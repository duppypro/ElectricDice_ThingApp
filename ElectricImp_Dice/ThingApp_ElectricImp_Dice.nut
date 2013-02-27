/* Electric Dice using MM8452 accelerometer */

local versionString = "MMA8452 Dice v00.01.2013.02.27a"
local webscriptioOutputPort = OutputPort("webscriptio_dieID_dieValue", "string")
local dieID = "I10100000001"
local wasActive = true // stay alive on boot as if button was pressed or die moved/rolled
local sleepforTimeout = 7.0 // seconds with no activity before calling server.sleepfor
local sleepforDuration = (5 * 60) // seconds to stay in deep sleep (wakeup is a reboot)

///////////////////////////////////////////////
// constants for MMA8452 i2cregisters
local OUT_X_MSB     = 0x01
local XYZ_DATA_CFG  = 0x0E
local WHO_AM_I      = 0x0D
local CTRL_REG1     = 0x2A
local GSCALE        = 2 
local i2c = hardware.i2c89 // now can use i2c.read... instead of hardware.i2c89.read...
// the slave address for this device is set in hardware. Creating a variable to save it here is helpful.
// The SparkFun breakout board defaults to 0x1D, set to 0x1C if SA0 jumper on the bottom of the board is set
local MMA8452_ADDR = (0x1D << 1) // I am not sure yet why the '<< 1' is needed, but it works.  I copied it from other sample code.
//local MM8452_ADDR = (0x1C << 1) // Use this address if SA0 jumper is set. 

///////////////////////////////////////////////
//define functions
function roll(dieValue) {
    local logMsg
    logMsg = dieID + "," + dieValue
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
    if (wasActive) {
        wasActive = false
        imp.wakeup(sleepforTimeout, checkActivity)
    } else {
        server.log("No activity for " + sleepforTimeout + " to " + sleepforTimeout*2 + " secs.")
        server.log("Going to deepsleep for " + (sleepforDuration / 60.0) + " minutes.")
        imp.onidle(function() { server.sleepfor(sleepforDuration) })  // go to deepsleep if button not pressed for a while
    }
}

// Read a single byte from addressToRead and return it as a byte
function readReg(addressToRead)
{
    return i2c.read(MMA8452_ADDR, format("%c", addressToRead), 1)[0]
}

// Writes a single byte (dataToWrite) into addressToWrite
function writeReg(addressToWrite, dataToWrite)
{
    return i2c.write(MMA8452_ADDR, format("%c%c", addressToRead, dataToWrite))
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
imp.configure("MMA8452 Dice", [], [webscriptioOutputPort])

// Send status to know we are alive
server.log(">>> BOOTING  " + versionString + " " + hardware.getimpeeid() + "/" + imp.getmacaddress())

// roll every time we boot just for some idle activity
roll("boot" + (math.rand() % 6 + 1)) // 1 - 6 for a six sided die

// Test I2C read WhoAmI from accel
local whoami = readReg(WHO_AM_I)
server.log("Who Am I == " + format("0x%0x", whoami))

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

void readAccelData(int *destination)
{
  byte rawData[6];  // x/y/z accel register data stored here

  readRegisters(OUT_X_MSB, 6, rawData);  // Read the six raw data registers into data array

  // Loop to calculate 12-bit ADC and g value for each axis
  for(int i = 0; i < 3 ; i++)
  {
    int gCount = (rawData[i*2] << 8) | rawData[(i*2)+1];  //Combine the two 8 bit registers into one 12-bit number
    gCount >>= 4; //The registers are left align, here we right align the 12-bit integer

    // If the number is negative, we have to make it so manually (no 12-bit data type)
    if (rawData[i*2] > 0x7F)
    {  
      gCount = ~gCount + 1;
      gCount *= -1;  // Transform into negative 2's complement #
    }

    destination[i] = gCount; //Record this gCount into the 3 int array
  }
}

// Initialize the MMA8452 registers 
// See the many application notes for more info on setting all of these registers:
// http://www.freescale.com/webapp/sps/site/prod_summary.jsp?code=MMA8452Q
void initMMA8452()
{
  byte c = readRegister(WHO_AM_I);  // Read WHO_AM_I register
  if (c == 0x2A) // WHO_AM_I should always be 0x2A
  {  
    Serial.println("MMA8452Q is online...");
  }
  else
  {
    Serial.print("Could not connect to MMA8452Q: 0x");
    Serial.println(c, HEX);
    while(1) ; // Loop forever if communication doesn't happen
  }

  MMA8452Standby();  // Must be in standby to change registers

  // Set up the full scale range to 2, 4, or 8g.
  byte fsr = GSCALE;
  if(fsr > 8) fsr = 8; //Easy error check
  fsr >>= 2; // Neat trick, see page 22. 00 = 2G, 01 = 4A, 10 = 8G
  writeRegister(XYZ_DATA_CFG, fsr);

  //The default data rate is 800Hz and we don't modify it in this example code

  MMA8452Active();  // Set to active to start reading
}

// Sets the MMA8452 to standby mode. It must be in standby to change most register settings
void MMA8452Standby()
{
  byte c = readRegister(CTRL_REG1);
  writeRegister(CTRL_REG1, c & ~(0x01)); //Clear the active bit to go into standby
}

// Sets the MMA8452 to active mode. Needs to be in this mode to output data
void MMA8452Active()
{
  byte c = readRegister(CTRL_REG1);
  writeRegister(CTRL_REG1, c | 0x01); //Set the active bit to begin detection
}

// Read bytesToRead sequentially, starting at addressToRead into the dest byte array
void readRegisters(byte addressToRead, int bytesToRead, byte * dest)
{
  Wire.beginTransmission(MMA8452_ADDRESS);
  Wire.write(addressToRead);
  Wire.endTransmission(false); //endTransmission but keep the connection active

  Wire.requestFrom(MMA8452_ADDRESS, bytesToRead); //Ask for bytes, once done, bus is released by default

  while(Wire.available() < bytesToRead); //Hang out until we get the # of bytes we expect

  for(int x = 0 ; x < bytesToRead ; x++)
    dest[x] = Wire.read();    
}

// Read a single byte from addressToRead and return it as a byte
byte readRegister(byte addressToRead)
{
  Wire.beginTransmission(MMA8452_ADDRESS);
  Wire.write(addressToRead);
  Wire.endTransmission(false); //endTransmission but keep the connection active

  Wire.requestFrom(MMA8452_ADDRESS, 1); //Ask for 1 byte, once done, bus is released by default

  while(!Wire.available()) ; //Wait for the data to come back
  return Wire.read(); //Return this one byte
}

// Writes a single byte (dataToWrite) into addressToWrite
void writeRegister(byte addressToWrite, byte dataToWrite)
{
  Wire.beginTransmission(MMA8452_ADDRESS);
  Wire.write(addressToWrite);
  Wire.write(dataToWrite);
  Wire.endTransmission(); //Stop transmitting
}
*/