-- Example use:
---- where dieID == S10100000003
----  and dieValue == 6
---- Ex: http://interfacearts.webscript.io/electricdice?value=S10100000003,6
---- must put all params in single HTTP GET value param
----  because that is limit of electricimp HTTP GET API
-- If dieValue == 'query', return last saved value
---- Ex: http://interfacearts.webscript.io/electricdice?value=S10100000003,query

-- Define dieValue to color mapping for use by blink(1) IFTTT rule
local dieValue_to_color = {
	["1"] = "#FF0000",
	["2"] = "#00FF00",
	["3"] = "#0000FF",
	["4"] = "#00FFFF",
	["5"] = "#FF00FF",
	["6"] = "#FFDF00",
}

local versionString = "2013-02-05a";
-- Parse "{url}?value
local dieID_dieValue = request.query.value
-- dieID is first part of string up to the ","
local start_dieID = 1
local end_dieID = string.find(dieID_dieValue,",") - 1
local dieID = string.sub(dieID_dieValue, start_dieID, end_dieID)
if #dieID == 0 then
	dieID = "unknown"
end
log(dieID)
-- dieValue is end of string after the ","
local dieValue = string.sub(dieID_dieValue, end_dieID+2)
if #dieValue == 0 then
	dieValue= "x"
end
log(dieValue)

--check if this is a query
if dieValue == "query" then
	dieValue = storage[dieID] or "nil"
	log("Return early for query.")
	return string.format("Die %s last roll was a %s. Set blink(1) to %s.\r\n%s", dieID, dieValue or "{UNKNOWN}", dieValue_to_color[dieValue] or "#3F0F00", versionString)
end

-- if not save the value in webscript storage object
storage[dieID] = dieValue

---- and post to electricimp
local response = http.request {
	url = 'https://api.electricimp.com/v1/576325708dfd870a/30eff61318bb0df6',
	params = {
		value = dieID .. "," .. dieValue;
	}
}

---- and post to pubnub
local	pubnub_url = 'http://pubsub.pubnub.com/publish/pub-4f2aaa91-c35a-43ab-8387-f94285ad1829/sub-33f7cff3-d20f-11e1-86e9-a12a9356843b/0/'
local pubnub_GET = string.format("%s%s/0/{\"%s\":\"%s\"}",pubnub_url,dieID,"roll",dieValue)
log(pubnub_GET)
local response = http.request {
	url = pubnub_GET
}

log(request.remote_addr)
log(request.querystring)
--log(response)

return string.format("Die %s rolled a %s.\r\n%s", dieID, dieValue or "{UNKNOWN}", versionString)
