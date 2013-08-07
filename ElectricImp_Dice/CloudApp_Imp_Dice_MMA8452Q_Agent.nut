// Electric Dice using MMA8452Q accelerometer */
// CloudApp Electric Imp Agent Squirrel code */

/////////////////////////////////////////////////
// global constants and variables

// generic
const versionString = "MMA8452Q Dice v00.01.2013-07-15a"
const logIndent   = "-AGENT:_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>_________>"
const errorIndent = "-AGENT:#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!#########!" 
logVerbosity <- 100 // higer numbers show more log messages
errorVerbosity <- 1000 // higher number shows more error messages
fakeMillis <- 42 // fake out millisecond times for debugging

// dice specific
mapImpeeID_DieID <- {
    "233c2e018fb7bdee" : "I10100000001"
    "2360aa028fb7bdee" : "I10100000002"
}
ubidotsToken <- ""

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
http.onrequest(function(req,res) {
    local tableEvent = {}
    local timestamp = format("%010d%03d", time(), fakeMillis)
    fakeMillis = (fakeMillis + 17) % 1000 // guarantee we have unique timestamps
    tableEvent[timestamp] <- req.query
    log("Received from REST: " + http.jsonencode(tableEvent), 100)

    // now append to ubidots
    http.request(
        "POST",
        "http://things.ubidots.com/api/variables/51c22105f91b28585e2430f4/values",
        {"Content-Type": "application/json",
            "X-Auth-Token": "bZ03WNcKxU8UWeF88nz46hHKjcjHz5so2FBQ6O5cuzBsIs5QoSRkudRlcD--"},
         "{ \"value\": " + tableEvent[timestamp].roll + "}"
         // "{ \"value\": " + http.jsonencode(tableEvent) + "}"
         // '{"value":' + http.jsonencode(tableEvent) + '}'
    ).sendasync(onHttpRequestComplete)

    // now append to firebase thingstream
    http.request(
        "PATCH",
        firebaseURLRoot + firebaseUUID + ".json",
        {},
        http.jsonencode(tableEvent)
    ).sendasync(onHttpRequestComplete)
    res.send(200,
        "Requested append\r\n"
        + http.jsonencode(tableEvent)
        + "\r\n to " + firebaseURLRoot + firebaseUUID + ".json")
})

// dice specific

device.onconnect(function() {
    log("Connect", 100)
})

device.ondisconnect(function() { // FIXME: send info to Dice server when disconnect 
    log("Disconnect", 100)
})

device.on("dieEvent", function(tableDieEvent) {
    log("received dieEvent " + http.jsonencode(tableDieEvent), 1000)
    foreach(val in tableDieEvent) {
        if ("impeeID" in val) {
            val.dieID <- mapImpeeID_DieID[val.impeeID]
            delete val.impeeID
        }
    }
    // post to firebase
    http.request(
        "PATCH",
        firebaseURLRoot + firebaseUUID + ".json",
        {},
        http.jsonencode(tableDieEvent)
    ).sendasync(onHttpRequestComplete)
    // post to ubidots
    foreach(idx, val in tableDieEvent) {
        if ("roll" in val) {
            try {
                http.request(
                    "POST",
                    "http://things.ubidots.com/api/variables/51c22105f91b28585e2430f4/values",
                    {"Content-Type": "application/json",
                        "X-Auth-Token": ubidotsToken},
                     "{ \"value\": " + val.roll.tointeger() + " }"
                ).sendasync(onHttpRequestComplete)
            } catch (e) {
                // if tointeger() fails    
            }
        }
    }
})


////////////////////////////////////////////////////////
// first Agent code starts here
log("BOOTING: " + versionString, 0)
log("Imp Agent URL: " + http.agenturl(), 0)
log("Agent SW version: " + imp.getsoftwareversion(), 10)
impAgentURLRoot <- http.agenturl()
impAgentURLRoot = impAgentURLRoot.slice(0, impAgentURLRoot.find("/", "https://".len()) + 1)
log("firebaseURLRoot: " + firebaseURLRoot, 10)
firebaseUUID <- firebaseUUIDPrefix + http.agenturl().slice(impAgentURLRoot.len()) + "/"
log("firebaseUUID: " + firebaseUUID, 10)
firebaseURLParamsString <- ".json?" + http.urlencode(firebaseURLParamsTable)
log("firebaseURLParamsString: " + firebaseURLParamsString, 10)

function onHttpRequestComplete(m) {
    if (m.statuscode == 200) {
        log("Request Complete : " + m.body, 1000)
    } else if (m.statuscode == 201) {
        if ("token" in http.jsondecode(m.body)) {
            ubidotsToken = http.jsondecode(m.body).token
            log("Ubidots token : " + ubidotsToken, 100)
        } else {
            log("non-error statuscode 201 : " + m.body, 1000)
        }
    } else {
        error("REQUEST error " + m.statuscode + "\r\n" + m.body, 10)
    }
}
 
// get ubidots token
    http.request(
        "POST",
        "http://things.ubidots.com/api/auth/token",
        {"X-Ubidots-ApiKey": "b42c3ab73b2b0cb7ba17d0c6b737aa564d94751e"},
        ""
    ).sendasync(onHttpRequestComplete)
    // token = bZ03WNcKxU8UWeF88nz46hHKjcjHz5so2FBQ6O5cuzBsIs5QoSRkudRlcDlm

// No more code to execute so we'll wait for messages from Device code.
// End code.
// Electric Dice using MMA8452Q accelerometer */
// CloudApp Electric Imp Agent Squirrel code */