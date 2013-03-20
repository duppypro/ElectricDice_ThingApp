/* Electric Dice using MMA8452Q accelerometer */

/////////////////////////////////////////////////
// global constants and variables
const versionString = "MMA8452Q Dice v00.01.2013-03-20d"
webscriptioOutputPort <- OutputPort("webscriptio_dieID_dieValue", "string")
dieID <- "I10100000001" // FIXME: assign this from a DNS
logVerbosity <- 100 // higer numbers show more log messages
errorVerbosity <- 1000 // higher number shows more error messages
wasActive <- true // stay alive on boot as if button was pressed or die moved/rolled
const sleepforTimeout = 7.0 // seconds with no activity before calling server.sleepfor
const sleepforDuration = 1620.0 // seconds to stay in deep sleep (wakeup is a reboot)
const accelSamplePeriod = 0.25 // seconds between reads of the XYZ accel data

class AccelXYZ { // A 3 item vector with magnitude squared method
    x = null; y = null; z = null
    function magSquared() { return x*x + y*y + z*z } // assuming that square root would take too long
}

function readBitField(val, bitPosition, numBits){ // works for 8bit and registers
    return (val >> bitPosition) & (0x00FF >> (8 - numBits))
}

function readBit(val, bitPosition) { return readBitField(val, bitPosition, 1) }

function writeBitField(val, bitPosition, numBits, newVal) { // works for 8bit registers
// newVal is not bounds checked
    return (val & (((0x00FF >> (8 - numBits)) << bitPosition) ^ 0x00FF)) | (newVal << bitPosition)
}

function writeBit(val, bitPosition, newVal) { return writeBitField(val, bitPosition, 1, newVal) }

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
    const INT_EN_LNDPRT_BIT= 0x4
    const INT_EN_FF_MT_BIT = 0x2
    const INT_EN_DRDY_BIT  = 0x0
const CTRL_REG5        = 0x2E

// helper variables for MMA8452Q. These are not const because they may have reason to change dynamically.
local i2c = hardware.i2c89 // now can use i2c.read... instead of hardware.i2c89.read...
local i2cRetryPeriod = 1.0 // seconds to wait before retrying a failed i2c operation

///////////////////////////////////////////////
//define functions
function log(string, level) {
    local indent = "_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>".slice(0, level/10 + 1)
    if (level <= logVerbosity)
        server.log(indent + string)
    if (level == 0)
        server.show(string)
}

function error(string, level) {
    local indent = "#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!".slice(0, level/10 + 1)
    if (level <= errorVerbosity)
        server.error(indent + string)
}

function roll(dieValue) {
    local message = dieID + "," + dieValue
    // Planner will send this to http://interfacearts.webscript.io/electricdice appending "?value=S10100000004,6" (example)
    webscriptioOutputPort.set(message)
    log(message,0)
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
        // Disable data ready interrupts.  Motion interrupts is left enabled in order to wake from sleep
        // FIXME: this function should not know about MMA8452Q specifics
        writeReg(CTRL_REG4, writeBit(readReg(CTRL_REG4), INT_EN_DRDY_BIT, 0))
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
        err = i2c.write(MMA8452Q_ADDR << 1, format("%c%c", addressToWrite, dataToWrite))
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

function readAccelData() {
    local rawData = array(3) // x/y/z accel register data stored here, 3 bytes
    local dest = AccelXYZ()
    rawData = readSequentialRegs(OUT_X_MSB, 3)  // Read the three raw data registers into data array
    // above assumes we are in F_READ mode == 1 to read 8 bits per xyz
    dest.x = (rawData[0] < 128 ? rawData[0] : rawData[0] - 256) / 64.0 // convert to signed float
    dest.y = (rawData[1] < 128 ? rawData[1] : rawData[1] - 256) / 64.0
    dest.z = (rawData[2] < 128 ? rawData[2] : rawData[2] - 256) / 64.0
    return dest
}

// Reset the MMA8452Q
function MMA8452QReset() {
    return writeReg(CTRL_REG2, writeBit(readReg(CTRL_REG2), RST_BIT, 1))
}

function MMA8452QSetActive(mode) {
    // Sets the MMA8452Q active mode.
    // 0 == STANDBY for changing registers
    // 1 == ACTIVE for outputting data
    return writeReg(CTRL_REG1, writeBit(readReg(CTRL_REG1), ACTIVE_BIT, mode))
}

// Initialize the MMA8452Q registers 
// See the many application notes for more info on setting all of these registers:
// http://www.freescale.com/webapp/sps/site/prod_summary.jsp?code=MMA8452Q
function initMMA8452Q() {
    local reg
    
    do {
        reg = readReg(WHO_AM_I)  // Read WHO_AM_I register
        if (reg == I_AM_MMA8452Q) {
            log("MMA8452Q is online...", 10)
            break
        } else {
            error("Could not connect to MMA8452Q: WHO_AM_I reg == " + format("0x%02x", reg), 10)
            imp.sleep(i2cRetryPeriod)
        }
    } while (true)
    
    MMA8452QReset() // Sometimes imp card resets and MMA8452Q keeps power
    // in STANDBY already after RESET//MMA8452QSetActive(0)  // Must be in standby to change registers

    // Set up the full scale range to 2, 4, or 8g.
    // FIXME: assumes HPF_OUT_BIT in this same register always == 0
    writeReg(XYZ_DATA_CFG, FS_2G)
    
    // setup CTRL_REG1
    reg = readReg(CTRL_REG1)
    reg = writeBitField(reg, ASLP_RATE_BIT, 2, ASLP_RATE_1p56HZ)
    reg = writeBitField(reg, DR_BIT, 3, DR_1p56HZ)
    // leave LNOISE_BIT as default off to save power
    // Set Fast read mode to read 8bits per xyz instead of 12bits
    reg = writeBit(reg, F_READ_BIT, 1)
    // set all CTRL_REG1 bit fields in one i2c write
    writeReg(CTRL_REG1, reg)
    
    // setup CTRL_REG2
    reg = readReg(CTRL_REG2)
    // set Oversample mode in sleep
    reg = writeBitField(reg, SMODS_BIT, 2, MODS_LOW_POWER)
    // enable Auto-SLEEP
    reg = writeBit(reg, SLPE_BIT, 1)
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
    log(format("FF_MT_CFG == 0x%02x", readReg(FF_MT_CFG)), 100)
    
    // setup Motion threshold to 32*0.063 ~ 2G
    writeReg(FF_MT_THS, 32) // FIXME: this is a shortcut and assumes DBCNTM_BIT is 0
    
    //Enable Motion interrupts
    writeReg(CTRL_REG4, writeBit(readReg(CTRL_REG4), INT_EN_FF_MT_BIT, 1))
    // Enable interrupts on every new data
    writeReg(CTRL_REG4, writeBit(readReg(CTRL_REG4), INT_EN_DRDY_BIT, 1))
    log(format("CTRL_REG4 == 0x%02x", readReg(CTRL_REG4)), 100)

    MMA8452QSetActive(1)  // Set to active to start reading
}

function pollMMA8452Q() {
    local xyz
    local mag
    local reg
    
    reg = readReg(INT_SOURCE)
    log("INT2",100)
    while (reg != 0x00) {
        log(format("INT_SOURCE == 0x%02x", reg), 100)
        if (readBit(reg, SRC_DRDY_BIT) == 0x1){
            xyz = readAccelData() // this clears the SRC_DRDY_BIT
            mag = xyz.magSquared()
            log(format("mag^2=%9.3f, x=%9.3f, y=%9.3f, z=%9.3f", mag, xyz.x, xyz.y, xyz.z),10)
        }
        if (readBit(reg, SRC_FF_MT_BIT) == 0x1){
            reg = readReg(FF_MT_SRC) // this clears SRC_FF_MT_BIT
            if (readBit(reg, EA_BIT) == 0x1) {
                log("Motion Interrupt", 50)
                wasActive = true
//                log(format("CTRL_REG4 == 0x%02x", readReg(CTRL_REG4)), 100)
            } else {
                error(format("FF_MT_SRC == 0x%02x  why no EA bit?", reg), 100)
            }
        }
        reg = readReg(INT_SOURCE)
    }
    log(format("FF_MT_CFG == 0x%02x", readReg(FF_MT_CFG)), 100)
}

////////////////////////////////////////////////////////
// first code starts here
// Configure pin1 for wakeup.  Connect MMA8452Q INT2 pin to imp pin1.
hardware.pin1.configure(DIGITAL_IN_WAKEUP, pollMMA8452Q)
// set the I2C clock speed. We can do 10 kHz, 50 kHz, 100 kHz, or 400 kHz
i2c.configure(CLOCK_SPEED_400_KHZ)

// Register with the server
imp.configure("MMA8452Q Dice", [], [webscriptioOutputPort])

// Send status to know we are alive
log(">>> BOOTING  " + versionString + " " + hardware.getimpeeid() + "/" + imp.getmacaddress(), 0)

// roll every time we boot just for some idle activity
roll("boot" + (math.rand() % 6 + 1)) // 1 - 6 for a six sided die

checkActivity() // kickstart checkActivity, this re-schedules itself every sleepforTimeout seconds

initMMA8452Q()  // sets up code to run on interrupts from MMA8452Q

// No more code to execute so we'll sleep until an interrupt from MMA8452Q.
// End of code.
