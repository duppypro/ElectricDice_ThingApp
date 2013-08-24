// Electric Dice using MMA8452Q accelerometer */
// ThingApp Imp Device Squirrel code */

/////////////////////////////////////////////////
// global constants and variables
const versionString = "Remember The Soda v00.01.2013-08-22a"
const logIndent   = "_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>"
const errorIndent = "#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!" 
logVerbosity <- 100 // higher numbers show more log messages
errorVerbosity <- 1000 // higher number shows more error messages
impeeID <- hardware.getimpeeid() // cache the impeeID FIXME: is this necessary for speed?
offsetMilliseconds <- 0 // set later to milliseconds % 1000 when time() rolls over
//DEPRECATED: wasActive <- true // stay alive on boot as if button was pressed or die moved/rolled
const sleepforTimeout = 122 // seconds with no activity before logging and dec idleCount
const sleepforDuration = 3300 // seconds to stay in deep sleep (wakeup is a reboot)
const idleCountdown = 6 // how many sleepforTimeout periods of inactivity before server.sleepfor
idleCount <- idleCountdown // Current count of idleCountdown timer

// helper variables
// These are not const because they may have reason to change dynamically.
vBatt <- hardware.pin5 // now we can use vBatt.read()

///////////////////////////////////////////////
//define functions

// start with fairly generic functions
function log(string, level) {
    local indent = logIndent.slice(0, level / 10)
    if (level <= logVerbosity)
        server.log(indent + string)
    if (level == 0)
        server.show(string)
}

function error(string, level) {
    local indent = errorIndent.slice(0, level / 10)
    if (level <= errorVerbosity)
        server.error(indent + string)
}

function timestamp() {
    local t, m
    t = time()
    m = hardware.millis()
    return format("%010u%03u", t, (m - offsetMilliseconds) % 1000)
        // return milliseconds since Unix epoch 
}

function checkActivity() {
// checkActivity re-schedules itself every sleepforTimeout
// FIXME: checkActivity should be more generic
    log("checkActivity() every " + sleepforTimeout + " secs.", 200)
    // let the agent know we are still alive
    agent.send(
        "event",
        {
            "keepAlive": idleCount,
            "vBatt": getVBatt(),
            "t": timestamp(),
        }
    )
    if (imp.getpowersave() == false) {
        imp.setpowersave(true)
        idleCount = idleCountdown // restart idle count down
    } else {
        if (idleCount == 0) {
            idleCount = idleCountdown
            log("No activity for " + sleepforTimeout * idleCountdown + " to " + sleepforTimeout * (idleCountdown + 1) + " secs.\r\nGoing to deepsleep for " + (sleepforDuration / 60.0) + " minutes.", 10)
            //
            // do app specific shutdown stuff here
            //
            imp.onidle(function() { server.sleepfor(sleepforDuration) })  // go to deepsleep if no MMA8452Q interrupts for sleepforTimeout
        } else {
            idleCount -= 1
        }
    }
    imp.wakeup(sleepforTimeout, checkActivity)
} // checkActivity

// now functions specific to devices that read i2c registers

// now app specific functions

// now general helper functions common to many apps

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
    
    vBatt.read() 
    // read count times and save min, max, and average
    while (i--){
        voltage = (2 * vBatt.read() / 65535.0) * hardware.voltage()
        if (voltage < tableVBatt.min) { tableVBatt.min = voltage }
        if (voltage > tableVBatt.max) { tableVBatt.max = voltage }
        tableVBatt.avg = tableVBatt.avg + voltage
    }
    tableVBatt.avg = tableVBatt.avg / tableVBatt.count
    return tableVBatt.avg
}

function wakeup() {
    log("woke up via pin1", 10)
}

////////////////////////////////////////////////////////
// first code starts here

imp.setpowersave(true) // start in low power mode.
    // Optimized for case where wakeup was caused by periodic timer, not user activity

// Register with the server
//imp.configure("MMA8452Q 1D6", [], []) // One 6-sided Die
// no in and out []s anymore, using Agent messages

// Send status to know we are alive
log("BOOTING  " + versionString + " " + hardware.getimpeeid() + "/" + imp.getmacaddress(), 0)
log("imp software version : " + imp.getsoftwareversion(), 10)

// BUGBUG: below needed until newer firmware!?  See http://forums.electricimp.com/discussion/comment/4875#Comment_2714
// imp.enableblinkup(true)

local lastUTCSeconds = time()
while(lastUTCSeconds == time()) {
}
offsetMilliseconds = hardware.millis() % 1000
log("offsetMilliseconds = " + offsetMilliseconds, 30)

log("powersave = " + imp.getpowersave(), 100)
// Configure pin1 for wakeup.  Connect MMA8452Q INT2 pin to imp pin1.
hardware.pin1.configure(DIGITAL_IN_WAKEUP, wakeup)
// Configure pin5 as ADC to read Vbatt/2.0
vBatt.configure(ANALOG_IN)

checkActivity() // kickstart checkActivity, this re-schedules itself every sleepforTimeout seconds
// FIXME: checkActivity waits from sleepforTimeout to sleepforTimeout*2.  Make this more constant.


// No more code to execute so we'll sleep until an interrupt from MMA8452Q.
// End of code.
// Electric Dice using MMA8452Q accelerometer */
// ThingApp Imp Device Squirrel code */