// Modified to read one button on pin 1

local webscriptioOutputPort = OutputPort("webscriptio_dieID_dieValue", "string");
local dieID = "S10100000004";
local wasButtonPressed = 1; // stay alive on boot as if button was pressed
local sleepforTimeout = 10.0; // seconds with no activity before calling server.sleepfor

function roll(dieValue) {
    local logMsg;
    logMsg = dieID + "," + dieValue;
    // Planner will send this to http://interfacearts.webscript.io/electricdice appending "?value=S10100000004,6" (example)
    webscriptioOutputPort.set(logMsg);
    server.log(logMsg);
    server.show(logMsg);
}

function eventButton()
{
    if (hardware.pin1.read() == 1) {  // FIXME: Experimentally there has been no need for debounce.  The neeed may show up with more testing.
        server.log("    buttonState === 1");
        roll(math.rand() % 6 + 1); // 1 - 6 for a six sided die
        wasButtonPressed = 1;
    } else {
        server.log("    buttonState === 0");
    }
}

function checkActivity()
{
    server.log("checkActivity();")
    if (wasButtonPressed == 1) {
        imp.wakeup(sleepforTimeout, checkActivity);
    } else {
        imp.onidle(function() { server.sleepfor(3600); });  // go to deepsleep if button not pressed for a while
    }
    wasButtonPressed = 0;
}

// Configure pin1 for wakeup with internal pull down.  Connect hardware button from pin1 to VCC
hardware.pin1.configure(DIGITAL_IN_WAKEUP,eventButton);

// Register with the server
imp.configure("Button to HTTP GET", [], [webscriptioOutputPort]);

// Send status to know we are alive
server.log(">>> Booted BigRedButton v00.01.20120205a");

server.log(">>> impee id==" + hardware.getimpeeid());
server.log(">>> impee MAC==" + imp.getmacaddress());
server.show("Press the Big Red Button");

imp.wakeup(sleepforTimeout, checkActivity);

// No more code to execute so we'll sleep until eventButton() occurs
// End of code.
