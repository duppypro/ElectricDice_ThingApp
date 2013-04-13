/* Electric Dice using MMA8452Q accelerometer */
/* CloudApp Electric Imp Agent Squirrel code */

/////////////////////////////////////////////////
// global constants and variables
const versionString = "MMA8452Q Dice v00.01.2013-04-04b"
const logIndent   = "-AGENT:_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>"
const errorIndent = "-AGENT:#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!" 
mapImpeeID_DieID <- {
    "233c2e018fb7bdee" : "I10100000001"
    "2360aa028fb7bdee" : "I10100000002"
}
const urlElectricDice = "http://interfacearts.webscript.io/electricdice"
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

function onHttpGetComplete(m)
{
  log("status was " + m.statuscode, 150)
  if (m.statuscode == 200) { // "OK"
    log("Proudly using " + m.headers.server, 150)
  }
}
 
device.onconnect(function() {
    log("Connect", 150)
})

device.ondisconnect(function() { // FIXME: send info to Dice server when disconnect 
    log("Disconnect", 150)
})

device.on("dieEvent", function(tableDieEvent) {
    if ("impeeID" in tableDieEvent) {
        tableDieEvent.dieID <- mapImpeeID_DieID[tableDieEvent.impeeID]
        delete tableDieEvent.impeeID
    }
    log("received dieEvent " + http.jsonencode(tableDieEvent), 100)
    http.get(urlElectricDice + "?" + http.urlencode(tableDieEvent)).sendasync(onHttpGetComplete)
})

// No more code to execute so we'll wait for messages from Device code.
// End of code.

