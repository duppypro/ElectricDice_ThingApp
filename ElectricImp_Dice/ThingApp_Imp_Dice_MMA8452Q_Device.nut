// Electric Dice using MMA8452Q accelerometer */
// ThingApp Imp Device Squirrel code */

/////////////////////////////////////////////////
// global constants and variables
const versionString = "MMA8452Q Dice v00.01.2013-05-02a"
const logIndent   = "Device:_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>"
const errorIndent = "Device:#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!" 
logVerbosity <- 100 // higer numbers show more log messages
errorVerbosity <- 1000 // higher number shows more error messages
impeeID <- hardware.getimpeeid() // cache the impeeID FIXME: is this necessary for speed?
//DEPRECATED: wasActive <- true // stay alive on boot as if button was pressed or die moved/rolled
const sleepforTimeout = 117 // seconds with no activity before logging and dec idleCount
const sleepforDuration = 1800 // seconds to stay in deep sleep (wakeup is a reboot)
const idleCountdown = 30 // how many sleepforTimeout periods of inactivity before server.sleepfor
idleCount <- idleCountdown // Current count of idleCountdown timer
lastFaceValue <- "boot"
const accelChangeThresh = 500 // change in accel per sample to count as movement.  Units of milliGs
pollMMA8452QBusy <- false // guard against interrupt handler collisions FIXME: Is this necessary?  Debugging why I get no EA_BIT set error sometimes

///////////////////////////////////////////////
// constants for MMA8452Q i2c registers
// the slave address for this device is set in hardware. Creating a variable to save it here is helpful.
// The SparkFun breakout board defaults to 0x1D, set to 0x1C if SA0 jumper on the bottom of the board is set
const MMA8452Q_ADDR = 0x1D // A '<< 1' is needed.  I add the '<< 1' in the helper functions.
//const MM8452Q_ADDR = 0x1C // Use this address if SA0 jumper is set. 
const STATUS           = 0x00
    const ZYXOW_BIT        = 0x7 // name_BIT == BIT position of name
    const ZYXDR_BIT        = 0x3
const OUT_X_MSB        = 0x01
const SYSMOD           = 0x0B
    const SYSMOD_STANDBY   = 0x00
    const SYSMOD_WAKE      = 0x01
    const SYSMOD_SLEEP     = 0x02
const INT_SOURCE       = 0x0C
    const SRC_ASLP_BIT     = 0x7
    const SRC_FF_MT_BIT    = 0x2
    const SRC_DRDY_BIT     = 0x0
const WHO_AM_I         = 0x0D
    const I_AM_MMA8452Q    = 0x2A // read addr WHO_AM_I, expect I_AM_MMA8452Q
const XYZ_DATA_CFG     = 0x0E
    const FS_2G            = 0x00
    const FS_4G            = 0x01
    const FS_8G            = 0x02
    const HPF_OUT_BIT      = 0x5
const HP_FILTER_CUTOFF = 0x0F
const FF_MT_CFG        = 0x15
    const ELE_BIT          = 0x7
    const OAE_BIT          = 0x6
    const XYZEFE_BIT       = 0x3 // numBits == 3 (one each for XYZ)
        const XYZEFE_ALL       = 0x07 // enable all 3 bits
const FF_MT_SRC        = 0x16
    const EA_BIT           = 0x7
const FF_MT_THS        = 0x17
    const DBCNTM_BIT       = 0x7
    const THS_BIT          = 0x0 // numBits == 7
const FF_MT_COUNT      = 0x18
const ASLP_COUNT       = 0x29
const CTRL_REG1        = 0x2A
    const ASLP_RATE_BIT    = 0x6 // numBits == 2
        const ASLP_RATE_12p5HZ = 0x1
        const ASLP_RATE_1p56HZ = 0x3
    const DR_BIT           = 0x3 // numBits == 3
        const DR_12p5HZ        = 0x5
        const DR_1p56HZ        = 0x7
    const LNOISE_BIT       = 0x2
    const F_READ_BIT       = 0x1
    const ACTIVE_BIT       = 0x0
const CTRL_REG2        = 0x2B
    const ST_BIT           = 0x7
    const RST_BIT          = 0x6
    const SMODS_BIT        = 0x3 // numBits == 2
    const SLPE_BIT         = 0x2
    const MODS_BIT         = 0x0 // numBits == 2
        const MODS_NORMAL      = 0x00
        const MODS_LOW_POWER   = 0x03
const CTRL_REG3        = 0x2C
    const WAKE_FF_MT_BIT   = 0x3
    const IPOL_BIT         = 0x1
const CTRL_REG4        = 0x2D
    const INT_EN_ASLP_BIT  = 0x7
    const INT_EN_LNDPRT_BIT= 0x4
    const INT_EN_FF_MT_BIT = 0x2
    const INT_EN_DRDY_BIT  = 0x0
const CTRL_REG5        = 0x2E

// helper variables for MMA8452Q. These are not const because they may have reason to change dynamically.
i2c <- hardware.i2c89 // now can use i2c.read... instead of hardware.i2c89.read...
vBatt <- hardware.pin5 // now we can use vBatt.read()
i2cRetryPeriod <- 1.0 // seconds to wait before retrying a failed i2c operation
fullScale <- FS_4G // what scale to get G readings

///////////////////////////////////////////////
//define functions

// start with fairly generic functions
function log(string, level) {
    local indent = logIndent.slice(0, level / 10 + 7)
    if (level <= logVerbosity)
        server.log(indent + string)
    if (level == 0)
        server.show(string)
}

function error(string, level) {
    local indent = errorIndent.slice(0, level / 10 + 7)
    if (level <= errorVerbosity)
        server.error(indent + string)
}

function timestamp() {
    return format("%016u", hardware.micros())  // return microseconds since boot
    // FIXME: should return milliseconds since Unix epoch
}

function checkActivity() {
// checkActivity re-schedules itself every sleepforTimeout
// FIXME: checkActivity should be more generic
    log("checkActivity() every " + sleepforTimeout + " secs.", 200)
    // let the agent know we are still alive
    t <- timestamp()
    agent.send(
        "dieEvent",
        {
            "keepAlive": idleCount,
            "vBatt": getVBatt(),
            "t": t,
// can't use priority until proper UTC is used            ".priority": t
        }
    )
    if (imp.getpowersave() == false) {
        imp.setpowersave(true)
        idleCount = idleCountdown // restart idle count down
    } else {
        if (idleCount == 0) {
            idleCount = idleCountdown
            log("No activity for " + sleepforTimeout * idleCountdown + " to " + sleepforTimeout * (idleCountdown + 1) + " secs.\r\nGoing to deepsleep for " + (sleepforDuration / 60.0) + " minutes.", 10)
            // Disable data ready interrupts.  Motion interrupts is left enabled in order to wake from sleep
            // FIXME: this function should not know about MMA8452Q specifics
            MMA8452QSetActive(0) // Can't write MMA8452Q until not active
            writeReg(CTRL_REG4, writeBit(readReg(CTRL_REG4), INT_EN_DRDY_BIT, 0)) // turn off SRC_DRDY_BIT so it doesnt wake us up
            writeReg(CTRL_REG4, writeBit(readReg(CTRL_REG4), INT_EN_ASLP_BIT, 0)) // turn off SRC_ASLP_BIT so it doesnt wake us up
            // Make harder to wakeup. set Motion threshold to 32*0.063.  (16 * 0.063 == 1G)
            //writeReg(FF_MT_THS, 32) // FIXME: this is a shortcut and assumes DBCNTM_BIT is 0
            MMA8452QSetActive(1) // set to Active mode so tht SRC_FF_MT_BIT can wake us up
            imp.onidle(function() { server.sleepfor(sleepforDuration) })  // go to deepsleep if no MMA8452Q interrupts for sleepforTimeout
        } else {
            idleCount -= 1
        }
    }
    imp.wakeup(sleepforTimeout, checkActivity)
} // checkActivity

// now functions specific to devices that read i2c registers

function readBitField(val, bitPosition, numBits){ // works for 8bit and registers
    return (val >> bitPosition) & (0x00FF >> (8 - numBits))
}

function readBit(val, bitPosition) { return readBitField(val, bitPosition, 1) }

function writeBitField(val, bitPosition, numBits, newVal) { // works for 8bit registers
// newVal is not bounds checked
    return (val & (((0x00FF >> (8 - numBits)) << bitPosition) ^ 0x00FF)) | (newVal << bitPosition)
}

function writeBit(val, bitPosition, newVal) { return writeBitField(val, bitPosition, 1, newVal) }

// Read a single byte from addressToRead and return it as a byte.  (The '[0]' causes a byte to return)
function readReg(addressToRead) {
    return readSequentialRegs(addressToRead, 1)[0]
}

// Writes a single byte (dataToWrite) into addressToWrite.  Returns error code from i2c.write
// Continue retry until success.  Caller does not need to check error code
function writeReg(addressToWrite, dataToWrite) {
    local err = null
    while (err == null) {
        err = i2c.write(MMA8452Q_ADDR << 1, format("%c%c", addressToWrite, dataToWrite))
        log(format("i2c.write addr=0x%02x data=0x%02x", addressToWrite, dataToWrite), 150)
        if (err == null) {
            error("i2c.write of value " + format("0x%02x", dataToWrite) + " to " + format("0x%02x", addressToWrite) + " failed.", 10)
            imp.sleep(i2cRetryPeriod)
            error("retry i2c.write", 100)
        }
    }
    return err
}

// Read numBytes sequentially, starting at addressToRead
// Continue retry until success.  Caller does not need to check error code
function readSequentialRegs(addressToRead, numBytes) {
    local data = null
    
    while (data == null) {
        data = i2c.read(MMA8452Q_ADDR << 1, format("%c", addressToRead), numBytes)
        if (data == null) {
            error("i2c.read from " + format("0x%02x", addressToRead) + " of " + numBytes + " byte" + ((numBytes > 1) ? "s" : "") + " failed.", 10)
            imp.sleep(i2cRetryPeriod)
            error("retry i2c.read", 100)
        }
    }
    return data
}

// now functions unique to MMA8452Q

function readAccelData() {
    local rawData = null // x/y/z accel register data stored here, 3 bytes
    local accelData = array(3)
    local i
    local val
    
    rawData = readSequentialRegs(OUT_X_MSB, 3)  // Read the three raw data registers into data array
    foreach (i, val in rawData) {
        accelData[i] = math.floor(1000.0 * ((val < 128 ? val : val - 256) / ((64 >> fullScale) + 0.0))) // FIXME: (depends on FS_scale selected)
        //convert to signed integer milliGs
    }
    return accelData
}

// Reset the MMA8452Q
function MMA8452QReset() {
    local reg
    
    do {
        reg = readReg(WHO_AM_I)  // Read WHO_AM_I register
        if (reg == I_AM_MMA8452Q) {
            log("Found MMA8452Q.  Sending RST command...", 200)
            break
        } else {
            error("Could not connect to MMA8452Q: WHO_AM_I reg == " + format("0x%02x", reg), 10)
            imp.sleep(i2cRetryPeriod)
        }
    } while (true)
    
    // send reset command
    writeReg(CTRL_REG2, writeBit(readReg(CTRL_REG2), RST_BIT, 1))

    do {
        reg = readReg(WHO_AM_I)  // Read WHO_AM_I register
        if (reg == I_AM_MMA8452Q) {
            log("MMA8452Q is online!", 150)
            break
        } else {
            error("Could not connect to MMA8452Q: WHO_AM_I reg == " + format("0x%02x", reg), 10)
            imp.sleep(i2cRetryPeriod)
        }
    } while (true)
}

function MMA8452QSetActive(mode) {
    // Sets the MMA8452Q active mode.
    // 0 == STANDBY for changing registers
    // 1 == ACTIVE for outputting data
    writeReg(CTRL_REG1, writeBit(readReg(CTRL_REG1), ACTIVE_BIT, mode))
}

function initMMA8452Q() {
// Initialize the MMA8452Q registers 
// See the many application notes for more info on setting all of these registers:
// http://www.freescale.com/webapp/sps/site/prod_summary.jsp?code=MMA8452Q
    local reg
    
    MMA8452QReset() // Sometimes imp card resets and MMA8452Q keeps power
    // Must be in standby to change registers
    // in STANDBY already after RESET//MMA8452QSetActive(0)

    // Set up the full scale range to 2, 4, or 8g.
    // FIXME: assumes HPF_OUT_BIT in this same register always == 0
    writeReg(XYZ_DATA_CFG, fullScale)
    
    // setup CTRL_REG1
    reg = readReg(CTRL_REG1)
    reg = writeBitField(reg, ASLP_RATE_BIT, 2, ASLP_RATE_1p56HZ)
    reg = writeBitField(reg, DR_BIT, 3, DR_12p5HZ)
    // leave LNOISE_BIT as default off to save power
    // Set Fast read mode to read 8bits per xyz instead of 12bits
    reg = writeBit(reg, F_READ_BIT, 1)
    // set all CTRL_REG1 bit fields in one i2c write
    writeReg(CTRL_REG1, reg)
    
    // setup CTRL_REG2
    reg = readReg(CTRL_REG2)
    // set Oversample mode in sleep
    reg = writeBitField(reg, SMODS_BIT, 2, MODS_LOW_POWER)
    // Enable Auto-SLEEP
    //reg = writeBit(reg, SLPE_BIT, 1)
    // Disable Auto-SLEEP
    reg = writeBit(reg, SLPE_BIT, 0)
    // set Oversample mode in wake
    reg = writeBitField(reg, MODS_BIT, 2, MODS_LOW_POWER)
    // set all CTRL_REG2 bit fields in one i2c write
    writeReg(CTRL_REG2, reg)
    
    // setup CTRL_REG3
    reg = readReg(CTRL_REG3)
    // allow Motion to wake from SLEEP
    reg = writeBit(reg, WAKE_FF_MT_BIT, 1)
    // change Int Polarity
    reg = writeBit(reg, IPOL_BIT, 1)
    // set all CTRL_REG3 bit fields in one i2c write
    writeReg(CTRL_REG3, reg)

    // setup FF_MT_CFG
    reg = readReg(FF_MT_CFG)
    // enable ELE_BIT to latch FF_MT_SRC events
    reg = writeBit(reg, ELE_BIT, 1)
    // enable Motion detection (not Free Fall detection)
    reg = writeBit(reg, OAE_BIT, 1)
    // enable on all axis x, y, and z
    reg = writeBitField(reg, XYZEFE_BIT, 3, XYZEFE_ALL)
    // set all FF_MT_CFG bit fields in one i2c write
    writeReg(FF_MT_CFG, reg)
    log(format("FF_MT_CFG == 0x%02x", readReg(FF_MT_CFG)), 150)
    
    // setup Motion threshold to n*0.063.  (16 * 0.063 == 1G)
    writeReg(FF_MT_THS, 60) // FIXME: this is a shortcut and assumes DBCNTM_BIT is 0

    // setup sleep counter, the time in multiples of 320ms of no activity to enter sleep mode
    //dont' use ASLP_COUNT for now, use change in prev AccelData reading
    //writeReg(ASLP_COUNT, 10) // 10 * 320ms = 3.2 seconds
    
    //Enable Sleep interrupts
//    writeReg(CTRL_REG4, writeBit(readReg(CTRL_REG4), INT_EN_ASLP_BIT, 1))
    //Enable Motion interrupts
    writeReg(CTRL_REG4, writeBit(readReg(CTRL_REG4), INT_EN_FF_MT_BIT, 1))
    // Enable interrupts on every new data
    writeReg(CTRL_REG4, writeBit(readReg(CTRL_REG4), INT_EN_DRDY_BIT, 1))
    log(format("CTRL_REG4 == 0x%02x", readReg(CTRL_REG4)), 150)

    MMA8452QSetActive(1)  // Set to active to start reading
} // initMMA8452Q

// now die specific functions

function roll(dieValue) {
    local t = timestamp() // FIXME: timestamp should come exactly when sample was captured
    local tableDieEvent = {
        "impeeID": impeeID,
        "roll": dieValue,
        "t": t,
// can't use priority until proper UTC is used        ".priority": t
        }

    // Agent will send this to http://interfacearts.webscript.io/electricdice appending "?dieID=S10100000004&roll=6" (example)
//    log(impeeID + " rolls a " + dieValue, 120)
    agent.send("dieEvent", tableDieEvent)
}

function getFaceValueFromAccelData(xyz) {
    local faceValue = "s"
    local snapAngle = ""

//<=-0.86    <=-.59    <=-0.25    <=0.26    <=.60	<=.87	<= 1.1
//-1.00 	-0.707	     x	       0	    x	    0.707	1
    foreach(val in xyz) {
        if (val <= -875) {
            snapAngle += "a"
        } else if (val <= -550) {
            snapAngle += "b"
        } else if (val <= -150) {
            snapAngle += "x"
        } else if (val <= 150) {
            snapAngle += "0"
        } else if (val <= 550) {
            snapAngle += "x"
        } else if (val <= 875) {
            snapAngle += "c"
        } else {
            snapAngle += "d"
        }
    }
// facevalue	x	y	z           x*x + z*z
//d1	0.000	1.000	0.000           0
//d2	0.707	0.000	-0.707          1
//d3	-0.707	0.000	-0.707          1
//d4	0.707	0.000	0.707
//d5	-0.707	0.000	0.707
//d6	0.000	-1.000	0.000
    // determine dice roll value (what side is up?)
// try this method below instead? create xz axis by x*x + z*z 
    //    roll = "x";
//    if (abs(inXYZ[1])<oneGAxis && abs(inXYZ[2])<oneGAxis && inXYZ[0] < xNegOneG)
//      roll = "3";
//    if (abs(inXYZ[1])<oneGAxis && abs(inXYZ[2])<oneGAxis && inXYZ[0] > xPosOneG)
//      roll = "4";
//    if (abs(inXYZ[0])<oneGAxis && abs(inXYZ[2])<oneGAxis && inXYZ[1] < yNegOneG)
//      roll = "1";
//    if (abs(inXYZ[0])<oneGAxis && abs(inXYZ[2])<oneGAxis && inXYZ[1] > yPosOneG)
//      roll = "6";
//    if (abs(inXYZ[0])<oneGAxis && abs(inXYZ[1])<oneGAxis && inXYZ[2] < zNegOneG)
//      roll = "5";
//    if (abs(inXYZ[0])<oneGAxis && abs(inXYZ[1])<oneGAxis && inXYZ[2] > zPosOneG)
//      roll = "2";
      
    switch (snapAngle) {
        case "0d0":
            faceValue = "1"
            break
        case "c0b":
            faceValue = "2"
            break
        case "b0b":
            faceValue = "3"
            break
        case "c0c":
            faceValue = "4"
            break
        case "b0c":
            faceValue = "5"
            break
        case "0a0":
            faceValue = "6"
            break
        default:
            faceValue = "x"
    }
    return faceValue
} // accelData2FaceValue

function pollMMA8452Q() {
    local xyz
    local reg
    local faceValue = lastFaceValue    

    while (pollMMA8452QBusy) {
        log("pollMMA8452QBusy collision", 50)
        // wait herer unitl other instance of int handler is done
    }
    pollMMA8452QBusy = true // mark as busy
    if (hardware.pin1.read() == 1) { // only react to low to high edge
//FIXME:  do we need to check status for data ready in all xyz?//log(format("STATUS == 0x%02x", readReg(STATUS)), 80)
        reg = readReg(INT_SOURCE)
        while (reg != 0x00) {
//            log(format("INT_SOURCE == 0x%02x", reg), 200)
            if (readBit(reg, SRC_DRDY_BIT) == 0x1) {
                xyz = readAccelData() // this clears the SRC_DRDY_BIT
                log(format("%4d %4d %4d", xyz[0], xyz[1], xyz[2]), 200)
                faceValue = getFaceValueFromAccelData(xyz)
                if (faceValue != lastFaceValue) {
                    roll(faceValue)
                    lastFaceValue = faceValue
                    imp.setpowersave(false) // go to low latency mode when facevalue changes
                }
            }
            if (readBit(reg, SRC_FF_MT_BIT) == 0x1) {
                log("Interrupt SRC_FF_MT_BIT", 50)
                reg = readReg(FF_MT_SRC) // this clears SRC_FF_MT_BIT
                imp.setpowersave(false) // go to low latency mode because we detected motion
            }
            if (readBit(reg, SRC_ASLP_BIT) == 0x1) {
                reg = readReg(SYSMOD) // this clears SRC_ASLP_BIT
//                log(format("Entering SYSMOD 0x%02x", reg), 100)
            }
            reg = readReg(INT_SOURCE)
        } // while (reg != 0x00)
    } else {
//        log("INT2 LOW", 200)
    }
    pollMMA8452QBusy = false // clear so other inst of int handler can run
} // pollMMA8452Q

function getVBatt() {
    local tableVBatt = {
        "min": 10,
        "max": 0,
        "avg": 0,
        "hardware-voltage": hardware.voltage(),
        "count": 3
    }
    local i = tableVBatt.count
    local voltage = 0
    
    // throw out first measurement. Experimentally first measurement is >5% low
    // Even with 10uF cap near SD card VCC
    vBatt.read() 
    // read count times and save min, max, and average
    while (i){
        voltage = (2 * vBatt.read() / 65535.0) * hardware.voltage()
        if (voltage < tableVBatt.min) { tableVBatt.min = voltage }
        if (voltage > tableVBatt.max) { tableVBatt.max = voltage }
        tableVBatt.avg = tableVBatt.avg + voltage
        i = i - 1
    }
    tableVBatt.avg = tableVBatt.avg / tableVBatt.count
    return tableVBatt
}

////////////////////////////////////////////////////////
// first code starts here

imp.setpowersave(false) // start in low latency mode.  Treat boot as an activity
// Register with the server
imp.configure("MMA8452Q Dice using Agent messages", [], [])
// no in and out []s anymore, using Agent messages

// Send status to know we are alive
log("BOOTING  " + versionString + " " + hardware.getimpeeid() + "/" + imp.getmacaddress(), 0)

// roll every time we boot just for some debug activity
roll("boot" + (math.rand() % 6 + 1)) // 1 - 6 for a six sided die

log("powersave = " + imp.getpowersave(), 100)
// Configure pin1 for wakeup.  Connect MMA8452Q INT2 pin to imp pin1.
hardware.pin1.configure(DIGITAL_IN_WAKEUP, pollMMA8452Q)
// Configure pin5 as ADC to read Vbatt/2.0
vBatt.configure(ANALOG_IN)
// set the I2C clock speed. We can do 10 kHz, 50 kHz, 100 kHz, or 400 kHz
i2c.configure(CLOCK_SPEED_400_KHZ)
initMMA8452Q()  // sets up code to run on interrupts from MMA8452Q

checkActivity() // kickstart checkActivity, this re-schedules itself every sleepforTimeout seconds
// FIXME: checkActivity waits from sleepforTimeout to sleepforTimeout*2.  Make this more constant.

pollMMA8452Q()  // call first time to get a roll value on boot.

// No more code to execute so we'll sleep until an interrupt from MMA8452Q.
// End of code.
// Electric Dice using MMA8452Q accelerometer */
// ThingApp Imp Device Squirrel code */