/* Electric Dice using MMA8452Q accelerometer */
/* CloudApp Electric Imp Agent Squirrel code */

/////////////////////////////////////////////////
// global constants and variables
const versionString = "MMA8452Q Dice v00.01.2013-03-29b"
const logIndent   = "-AGENT:_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>"
const errorIndent = "-AGENT:#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!" 
dieID <- "I10100000001" // FIXME: assign this from a DNS
logVerbosity <- 100 // higer numbers show more log messages
errorVerbosity <- 1000 // higher number shows more error messages

///////////////////////////////////////////////
// constants for Firebase and/or PubNub or webscript.io

// helper variables ???

///////////////////////////////////////////////
//define functions
function log(string, level) {
    local indent = logIndent.slice(0, level / 10 + 7)
    if (level <= logVerbosity)
        server.log(indent + string)
}

function error(string, level) {
    local indent = errorIndent.slice(0, level / 10 + 7)
    if (level <= errorVerbosity)
        server.error(indent + string)
}

////////////////////////////////////////////////////////
// first Agent code starts here
log("BOOTING: " + versionString, 0)
log("Agent URL is " + http.agenturl(), 20)

device.onconnect(function() {
    log("Connect", 90)
})

device.ondisconnect(function() { // FIXME: send info to Dice server when disconnect 
    log("Disconnect", 90)
})

device.on("dieEvent", function(tableDieEvent) {
    log("received dieEvent " + http.jsonencode(tableDieEvent), 10)
})

// No more code to execute so we'll wait for messages from Device code.
// End of code.

