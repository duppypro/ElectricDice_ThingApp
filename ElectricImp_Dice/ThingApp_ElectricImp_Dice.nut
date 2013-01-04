// Modified to read one button on pin 1

local rolled1 = OutputPort("Rolled A 1", "string");
local rolled2 = OutputPort("Rolled A 2", "string");
local rolled3 = OutputPort("Rolled A 3", "string");
local rolled4 = OutputPort("Rolled A 4", "string");
local rolled5 = OutputPort("Rolled A 5", "string");
local rolled6 = OutputPort("Rolled A 6", "string");
local shake = OutputPort("Shaking", "string");
local pubnubOutputPort = OutputPort("pubnub_dieID_dieValue", "string");

function eventButton()
{
    local roll;
    local buttonState;
    local logMsg;
    // imp.sleep(0.050);
    // use imp.wakeup()
    // for hibernate use server.sleepfor()
    buttonState = hardware.pin1.read();
    server.log("buttonState === " + buttonState);
    roll = math.rand() % 8 + 1;
    if (roll <= 6) {
        logMsg = "{\"roll\":\"" + roll + "\"}";
    } else {
        logMsg = "{\"roll\":\"" + 7 + "\", \"shake\":\"1000\"}";
    }
    if (buttonState == 1) {
        server.log(logMsg)
        if (roll == 1) {
            rolled1.set(1);
        } else if (roll == 2) {
            rolled2.set(2);
        } else if (roll == 3) {
            rolled3.set(3);
        } else if (roll == 4) {
            rolled4.set(4);
        } else if (roll == 5) {
            rolled5.set(5);
        } else if (roll == 6) {
            rolled6.set(6);
        } else {
            shake.set(7);
        }    
        server.show(logMsg);
    }
}

hardware.pin1.configure(DIGITAL_IN_PULLUP,eventButton);

// Register with the server
imp.configure("Button to HTTP GET", [], [rolled1, rolled2, rolled3, rolled4, rolled5, rolled6, shake]);

server.log(">>> Booted BigRedButton v00.01");
server.log(">>> impee id==" + hardware.getimpeeid());
server.log(">>> impee MAC==" + imp.getmacaddress());
server.show("Press the Big Red Button");
server.show("on id " + hardware.getimpeeid());

// No more code to execute so we'll sleep until eventButton() occurs

// End of code.
