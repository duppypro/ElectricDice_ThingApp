#! python
# 
# jeelink2pubnub.py
# Reads Serial Messages from a JeeLink USB COM port
# and publishes them to a http://www.PubNub.com channel
# 
# Data from each die accelerometer is received via wireless to
# JeeLink USB wireless receiver to USB serial port
#   
# Format expected is space seperated ASCII values:
# "OK {diceID} {xLoByte} {xHiByte} {yLoByte} {yHiByte} {zLoByte} {zHiByte}"
# 
# Written by @duppy
#     Created: 2012-07-26
#     Updated: 2012-07-26
#
# Tested on:
#     Windows 7 64bit
#     Python 2.7.3 32bit
#     pyserial-py3k-2.5 32bit
#     JeeLink v2 http://JeeLabs.org/jl2

import serial
import pubnub

port = 'COM1'
baud = 57600
pubNubPubKey = "pub-1b4e9e64-d3c7-452d-a730-6e3bf9368653"
pubNubSubKey = "sub-dd119400-d20d-11e1-a576-a12a9356843b"
pubNubDiceId[0] = "J10100000001"  # nodeId 6
pubNubDiceId[1] = "S10100000003"  # nodeId 7
pubNubDiceId[2] = "S10100000004"  # nodeId 8
pubNubDiceId[3] = "S10100000005"  # nodeId 9
pubNubDiceId[4] = "S10100000006"  # nodeId 10

jeelink = serial.Serial(port=port,
                        baudrate=baud,
                        bytesize=8,
                        parity='N',
                        stopbits=1,
                        timeout=None,
                        xonxoff=False,
                        rtscts=False,
                        dsrdtr=False)
                        
while 1:
    print jeelink.readline()
                        
                        
####################################
# below this is snippets from processing.org version that I may need
#######################################

import processing.serial.*;
Serial myPort;        // The serial port
static int baud = 57600;  //must match baud rate of sketch on JeeLink USB stick

int xPos = 0;         // horizontal position of the graph
int[] inXYZ = new int[3];  // raw values from string to int
int[] vizXYZ = new int[3];  // values scaled to fit graph window size

int diceId = 0;
static int diceIdMin = 7;
static int diceIdMax = 8;
static int numDice = diceIdMax + 1 - diceIdMin;
String[] diceRoll = new String[numDice];
String[] lastDiceRoll = new String[numDice];

import processing.net.*;
Client client;
String[] pubNubDiceId = new String[numDice];
int pubCount = 4;
static String pubNubPubKey = "pub-1b4e9e64-d3c7-452d-a730-6e3bf9368653";
static String pubNubSubKey = "sub-dd119400-d20d-11e1-a576-a12a9356843b";


String roll = "E"; // Error, should be changed before ever displayed.
static int oneGAxis = 150;

PVector[] inPV = new PVector[numDice];
PVector[] vizPV = new PVector[numDice];
float[] inPVMag = new float[numDice];

PFont metaBold;

static String server = "pubsub.pubnub.com";
static String publish = "/publish/";
byte[] byteBuffer = new byte[1200];

float lastSerialMsg, now, lastRandomTest;
float[] lastPub = new float[numDice];
    
# void setup () {


  
 # now = millis();
 # lastSerialMsg = now;
 # lastRandomTest = now;

 # for (int i=0; i < numDice; i = i+1) {
 #   diceRoll[i] = "-";
 #   lastDiceRoll[i] = "-";
 #   lastPub[i] = now;
 # }
  
  pubNubDiceId[0] = "S10100000003";
  pubNubDiceId[1] = "S10100000004";

  client = new Client(this, server, 80);

  frameRate(12);
}
 
void draw () {
  
  now = millis();
//  println("now:"+now+", lastSer:"+lastSerialMsg+", lastRand:"+lastRandomTest);
  if (lastSerialMsg < (now - 5000)) { // If no serial msg received for 5 seconds
    println("*** Dice timed out");
    if (lastRandomTest < (now - 6000) ) { // if no randrom roll in 7-1 seconds
      lastRandomTest = now;
      for (int i=0; i < numDice; i = i+1) {
        diceRoll[i] = "test" + int(random(1,8)); // include 7 as a blank face
        print("{" + diceRoll[i] + "}");
      }
      println();
    }
  }
  // global variables changed in the serialEvent()
  background(0);
  noStroke();
  smooth();
  ellipseMode(CENTER);
  
  int w1 = 320, sep = 500, ox = 200, oy = 100;
  
  for (int i=0; i < numDice; i = i+1) {
    if (i==0) { fill(255,0,0); }
    else { fill(255,255,255); }
    
    rect(ox+i*sep,oy,w1,w1);  
    
    if (i==1) { fill(255,0,0); }
    else { fill(255,255,255); }
    
    int d = 80, w2 = 100;

    String sampDiceRoll = diceRoll[i]; // SerialEvent may change this asynch so sample it.
    if ( (lastDiceRoll[i] != sampDiceRoll) || (lastPub[i] < (now - 4000)) ) {  // only publish if changed or too long since last
      lastDiceRoll[i] = sampDiceRoll;
      lastPub[i] = now;
/*
"http://pubsub.pubnub.com/publish/pub-key/sub-key/0/S10100000004/0/%7B%22roll%22:%225%22%7D"
*/
    if (pubCount == 0) {
//      if (client == null) {
        while(client.available() == 0);  // wait for response
        client.stop();
//      }
      client = new Client(this, server, 80);
      pubCount = 8;
    }
  //    delay(50);
  
  String a = "GET " + publish + pubNubPubKey + "/" + pubNubSubKey + "/0/" +
         pubNubDiceId[i] + "/0/{\"roll\":\"" + diceRoll[i] + "\"} HTTP/1.1\r\n";
  String b = "Host: " + server + "\r\n";
  String c = "V: 3.1\r\n";
  String e = "User-Agent: Python\r\n";
  String f = "Accept: */*\r\n\r\n";
  print(a);
      client.write(a); client.write(b); client.write(c); client.write(e); client.write(f);
      pubCount = pubCount - 1;
  
//      while(client.available() == 0);  // wait for response
//      delay(10);
//      int byteCount = client.readBytesUntil(']', byteBuffer); 
      // Convert the byte array to a String
//      String myString = new String(byteBuffer);
      // Display the string
//      print(client.readString());
//      client.stop();
    }
    
    if (diceRoll[i].equals("1")) {
      ellipse(ox+i*sep+w1/2,oy+w1/2,d,d);
    }
    if (diceRoll[i].equals("2")) {
      ellipse(ox+i*sep+w1/2-w2,oy+w1/2-w2,d,d);
      ellipse(ox+i*sep+w1/2+w2,oy+w1/2+w2,d,d);
    }
    if (diceRoll[i].equals("3")) {
      ellipse(ox+i*sep+w1/2,oy+w1/2,d,d);
      ellipse(ox+i*sep+w1/2+w2,oy+w1/2-w2,d,d);
      ellipse(ox+i*sep+w1/2-w2,oy+w1/2+w2,d,d);
    }
    if (diceRoll[i].equals("4")) {
      ellipse(ox+i*sep+w1/2-w2,oy+w1/2-w2,d,d);
      ellipse(ox+i*sep+w1/2+w2,oy+w1/2+w2,d,d);
      ellipse(ox+i*sep+w1/2+w2,oy+w1/2-w2,d,d);
      ellipse(ox+i*sep+w1/2-w2,oy+w1/2+w2,d,d);
    }
    if (diceRoll[i].equals("5")) {
      ellipse(ox+i*sep+w1/2,oy+w1/2,d,d);
      ellipse(ox+i*sep+w1/2-w2,oy+w1/2-w2,d,d);
      ellipse(ox+i*sep+w1/2+w2,oy+w1/2+w2,d,d);
      ellipse(ox+i*sep+w1/2+w2,oy+w1/2-w2,d,d);
      ellipse(ox+i*sep+w1/2-w2,oy+w1/2+w2,d,d);
    }
    if (diceRoll[i].equals("6")) {
      ellipse(ox+i*sep+w1/2-w2,oy+w1/2-w2,d,d);
      ellipse(ox+i*sep+w1/2+w2,oy+w1/2+w2,d,d);
      ellipse(ox+i*sep+w1/2+w2,oy+w1/2-w2,d,d);
      ellipse(ox+i*sep+w1/2-w2,oy+w1/2+w2,d,d);
      ellipse(ox+i*sep+w1/2+w2,oy+w1/2,d,d);
      ellipse(ox+i*sep+w1/2-w2,oy+w1/2,d,d);
    }
  }
  
}
 
void serialEvent (Serial myPort) {
  // get the ASCII string:
  String rawString = myPort.readStringUntil('\n');
  String[] nums = splitTokens(rawString);
   
  if (nums[0].equals("OK")) {
//    print("RAW:"); print(rawString);
    lastSerialMsg = millis();
    diceId = int(nums[1]) - diceIdMin;
    for (int i = 0; i < 3; i = i+1) {
      int j = 2+2*i; // position in text string of gravity axes values
      int hi = int(nums[j+1]);
      int lo = int(nums[j]);
      // convert 2 bytes to signed word
      if (hi < 128) { inXYZ[i] = int(256*hi) + lo; }
      else { inXYZ[i] = int(256*int(hi-255) + int(lo-255) - 1); }
      // map raw values to screen co-ord
      vizXYZ[i] = int( map(inXYZ[i], -512, 511, 0, int(height/3)) );
//      stroke(0,255,0);
//      line(xPos, height*(i+1)/3, xPos, height*(i+1)/3 - vizXYZ[i]);
    }
    inPV[diceId] = new PVector(inXYZ[0], inXYZ[1], inXYZ[2]);
    inPVMag[diceId] = inPV[diceId].mag();
//    print(inPVMag[diceId]);
    // determine dice roll value (what side is up?)
    roll = "x";
    if (abs(inXYZ[0])<oneGAxis && abs(inXYZ[2])<oneGAxis && inXYZ[1]<-oneGAxis)
      roll = "1";
    if (abs(inXYZ[0])<oneGAxis && abs(inXYZ[2])<oneGAxis && inXYZ[1]>oneGAxis)
      roll = "6";
    if (abs(inXYZ[0])<oneGAxis && abs(inXYZ[1])<oneGAxis && inXYZ[2]<-oneGAxis)
      roll = "5";
    if (abs(inXYZ[0])<oneGAxis && abs(inXYZ[1])<oneGAxis && inXYZ[2]>oneGAxis)
      roll = "2";
    if (abs(inXYZ[1])<oneGAxis && abs(inXYZ[2])<oneGAxis && inXYZ[0]<-oneGAxis)
      roll = "3";
    if (abs(inXYZ[1])<oneGAxis && abs(inXYZ[2])<oneGAxis && inXYZ[0]>oneGAxis)
      roll = "4";
    
    print(" ["+roll+"] ");
//    lastDiceRoll[diceId] = diceRoll[diceId];
    diceRoll[diceId] = roll;
    
    // draw the line:
//    println( nfp(inXYZ[0],4) +","+ nfp(inXYZ[1],4) +","+ nfp(inXYZ[2],4) );
  }
}