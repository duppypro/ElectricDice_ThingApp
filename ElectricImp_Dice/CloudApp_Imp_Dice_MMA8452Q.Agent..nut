// Electric Dice using MMA8452Q accelerometer */
// CloudApp Electric Imp Agent Squirrel code */

/////////////////////////////////////////////////
// global constants and variables

// generic
const versionString = "MMA8452Q Dice v00.01.2013-08-06a"
const logIndent   = "-AGENT:_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>"
const errorIndent = "-AGENT:#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!" 
logVerbosity <- 100 // higer numbers show more log messages
errorVerbosity <- 1000 // higher number shows more error messages

// dice specific
mapImpeeID_DieID <- {
    "233c2e018fb7bdee" : "I10100000001"
    "2360aa028fb7bdee" : "I10100000002"
}

///////////////////////////////////////////////
// constants for Firebase and/or webscript.io

// where to post to webscript.io (which posts(gets) to pubnub)
const urlElectricDice = "http://interfacearts.webscript.io/electricdice"

// which firebase to use
firebaseURLRoot <- "https://electricdice-beta.firebaseio.com/stream/"
//firebaseURLRoot <- "https://electricdice.firebaseio.com/stream/"
const firebaseUUIDPrefix = "imp-v0-" // add prefix so that imp UUIDs do not collide with other Thing UUIDs
firebaseURLParamsTable <- {}
firebaseURLParamsTable.print <- "pretty"
firebaseURLParamsTable.format <- "export"

// helper variables ???

///////////////////////////////////////////////
//define functions

//generic
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

// firebase specific
httpResponse <- {}
http.onrequest(function(req,res) {
    log("posting: " + http.jsonencode(req.query), 100)
    http.post(
        firebaseURLRoot + firebaseUUID + ".json",
        {},
        http.jsonencode(req.query)
    ).sendasync(onHttpPostComplete)
    log("getting: " + firebaseURLRoot + firebaseUUID + firebaseURLParamsString, 100)
    httpResponse = res
    http.get(
        firebaseURLRoot + firebaseUUID + firebaseURLParamsString,
        {}
    ).sendasync(onHttpGetComplete)
})

// dice specific

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
//old webscript.io call    http.get(urlElectricDice + "?" + http.urlencode(tableDieEvent)).sendasync(onHttpGetComplete)
    http.post(
        firebaseURLRoot + firebaseUUID + ".json",
        {},
        http.jsonencode(tableDieEvent)
    ).sendasync(onHttpPostComplete)
})


////////////////////////////////////////////////////////
// first Agent code starts here
log("BOOTING: " + versionString, 0)
log("Imp Agent URL: " + http.agenturl(), 0)
impAgentURLRoot <- http.agenturl()
impAgentURLRoot = impAgentURLRoot.slice(0, impAgentURLRoot.find("/", "https://".len()) + 1)
firebaseUUID <- firebaseUUIDPrefix + http.agenturl().slice(impAgentURLRoot.len())
log("firebaseURLRoot: " + firebaseURLRoot, 0)
log("firebaseUUID: " + firebaseUUID, 0)
firebaseURLParamsString <- ".json?" + http.urlencode(firebaseURLParamsTable)
log("firebaseURLParamsString: " + firebaseURLParamsString, 100)

function onHttpPostComplete(m) // FIXME:
{
    log("POST response: " + m.body, 150)
}

function onHttpGetComplete(m) // FIXME: not used unless I use .sendasync() ???
{
    log("GET response: " + m.body, 100)
    httpResponse.send(200, m.body)
}
 
// No more code to execute so we'll wait for messages from Device code.
// End code.
// Electric Dice using MMA8452Q accelerometer */
// CloudApp Electric Imp Agent Squirrel code */