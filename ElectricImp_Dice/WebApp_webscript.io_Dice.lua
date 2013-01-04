-- Example use:
---- where dieID == S10100000003
----  and dieValue == 6
---- http://interfacearts.webscript.io/electricdice?value=S10100000003,6
---- must put all params in single HTTP GET value param
----  because that is limit of electricimp HTTP GET API
local dieID_dieValue = request.query.value
-- dieValue is last character of string
local dieValue = string.sub(dieID_dieValue,-1)
-- dieID is first part of string up to the ","
local start_dieID = 1
local end_dieID = string.find(dieID_dieValue,",") - 1
local dieID = string.sub(dieID_dieValue, start_dieID, end_dieID)

if #dieID == 0 then
	dieID = "unknown"
end
-- add callback=0 param. Must be 0 for now as far as I can tell from pubnub.com documentation
dieID = dieID .. "/0/"

--log(dieID_dieValue)
log(dieID)
log(dieValue)

local response = http.request {
	url = 'https://api.electricimp.com/v1/576325708dfd870a/30eff61318bb0df6',
	params = {
		value = dieValue;
	}
}

local	pubnub_url = 'http://pubsub.pubnub.com/publish/pub-4f2aaa91-c35a-43ab-8387-f94285ad1829/sub-33f7cff3-d20f-11e1-86e9-a12a9356843b/0/'

local pubnub_GET = string.format("%s%s{\"%s\":\"%s\"}",pubnub_url,dieID,"roll",dieValue)
log(pubnub_GET)

local response = http.request {
	url = pubnub_GET
}

log(request.remote_addr)
log(request.querystring)
--log(response)

return string.format("Rolled a %s.", dieValue or "{UNKNOWN}")