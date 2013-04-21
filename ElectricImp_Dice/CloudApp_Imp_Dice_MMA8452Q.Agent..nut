/* Electric Dice using MMA8452Q accelerometer */
/* CloudApp Electric Imp Agent Squirrel code */

/////////////////////////////////////////////////
// global constants and variables

// generic
const versionString = "MMA8452Q Dice v00.01.2013-04-21a"
const logIndent   = "-AGENT:_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>"
const errorIndent = "-AGENT:#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!" 
logVerbosity <- 200 // higer numbers show more log messages
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
const betaURL = "-beta" // or "" for public website
firebaseURLRoot <- "https://electricdice" + betaURL + ".firebaseio.com/stream/"
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
http.onrequest(function(req,res) {
    if (req.path == "") {
        req.query[".priority"] <- clock()
        log("posting: " + http.jsonencode(req.query), 150)
        postRes <- 
            http.post(
                firebaseURLRoot + firebaseUUID + ".json",
                {},
                http.jsonencode(req.query)
            ).sendsync()
        log("post response: " + postRes.body, 200)
/*
        readRes <-
            http.get(
                firebaseURLRoot + firebaseUUID + firebaseURLParamsString
            ).sendsync().body
        log("read response: " + readRes, 200)
        res.send(200, readRes)
*/
        res.send(200, postRes.body)
    }
});

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
    http.get(urlElectricDice + "?" + http.urlencode(tableDieEvent)).sendasync(onHttpGetComplete)
})


////////////////////////////////////////////////////////
// first Agent code starts here
log("BOOTING: " + versionString, 0)
log("Imp Agent URL: " + http.agenturl(), 0)
impAgentURLRoot <- http.agenturl()
impAgentURLRoot = impAgentURLRoot.slice(0, impAgentURLRoot.find("/", "https://".len()) + 1)
firebaseUUID <- firebaseUUIDPrefix + http.agenturl().slice(impAgentURLRoot.len())
log("firebaseUUID: " + firebaseUUID, 0)
firebaseURLParamsString <- ".json?" + http.urlencode(firebaseURLParamsTable)
log("firebaseURLParamsString: " + firebaseURLParamsString, 200)

function onHttpGetComplete(m) // FIXME: not used unless I use .sendasync() ???
{
  log("status was " + m.statuscode, 150)
  if (m.statuscode == 200) { // "OK"
    log("Proudly using " + m.headers.server, 150)
  }
}
 
// No more code to execute so we'll wait for messages from Device code.
// End of code.