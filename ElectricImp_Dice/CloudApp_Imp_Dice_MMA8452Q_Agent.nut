// Generic Elextric Imp Agent to Thingstream on Firebase

// Firebase configuration and init 
fbRoot <- "https://electricdice-beta.firebaseio.com/stream/"
///****************** SECRET: ***************************************/ fbAuth <- "PasteSecretFirebaseAuthKeyHere"
/****************** SECRET: ***************************************/ fbAuth <- "emRthqxr7UVV6Jw4SeEI9G65GA0CUXpfVN3eBoGO"
/****************** SECRET: ***************************************/
const fbUuidPrefix = "imp-v0-" // add unique prefix so that imp UUIDs do not collide with other Thingstream UUIDs
// CONSTRAINT: Assumes first 30 chars of http.agenturl() are root and remainder are UUID
fbUuid <- fbUuidPrefix + http.agenturl().slice(30) + "/"
// FIXME: Move UUID assignment to cloud
fbParamsTable <- {}
fbParamsTable.print <- "silent" // "silent" or "pretty"
fbParamsTable.auth <- fbAuth
fbParamsString <- "/.json?" + http.urlencode(fbParamsTable)
tsRoot <- fbRoot + fbUuid // pre-calc Thingstream root for speed?

// firebase specific functions
function getNow() {
    d <- date()
    // FIXME: add serverTimeOffset
    return format("%010d%03d", d.time, d.usec / 1000)
}

function streamThing(timeKey, dataTable) {
    // FIXME: this does not check for pre-existence of a duplicate timeKey.  So for now, 'By Design' this is last writer wins.
    // server.log(tsRoot + timeKey + fbParamsString)
    // server.log(http.jsonencode(dataTable))
    http.request(
        "PUT",
        tsRoot + timeKey + fbParamsString,
        {},
        http.jsonencode(dataTable)
    ).sendasync(onHttpRequestComplete)
}

// event handlers
// trigger events from REST for debugging
http.onrequest(function(req,res) {
    timeKey <- getNow()
    tableEvent <- req.query
    server.log("Received from REST: " + http.jsonencode(tableEvent)
        + "\r\n at " + timeKey
    )
    streamThing(timeKey, tableEvent)
    res.send(200,
        "Requested .set of \r\n"
        + http.jsonencode(tableEvent)
        + "\r\n to " + tsRoot + timeKey + fbParamsString
    )
})

function onHttpRequestComplete(m) {
    if (m.statuscode == 200) {
        server.log("Request Complete : " + m.body)
    } else if (m.statuscode == 204) {
        // server.log("Request Complete : " + m.body)
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

// first Agent code starts here (event handlers already running)
server.log("Imp Agent URL      :   " + http.agenturl())
server.log("Agent SW version   :   " + imp.getsoftwareversion())
server.log("Thingstream Root   :   " + tsRoot)
server.log("fbParamsString     :   " + fbParamsString)
server.log("Version            :   MMA8452Q Dice v00.01.2013-08-26a")
server.log("Waiting for events...")

// No more code to execute so we'll wait for messages from Device
// Electric Imp Agent Squirrel (.nut) code
// end of code
