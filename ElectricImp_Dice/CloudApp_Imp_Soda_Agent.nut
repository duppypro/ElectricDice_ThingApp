// Generic Imp to Firebase Thingstream Agent
// CloudApp Electric Imp Agent Squirrel code

/////////////////////////////////////////////////
// global constants and variables

///////////////////////////////////////////////
// Firebase configuration and init 
fbRoot <- "https://electricdice-beta.firebaseio.com/stream/"
/****************** SECRET: ***************************************/ fbAuth <- "emRthqxr7UVV6Jw4SeEI9G65GA0CUXpfVN3eBoGO"
/****************** SECRET: ***************************************/
impAgentURLRoot <- http.agenturl()
impAgentURLRoot = impAgentURLRoot.slice(0, impAgentURLRoot.find("/", "https://".len()) + 1)
const fbUuidPrefix = "imp-v0-" // add prefix so that imp UUIDs do not collide with other Thingstream UUIDs
fbUuid <- fbUuidPrefix + http.agenturl().slice(impAgentURLRoot.len()) + "/"
// FIXME: Move UUID assignment to cloud
fbParamsTable <- {}
fbParamsTable.print <- "silent" // "pretty"
fbParamsTable.auth <- fbAuth
fbParamsString <- ".json?" + http.urlencode(fbParamsTable)
tsRoot <- fbRoot + fbUuid // pre-calc for speed?
// generic configuration and init
logVerbosity <- 100 // higer numbers show more log messages
errorVerbosity <- 1000 // higher number shows more error messages
const logIndent   = "_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>"

///////////////////////////////////////////////
// generic functions
function server.log(string, level) {
    if (level <= logVerbosity) {
        indent <- logIndent.slice(0, level / 10)
        server.log(indent + string)
    }
}

function server.error(string, level) {
    if (level <= errorVerbosity) {
        indent <- logIndent.slice(0, level / 10)
        server.error(indent + string)
    }
}

///////////////////////////////////////////////
// firebase specific functions
function getNow() {
    d <- date()
    // FIXME: add serverTimeOffset
    return format("%010d%03d", d.time, d.usec / 1000)
}

function streamThing(timeKey, dataTable) {
    // FIXME: this does not check for pre-existence of a duplicate timeKey.  So for now, 'By Design' this is last writer wins.
    http.request(
        "PUT",
        fbRoot + fbUuid + timeKey + fbParamsString,
        {},
        http.jsonencode(dataTable)
    ).sendasync(onHttpRequestComplete)
}

///////////////////////////////////////////////
// event handlers

// trigger events from REST for debugging
http.onrequest(function(req,res) {
    timeKey <- getNow()
    tableEvent <- req.query
    server.log("Received from REST: " + http.jsonencode(tableEvent))
    streamThing(timeKey, tableEvent)
    res.send(200,
        "Requested .set of \r\n"
        + http.jsonencode(tableEvent)
        + "\r\n to " + fbRoot + fbUuid + timeKey + "/.json")
})

function onHttpRequestComplete(m) {
    if (m.statuscode == 200) {
        server.log("Request Complete : " + m.body)
    } else if (m.statuscode == 201) {
        server.error("AUTH error " + m.statuscode + "\r\n" + m.body)
    } else {
        server.error("REQUEST error " + m.statuscode + "\r\n" + m.body)
    }
}

device.onconnect(function() {
    server.log("Connect")
})

device.ondisconnect(function() {
    server.log("Disconnect")
    // FIXME: send info to Dice server when disconnect 
})

device.on("event", function(tableEvent) {
    server.log("received dieEvent " + http.jsonencode(tableEvent))
    local timeKey = tableEvent.t // extract timestamp and make it the path
    delete tableEvent.t
    // append to firebase Thingstream
    streamThing(timeKey, tableEvent)
})


////////////////////////////////////////////////////////
// first Agent code starts here
server.log("Imp Agent URL : " + http.agenturl())
server.log("Agent SW version : " + imp.getsoftwareversion())
server.log("Thingstream Root : " + tsRoot)
server.log("fbParamsString: " + fbParamsString)
const versionString = "Remeber The Soda v00.01.2013-08-22a"
server.log("Ready for events.  Version : " + versionString)

// No more code to execute so we'll wait for messages from Device
// Remember The Soda
// CloudApp Electric Imp Agent Squirrel (.nut) code
// end of code
