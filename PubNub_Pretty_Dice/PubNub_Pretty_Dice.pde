/*
  Visualize status of two Cloud Dice.
  
  Data from each die accelerometer is received via wireless to
  JeeLink USB wireless receiver
  JeeLink wireless receiver sends data to USB serial port
  Format expected is space seperated ASCII values:
    OK {diceID} {xLoByte} {xHiByte} {yLoByte} {yHiByte} {zLoByte} {zHiByte}
*/

// Adapted from Tom Igoe's public domain Graphing sketch 
// Adaptations by David Proctor (@duppy) also in the public domain.
// Created 2012-04-01 by David Proctor
// Updated 2013-01-30 by David Proctor

import processing.serial.*;
Serial myPort;        // The serial port
static int baud = 57600;  //must match baud rate of sketch on JeeLink USB stick

int[] inXYZ = new int[3];  // raw values from string to int

int diceId = 0;
static int diceIdMin = 1;
static int diceIdMax = 2;
static int numDice = diceIdMax + 1 - diceIdMin;
String[] pubNubDiceId = new String[numDice];
//pubNubDieId[0] = "J10100000001"  // Jeelink nodeId 6
//pubNubDieId[1] = "S10100000003"  // Jeelink nodeId 7
//pubNubDieId[2] = "S10100000004"  // Jeelink nodeId 8 (dead, one wire needs re-solder)
//pubNubDieId[3] = "S10100000005"  // Jeelink nodeId 9
//pubNubDieId[4] = "I10100000001"  // Electric Imp version
//pubNubDieId[5] = "T10100000001"  // Duppy's Twine
//pubNubDieId[6] = "N10100000001"  // Duppy's NinjaBlock
String[] diceRoll = new String[numDice];
String[] lastDiceRoll = new String[numDice];

import processing.net.*;
Client client;
int numGETsBeforeStop = 37;
int pubCount = numGETsBeforeStop;
int testPeriod = 1500; // milliseconds between send test messages (sent during idle)
int idleTimeout = 5000; // milliseconds of no JeeLink msg recvd before going to idle
int throttleDelay = 1; // milliseconds after client.stop() FIXME:I'm still seeing java.net.SocketException: even with this delay
// keys for myinternetdice@gmail.com
//static String pubNubPubKey = "pub-1b4e9e64-d3c7-452d-a730-6e3bf9368653"; SECRET
//static String pubNubSubKey = "sub-dd119400-d20d-11e1-a576-a12a9356843b";
// keys for duppy@duppy.com twitter auth from pubnub.com
static String pubNubPubKey = "pub-4f2aaa91-c35a-43ab-8387-f94285ad1829"; // KEEP THIS SECRET
static String pubNubSubKey = "sub-33f7cff3-d20f-11e1-86e9-a12a9356843b";


String roll = "E"; // Error, should be changed before ever displayed.
static int oneGAxis = 200;
// TODO: autocalibrate resting X,Y,Z oneG
int xPosOneG = oneGAxis;
int xNegOneG = -oneGAxis;
int yPosOneG = oneGAxis;
int yNegOneG = -oneGAxis;
int zPosOneG = oneGAxis;
int zNegOneG = -oneGAxis;


PVector[] inPV = new PVector[numDice];
int[] inPVMag = new int[numDice];

static String server = "pubsub.pubnub.com";
static String publish = "/publish/";

float now;
float[] lastSerialMsg = new float[numDice];
float[] lastRandomTest = new float[numDice];
float[] lastPub = new float[numDice];

int w1, sep;
int d, w2;

int dataIn;   

void setup () {
  // set the dice and window size:
  w1 = 80;
  sep = 5;
  d = 20;
  w2 = 25;
  size(sep + w1 + sep + w1 + sep + w1 + sep, sep + w1 + sep + w1 + sep);        
  // set inital background:
  background(0);

  // List all the available serial ports
  println("Length: " + Serial.list().length);
  println(Serial.list());
  // Comment from Tom Igoe: I know that the first port in the serial list on my mac
  // is always my  Arduino, so I open Serial.list()[0].
  // Open whatever port is the one you're using.
  // TODO: Fix this!
  println("look for ports");
  if (Serial.list().length > 0) {
    myPort = new Serial(this, Serial.list()[0], baud);
    // don't generate a serialEvent() unless you get a newline character:
    myPort.bufferUntil('\n');
  } else {
    println("no serial ports found.");
  }

  now = millis();

  for (int i=0; i < numDice; i = i+1) {
    diceRoll[i] = "-";
    lastDiceRoll[i] = "-";
    lastPub[i] = now;
    lastSerialMsg[i] = now;
    lastRandomTest[i] = now;
    inPVMag[i] = (150 + 330) / 2; // fake idle Mag
  }
  
//  pubNubDiceId[0] = "J10100000001";  // nodeId 6
  pubNubDiceId[0] = "S10100000003";  // nodeId 7
//  pubNubDiceId[2] = "S10100000004";  // nodeId 8 (broken wire)
  pubNubDiceId[1] = "S10100000004";  // nodeId 8 (temporary send random values)
//  pubNubDiceId[3] = "S10100000005";  // nodeId 9
//  pubNubDiceId[4] = "S10100000006";  // nodeId 10

  client = new Client(this, server, 80);
  if (client == null) {
    println("create client for " + server + " FAILED.");
    exit();
  }

//  frameRate(60);
}

long lastTime = 0;

 
void draw () {
  
  now = millis();

  // global variables changed in the serialEvent()
  background(0);
  noStroke();
  smooth();
  ellipseMode(CENTER);
  
  int ox = sep, oy = sep;
  for (int i=0; i < numDice; i = i+1) {

    if (pubNubDiceId[i] == "S10100000003") {
      fill(255,0,0);
    } else {
      fill(255,255,255);
    }
    
    rect(ox,oy,w1,w1);  
    
    if (pubNubDiceId[i] == "S10100000003") {
      fill(255,255,255);
    } else {
      fill(255,0,0);
    }
    
    if (diceRoll[i].equals("1")) {
      ellipse(ox+w1/2,oy+w1/2,d,d);
    }
    if (diceRoll[i].equals("2")) {
      ellipse(ox+w1/2-w2,oy+w1/2-w2,d,d);
      ellipse(ox+w1/2+w2,oy+w1/2+w2,d,d);
    }
    if (diceRoll[i].equals("3")) {
      ellipse(ox+w1/2,oy+w1/2,d,d);
      ellipse(ox+w1/2+w2,oy+w1/2-w2,d,d);
      ellipse(ox+w1/2-w2,oy+w1/2+w2,d,d);
    }
    if (diceRoll[i].equals("4")) {
      ellipse(ox+w1/2-w2,oy+w1/2-w2,d,d);
      ellipse(ox+w1/2+w2,oy+w1/2+w2,d,d);
      ellipse(ox+w1/2+w2,oy+w1/2-w2,d,d);
      ellipse(ox+w1/2-w2,oy+w1/2+w2,d,d);
    }
    if (diceRoll[i].equals("5")) {
      ellipse(ox+w1/2,oy+w1/2,d,d);
      ellipse(ox+w1/2-w2,oy+w1/2-w2,d,d);
      ellipse(ox+w1/2+w2,oy+w1/2+w2,d,d);
      ellipse(ox+w1/2+w2,oy+w1/2-w2,d,d);
      ellipse(ox+w1/2-w2,oy+w1/2+w2,d,d);
    }
    if (diceRoll[i].equals("6")) {
      ellipse(ox+w1/2-w2,oy+w1/2-w2,d,d);
      ellipse(ox+w1/2+w2,oy+w1/2+w2,d,d);
      ellipse(ox+w1/2+w2,oy+w1/2-w2,d,d);
      ellipse(ox+w1/2-w2,oy+w1/2+w2,d,d);
      ellipse(ox+w1/2+w2,oy+w1/2,d,d);
      ellipse(ox+w1/2-w2,oy+w1/2,d,d);
    }
    
    ox = ox + w1 + sep;
    if (i == 2) { // jump down to next row
      ox = sep;
      oy = sep + w1 + sep;
    }

    if (lastSerialMsg[i] < (now - idleTimeout)) { // If no serial msg received for idleTimeout seconds
      if (lastRandomTest[i] < (now - testPeriod) ) { // if no randrom roll in testPeriod seconds
        lastRandomTest[i] = now;
        diceRoll[i] = "test" + int(random(1,7)); // random 1-6 inclusive
        inPVMag[i] = (150 + 330) / 2; // fake idle Mag
//        print(" " + i + "=#" + diceRoll[i] +"#");
      }
    }
  
    if ( (!lastDiceRoll[i].equals(diceRoll[i]))
        || (lastPub[i] < (now - 8000))
        || (inPVMag[i] < 150)
        || (inPVMag[i] > 330) ) {
// only publish if changed or too long since last or large movement
      
      lastDiceRoll[i] = diceRoll[i];  // set last roll to value of the roll we will publish
      
      if ( (pubCount <= 0)
           || (client == null) ) {  // don't post too many GETs before closing and reconnecting
        if (client != null) {
          print("WAITING...");
          while( (client.available() == 0) ) ;  // wait for response or new die roll
//          print("\r\n" + client.readString());
          print("CLOSING....");
          lastTime = millis();
          while (millis() - lastTime < throttleDelay) ;
          if (client != null) {
            client.stop();
            println("....CLOSED");
          } else {
            println("CLIENT CLOSED AFTER RESPONSE READ:");
          }
        } else {
          println("CLIENT CLOSED UNEXPECTEDLY");
          exit();
        }
        print("OPENING... ");
        client = new Client(this, server, 80);
        if (client == null) {
          println("create client for " + server + " FAILED.");
          exit();
        } else {
          println("new Client() SUCCESS!");
        }
        pubCount = numGETsBeforeStop;
      }   
/*
http://pubsub.pubnub.com/publish/pub-key/sub-key/0/S10100000004/0/{"roll":"test7"}
*/
/***** BUGBUGBUG
 * On Aug 22, 2012 the old code that used \" stopped working, showing up as x22 in pubnub history
 * I changed to %22 and it started working again.?????   There was a pubnub transmission delay issue on the same day.
 * TODO:  Add better error handling to my WebApp
 *****************/
      String a = "GET " + publish + pubNubPubKey + "/" + pubNubSubKey + "/0/" +
             pubNubDiceId[i] + "/0/{";
      a = a + "%22roll%22:%22" + diceRoll[i] + "%22,";
      a = a + "%22shake%22:%22" + inPVMag[i] + "%22";  // last item has no ending comma
      a = a + "} HTTP/1.1\r\n";
      String b = "Host: " + server + "\r\n";
      String c = "V: 3.1\r\n";
      String e = "User-Agent: Java\r\n";
      String f = "Accept: */*\r\n\r\n";
//      String shortGET = "\r\nGET ..." + a.substring(a.length() - 65, a.length() - 2);
      print("G"); print(pubNubDiceId[i].substring(0,2) + pubNubDiceId[i].substring(10,12));
      print(a.substring(a.length() - 41, a.length() - 40) ); // print(shortGET);
//      print(a);
      lastTime = millis();
      while (millis() - lastTime < throttleDelay) ;
      if (client == null) {
        println("CLIENT CLOSED UNEXPECTEDLY");
        exit();
      }
      client.write(a); client.write(b); client.write(c); client.write(e); client.write(f);
      lastPub[i] = now;
      pubCount = pubCount - 1;
    }
  }
}
 
void serialEvent (Serial myPort) {
  // get the ASCII string:
  String rawString = myPort.readStringUntil('\n');
  print("r");
//  print("RAW:"); print(rawString);
  String[] nums = splitTokens(rawString);

print(nums[0]);

  if (nums[0].equals("OK")) {
    diceId = int(nums[1]) - diceIdMin;
    lastSerialMsg[diceId] = millis();
   
    for (int i = 0; i < 3; i = i+1) {
      int j = 2+2*i; // position in text string of gravity axes values
      int hi = int(nums[j+1]);
      int lo = int(nums[j]);
      // convert 2 bytes to signed word
      if (hi < 128) { inXYZ[i] = int(256*hi) + lo; }
      else { inXYZ[i] = int(256*int(hi-255) + int(lo-255) - 1); }
    }
    
    // Fake calibrate  TODO: Add dynamic per die calibration
    inXYZ[0] = inXYZ[0] - 40;
    inXYZ[1] = inXYZ[1] + 15;
    inXYZ[2] = inXYZ[2] - 4;

    // Calculate Magnitude
    inPV[diceId] = new PVector(inXYZ[0], inXYZ[1], inXYZ[2]);
    inPVMag[diceId] = int(inPV[diceId].mag());

    // determine dice roll value (what side is up?)
    roll = "x";
    if (abs(inXYZ[1])<oneGAxis && abs(inXYZ[2])<oneGAxis && inXYZ[0] < xNegOneG)
      roll = "3";
    if (abs(inXYZ[1])<oneGAxis && abs(inXYZ[2])<oneGAxis && inXYZ[0] > xPosOneG)
      roll = "4";
    if (abs(inXYZ[0])<oneGAxis && abs(inXYZ[2])<oneGAxis && inXYZ[1] < yNegOneG)
      roll = "1";
    if (abs(inXYZ[0])<oneGAxis && abs(inXYZ[2])<oneGAxis && inXYZ[1] > yPosOneG)
      roll = "6";
    if (abs(inXYZ[0])<oneGAxis && abs(inXYZ[1])<oneGAxis && inXYZ[2] < zNegOneG)
      roll = "5";
    if (abs(inXYZ[0])<oneGAxis && abs(inXYZ[1])<oneGAxis && inXYZ[2] > zPosOneG)
      roll = "2";

    diceRoll[diceId] = roll;
//    print(" " + diceId + "=["+roll+"]");
//    print(" Mag:" + nfp(inPVMag[diceId], 4));
//    print(" <" + nfp(inXYZ[0],3) +","+ nfp(inXYZ[1],3) +","+ nfp(inXYZ[2],3) + ">");

  } else {
    print("?");
  }
}

void disconnectEvent(Client someClient) {
  print("X");
//  print("pubCount=" + pubCount + ", Server Says:  ");
//  dataIn = someClient.read();
//  println(dataIn);
//  background(dataIn);  // I forgot why I added this? Doesn't make sense.
}

