/* Electric Dice using MM8452 accelerometer */

const versionString = "MMA8452 Dice v00.01.2013.02.28c"
local webscriptioOutputPort = OutputPort("webscriptio_dieID_dieValue", "string")
local wasActive = true // stay alive on boot as if button was pressed or die moved/rolled
const sleepforTimeout = 77.0 // seconds with no activity before calling server.sleepfor
const sleepforDuration = 1620 // seconds to stay in deep sleep (wakeup is a reboot)
local accelSamplePeriod = 1.0/2.0 // seconds between reads of the XYZ accel data

///////////////////////////////////////////////
// constants for MMA8452 i2cregisters
const OUT_X_MSB     = 0x01
const XYZ_DATA_CFG  = 0x0E
const WHO_AM_I      = 0x0D
const CTRL_REG1     = 0x2A
// helper variables for MMA8452. These are not const because they may have reason to change dynamically.
local GSCALE        = 2 
local i2c = hardware.i2c89 // now can use i2c.read... instead of hardware.i2c89.read...
// the slave address for this device is set in hardware. Creating a variable to save it here is helpful.
// The SparkFun breakout board defaults to 0x1D, set to 0x1C if SA0 jumper on the bottom of the board is set
local MMA8452_ADDR = 0x1D // A '<< 1' is needed.  I add the '<< 1' in the helper functions.  FIXME:  Why is '<< 1' needed?
//local MM8452_ADDR = 0x1C // Use this address if SA0 jumper is set. 

///////////////////////////////////////////////
//define functions
function roll(dieValue) {
    local logMsg
    logMsg = imp.configparams.dieID + "," + dieValue
    // Planner will send this to http://interfacearts.webscript.io/electricdice appending "?value=S10100000004,6" (example)
    webscriptioOutputPort.set(logMsg)
    server.log(logMsg)
    server.show(logMsg)
}

function eventButton()
{
    if (hardware.pin1.read() == 1) {  // FIXME: Experimentally there has been no need for debounce.  The neeed may show up with more testing.
//        server.log("    buttonState === 1")
        roll(math.rand() % 6 + 1) // 1 - 6 for a six sided die
        wasActive = true
    } else {
//        server.log("    buttonState === 0")
    }
}

function eventInt1()
{
    server.log("Interrupt 1 changed.")
}

function eventInt2()
{
    server.log("Interrupt 2 changed.")
}

function checkActivity()
{
    server.log("checkActivity() every " + sleepforTimeout + " secs.")
    server.log("V = " + hardware.voltage())
    if (wasActive) {
        wasActive = false
        imp.wakeup(sleepforTimeout, checkActivity)
    } else {
        server.log("No activity for " + sleepforTimeout + " to " + sleepforTimeout*2 + " secs.")
        server.log("Going to deepsleep for " + (sleepforDuration / 60.0) + " minutes.")
        imp.onidle(function() { server.sleepfor(sleepforDuration) })  // go to deepsleep if button not pressed for a while
    }
}

// Read a single byte from addressToRead and return it as a byte.  (The '[0]' causes a byte to return)
function readReg(addressToRead)
{
    local r = i2c.read(MMA8452_ADDR << 1, format("%c", addressToRead), 1)[0]
    server.log(format("    >>>> readReg %0x == %0x", addressToRead, r))
    return r
}

// Writes a single byte (dataToWrite) into addressToWrite
function writeReg(addressToWrite, dataToWrite)
{
    local err = i2c.write(MMA8452_ADDR << 1, format("%c%c", addressToWrite, dataToWrite))
    server.log(format("    >>>> writeReg %0x = %0x err:", addressToWrite, dataToWrite) + err)
}

// Read numBytes sequentially, starting at addressToRead.  Return array
function readSequentialRegs(addressToRead, numBytes)
{
    local dest = []
    for(local x = 0; x < numBytes; x += 1){
        dest[c] = readReg(addressToRead + x)
    }
    return dest
}

function readAccelData()
{
    local rawData = [] // x/y/z accel register data stored here, 6 bytes
    local dest = [] // holds 3 12 bit ints
    local gCount
    
    rawData = readSequentialRegs(OUT_X_MSB, 6)  // Read the six raw data registers into data array

    // Loop to calculate 12-bit ADC and g value for each axis
    for(local i = 0; i < 3 ; i++)
    {
        gCount = (rawData[i*2] << 8) | rawData[(i*2)+1]  //Combine the two 8 bit registers into one 12-bit number
        gCount >>= 4 //The registers are left align, here we right align the 12-bit integer

        // If the number is negative, we have to make it so manually (no 12-bit data type)
        if (rawData[i*2] > 0x7F)
        {  
            gCount = ~gCount + 1
            gCount *= -1  // Transform into negative 2's complement #
        }
server.log(gCount)
        dest[i] = gCount //Record this gCount into the 3 int array
    }
    return dest
}

// Sets the MMA8452 to standby mode. It must be in standby to change most register settings
function MMA8452Standby()
{
  local c = readReg(CTRL_REG1);
  writeReg(CTRL_REG1, c & ~(0x01)); //Clear the active bit to go into standby
}

// Sets the MMA8452 to active mode. Needs to be in this mode to output data
function MMA8452Active()
{
  local c = readReg(CTRL_REG1);
  writeReg(CTRL_REG1, c | 0x01); //Set the active bit to begin detection
}

// Initialize the MMA8452 registers 
// See the many application notes for more info on setting all of these registers:
// http://www.freescale.com/webapp/sps/site/prod_summary.jsp?code=MMA8452Q
function initMMA8452()
{
    local c = readReg(WHO_AM_I);  // Read WHO_AM_I register
    if (c == 0x2A) // WHO_AM_I should always be 0x2A
    {  
        server.log("MMA8452Q is online...")
    }
    else
    {
        server.log("Could not connect to MMA8452Q: " + format("0x%0x", c))
        server.error("Could not connect to MMA8452Q: " + format("0x%0x", c))
    }
    
    MMA8452Standby();  // Must be in standby to change registers
    
    // Set up the full scale range to 2, 4, or 8g.
    // use GSCALE >> 2 : Neat trick, see page 22. 00 = 2G, 01 = 4A, 10 = 8G
    writeReg(XYZ_DATA_CFG, GSCALE >> 2);
    
    //The default data rate is 800Hz and we don't modify it in this example code
    
    MMA8452Active();  // Set to active to start reading
}

function pollMMA8452(period)
{
    imp.wakeup(period, pollMMA8452)
}

////////////////////////////////////////////////////////
// first code starts here
// Configure pin1 for wakeup with internal pull down.  Connect hardware button from pin1 to VCC
hardware.pin1.configure(DIGITAL_IN_WAKEUP, eventButton)
hardware.pin5.configure(DIGITAL_IN_PULLUP, eventInt1) // interrupt 1 from MMA8452
hardware.pin7.configure(DIGITAL_IN_PULLUP, eventInt2) // interrupt 2 from MMA8452
// set the I2C clock speed. We can do 10 kHz, 50 kHz, 100 kHz, or 400 kHz
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ)

// Register with the server
imp.configure("MMA8452 Dice", [], [webscriptioOutputPort], {dieID = "I10100000001"})
server.log("dieID = " + imp.configparams.dieID)

// Send status to know we are alive
server.log(">>> BOOTING  " + versionString + " " + hardware.getimpeeid() + "/" + imp.getmacaddress())

// roll every time we boot just for some idle activity
roll("boot" + (math.rand() % 6 + 1)) // 1 - 6 for a six sided die

initMMA8452()
pollMMA8452(accelSamplePeriod)

imp.wakeup(sleepforTimeout, checkActivity)

// No more code to execute so we'll sleep until eventButton() occurs
// End of code.

/* 
 arduino code example below
 
void loop()
{  
  int accelCount[3];  // Stores the 12-bit signed value
  readAccelData(accelCount);  // Read the x/y/z adc values

  // Now we'll calculate the accleration value into actual g's
  float accelG[3];  // Stores the real accel value in g's
  for (int i = 0 ; i < 3 ; i++)
  {
    accelG[i] = (float) accelCount[i] / ((1<<12)/(2*GSCALE));  // get actual g value, this depends on scale being set
  }

  // Print out values
  for (int i = 0 ; i < 3 ; i++)
  {
    Serial.print(accelG[i], 4);  // Print g values
    Serial.print("\t");  // tabs in between axes
  }
  Serial.println();

  delay(10);  // Delay here for visibility
}


*/