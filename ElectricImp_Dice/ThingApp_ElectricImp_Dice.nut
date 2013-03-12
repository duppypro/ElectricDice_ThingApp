/* Electric Dice using MMA8452 accelerometer */

/////////////////////////////////////////////////
// global constants and variables
const versionString = "MMA8452 Dice v00.01.2013-03-07a"
local webscriptioOutputPort = OutputPort("webscriptio_dieID_dieValue", "string")
local wasActive = true // stay alive on boot as if button was pressed or die moved/rolled
const sleepforTimeout = 151.0 // seconds with no activity before calling server.sleepfor
const sleepforDuration = 30 // seconds to stay in deep sleep (wakeup is a reboot)
local accelSamplePeriod = 1.0/8 // seconds between reads of the XYZ accel data
local vizSpaces = "                                                                                                                                                                  "
local vizBars   = "##################################################################################################################################################################"

class AccelXYZ {
    constructor(nx,ny,nz) {
        x = nx
        y = ny
        z = nz
    }
    x = null
    y = null
    z = null
    function mag() {
        return x*x + y*y + z*z
    }
    function setByIndex(i, val) {
        switch (i) {
            case 0: x = val; break
            case 1: y = val; break
            case 2: z = val; break
        }
    }
    function asArray() {
        return [x, y, z]
    }
}

///////////////////////////////////////////////
// constants for MMA8452 i2c registers
// the slave address for this device is set in hardware. Creating a variable to save it here is helpful.
// The SparkFun breakout board defaults to 0x1D, set to 0x1C if SA0 jumper on the bottom of the board is set
local MMA8452_ADDR = 0x1D // A '<< 1' is needed.  I add the '<< 1' in the helper functions.  FIXME:  Why is '<< 1' needed?
//local MM8452_ADDR = 0x1C // Use this address if SA0 jumper is set. 
const OUT_X_MSB     = 0x01
const INT_SOURCE    = 0x0C
const XYZ_DATA_CFG  = 0x0E
const WHO_AM_I      = 0x0D; const I_AM_MMA8452  = 0x2A // read addr WHO_AM_I, expect I_AM_MMA8452
const PL_STATUS     = 0x10
const CTRL_REG1     = 0x2A
const CTRL_REG2     = 0x2B
const CTRL_REG3     = 0x2C
const CTRL_REG4     = 0x2D
const     INT_EN_LNDPRT  = 0x10 // bit4
const     INT_EN_DRDY    = 0x01 // bit0
// helper variables for MMA8452. These are not const because they may have reason to change dynamically.
local GSCALE        = 2 
local i2c = hardware.i2c89 // now can use i2c.read... instead of hardware.i2c89.read...
local i2cRetryPeriod = 1.0

///////////////////////////////////////////////
//define functions
function log(string, level) {
    local indent = vizSpaces.slice(0, level/10 + 1)
    if (level <= imp.configparams.logVerbosity)
        server.log(indent + string)
    if (level == 0)
        server.show(string)
}

function error(string, level) {
    local indent = vizSpaces.slice(0, level/10 + 1)
    if (level <= imp.configparams.errorVerbosity)
        server.error(indent + string)
}

function roll(dieValue) {
    local message = imp.configparams.dieID + "," + dieValue
    // Planner will send this to http://interfacearts.webscript.io/electricdice appending "?value=S10100000004,6" (example)
    webscriptioOutputPort.set(message)
    log(message,0)
}

function eventButton() {
    if (hardware.pin1.read() == 1) {  // FIXME: Experimentally there has been no need for debounce.  The neeed may show up with more testing.
        log("    buttonState === 1", 200)
        roll(math.rand() % 6 + 1) // 1 - 6 for a six sided die
        wasActive = true
    } else {
        log("    buttonState === 0", 200)
    }
}

function eventInt1() {
    log("Interrupt 1 changed.", 10)
}

function eventInt2() {
    log("Interrupt 2 changed.", 10)
}

// checkActivity re-schedules itself every sleepforTimeout
function checkActivity() {
    log("checkActivity() every " + sleepforTimeout + " secs.", 20)
    log("V = " + hardware.voltage(), 150)
    if (wasActive) {
        wasActive = false
        imp.wakeup(sleepforTimeout, checkActivity)
    } else {
        log("No activity for " + sleepforTimeout + " to " + sleepforTimeout*2 + " secs.\r\nGoing to deepsleep for " + (sleepforDuration / 60.0) + " minutes.", 10)
        imp.onidle(function() { server.sleepfor(sleepforDuration) })  // go to deepsleep if button not pressed for sleepforTimeout
    }
}

// Read a single byte from addressToRead and return it as a byte.  (The '[0]' causes a byte to return)
function readReg(addressToRead) {
    return readSequentialRegs(addressToRead, 1)[0]
}

// Writes a single byte (dataToWrite) into addressToWrite.  Returns error code from i2c.write
// Continue retry until success.  Caller does not need to check error code
function writeReg(addressToWrite, dataToWrite) {
    local err = null
    while (err == null) {
        err = i2c.write(MMA8452_ADDR << 1, format("%c%c", addressToWrite, dataToWrite))
        if (err == null) {
            error("i2c.write of value " + format("0x%02x", dataToWrite) + " to " + format("0x%02x", addressToWrite) + " failed.", 10)
            imp.sleep(i2cRetryPeriod)
        }
    }
    return err
}

// Read numBytes sequentially, starting at addressToRead
// Continue retry until success.  Caller does not need to check error code
function readSequentialRegs(addressToRead, numBytes) {
    local data = null
    while (data == null) {
        data = i2c.read(MMA8452_ADDR << 1, format("%c", addressToRead), numBytes)
        if (data == null) {
            error("i2c.read from " + format("0x%02x", addressToRead) + " of " + numBytes + " byte" + ((numBytes > 1) ? "s" : "") + " failed.", 10)
            imp.sleep(i2cRetryPeriod)
        }
    }
    return data
}

function readAccelData() {
    local rawData = array(6) // x/y/z accel register data stored here, 6 bytes
    local dest = AccelXYZ(null,null,null)
    
    rawData = readSequentialRegs(OUT_X_MSB, 6)  // Read the six raw data registers into data array
    if (rawData == null)
        return null

    // Loop to calculate 16-bit ADC and g value for each axis
    local i
    local val
    foreach(i,val in dest.asArray()) {
        val = (rawData[i*2] << 8) | rawData[(i*2)+1]  //Combine the two 8 bit registers into one 16-bit number
        // Actually the MMA8452 only provides 12bits.  The lowest 4 bits will always be 0.
        // If the number is negative, we have to make it so manually (no 12-bit data type)
        if (val >= 32768)
            val = val - 65536
        dest.setByIndex(i, val)
    }
    return dest
}

// Sets the MMA8452 to standby mode. It must be in standby to change most register settings
function MMA8452Standby() {
    return writeReg(CTRL_REG1, readReg(CTRL_REG1) & ~(0x01)) //Clear the active bit to go into standby
}

// Sets the MMA8452 to active mode. Needs to be in this mode to output data
function MMA8452Active() {
    return writeReg(CTRL_REG1, readReg(CTRL_REG1) | 0x01) //Set the active bit to begin detection
}

// Initialize the MMA8452 registers 
// See the many application notes for more info on setting all of these registers:
// http://www.freescale.com/webapp/sps/site/prod_summary.jsp?code=MMA8452Q
function initMMA8452() {
    do {
        local byte = readReg(WHO_AM_I)  // Read WHO_AM_I register
        if (byte == I_AM_MMA8452) {
            log("MMA8452Q is online...", 10)
            break
        } else {
            error("Could not connect to MMA8452Q: WHO_AM_I reg == " + format("0x%02x", byte), 10)
            imp.sleep(i2cRetryPeriod)
        }
    } while (true)
    
    MMA8452Standby()  // Must be in standby to change registers
    
    // Set up the full scale range to 2, 4, or 8g.
    // use GSCALE >> 2 : Neat trick, see page 22. 00 = 2G, 01 = 4A, 10 = 8G
    writeReg(XYZ_DATA_CFG, GSCALE >> 2)
    
    //The default data rate is 800Hz and we don't modify it in this example code

    //Enable interrupts
    writeReg(CTRL_REG4, readReg(CTRL_REG4) | INT_EN_LNDPRT)
//    writeReg(CTRL_REG4, readReg(CTRL_REG4) | INT_EN_DRDY)

    MMA8452Active()  // Set to active to start reading
}

function vizXYZ(xyz, level) {
    local string = ""
    local val
    local len

    foreach(val in xyz.asArray()) {
        len = val / 1024
        if (len <= 0) {
            string += vizSpaces.slice(0,16+len)
            string += vizBars.slice(0,-len)
        } else {
            string += vizSpaces.slice(0,16)
        }
        string += format("%6.0d",val)
        if (len > 0) {
            string += vizBars.slice(0,len)
            string += vizSpaces.slice(0,16-len)
        } else{
            string += vizSpaces.slice(0,16)
        }
    }
    log(format("mag=%11.0d", xyz.mag()) + string, level)
//    log(format("0x%02x",readReg(INT_SOURCE)), 100)
//    log(format("0x%02x",readReg(CTRL_REG4)), 100)
}

function pollMMA8452() {
    local xyz = readAccelData()
    local mag = xyz.mag()
    
    if (mag > 290000000 || mag < 240000000) {
        vizXYZ(xyz, 10)
        wasActive = true
    }
    imp.wakeup(accelSamplePeriod, pollMMA8452)
}

////////////////////////////////////////////////////////
// first code starts here
// Configure pin1 for wakeup with internal pull down.  Connect hardware button from pin1 to VCC
hardware.pin1.configure(DIGITAL_IN_WAKEUP, eventButton)
hardware.pin5.configure(DIGITAL_IN_PULLUP, eventInt1) // interrupt 1 from MMA8452
hardware.pin7.configure(DIGITAL_IN_PULLUP, eventInt2) // interrupt 2 from MMA8452
// set the I2C clock speed. We can do 10 kHz, 50 kHz, 100 kHz, or 400 kHz
i2c.configure(CLOCK_SPEED_400_KHZ)

// Register with the server
imp.configure("MMA8452 Dice", [], [webscriptioOutputPort], {dieID = "I10100000001", logVerbosity = 100, errorVerbosity = 1000})
log("imp.configparams.dieID = " + imp.configparams.dieID, 10)

// Send status to know we are alive
log(">>> BOOTING  " + versionString + " " + hardware.getimpeeid() + "/" + imp.getmacaddress(), 0)

// roll every time we boot just for some idle activity
roll("boot" + (math.rand() % 6 + 1)) // 1 - 6 for a six sided die

checkActivity() // kickstart checkActivity, this re-schedules itself every sleepforTimeout seconds

initMMA8452()
pollMMA8452()

// No more code to execute so we'll sleep until eventButton() occurs
// End of code.
