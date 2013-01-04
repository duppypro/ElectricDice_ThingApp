// Demo of the Gravity Plug, based on the GravityPlug class in the Ports library
// 2010-03-19 <jc@wippler.nl> http://opensource.org/licenses/mit-license.php
//
// Modified extensivly for the Cloud Dice project by @duppy
//  All modifications by @duppy open source
// Created 2012-04-01
// Updated 2012-07-27

// SCHEMATIC
  //  Arduino compatible is Seeeduino Film from SeeedStudio
  //    Board type: Arduino Pro or Pro Mini (3.3V, 8 MHz) w/ ATmega168
  //  Accel (Gravity Plug from JeeLabs.org/gp1 ) is on
  //    PC0(A0) - SCL
  //    PD3(D3) - IRQ
  //    PD4(D4) - SDA
  //  RFM12BS Rev4.0 from HopeRF is on 
  //    D2  - nIRQ
  //    D10 - nSEL
  //    D11 - SDI
  //    D12 - SDO
  //    D13 - SCK

#include <JeeLib.h>

PortI2C myBus (1);
GravityPlug sensor (myBus);

MilliTimer measureTimer;

boolean serOut = CHANGE; // true for debugging, false to save power
byte nodeId = CHANGE; // unique ID needs to be different for each die.
// TODO: Add dynamic nodeId assignment and store in PROM
//  pubNubDiceId[0] = "J10100000001";  // nodeId 6
//  pubNubDiceId[1] = "S10100000003";  // nodeId 7
//  pubNubDiceId[2] = "S10100000004";  // nodeId 8
//  pubNubDiceId[3] = "S10100000005";  // nodeId 9
//  pubNubDiceId[4] = "S10100000006";  // nodeId 10

const int readInterval = 83; // read the accelerometer every readInterval millis
int ledPin = 8; // status and debugging LED
                // pin 8 or Seeed Film, pin 9 for std Arduino
int ledInterval = 25; // Flash LED every this many reads
int ledCount = ledInterval;
int rfIntervalActive = 1; // Send RF every this many accel reads when Active
int rfIntervalSleep = 6 * 12; // Send RF every this many accel reads when Sleep
int rfInterval = rfIntervalActive; // Start in Active mode
int rfCount = rfInterval;
int stillLimit = 6 * 60 * 12; // Sleep if still for this many accel reads
int stillCount = stillLimit;
int stillMagLimit = 330; // less than this single axes accel reading is no movement

void setup () {
  
  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, HIGH);  // turn on to signal boot

  if (serOut) {
    Serial.begin(57600);
    Serial.println("\n[dice_test_FILM-2012-08-02]");
  }
  rf12_initialize(nodeId, RF12_915MHZ, 5); // init RF
  sensor.begin(); // init accelerometer
  
  digitalWrite(ledPin, LOW);  // boot and init succesfull

}

void loop () {

  if (measureTimer.poll(readInterval)) {

    if (ledCount == 1) {
      digitalWrite(ledPin, HIGH);
      ledCount = ledInterval;
    } else {
      ledCount = ledCount - 1;
    }

    // Read Acceleromoeter
    const int* p = sensor.getAxes();
    
    // check for movement
    int max = 0;
    int i;
    for (i = 0; i < 3; i = i + 1) {
      if (abs(p[i]) > max) {
        max = abs(p[i]);
      }
    }
    if (rfInterval == rfIntervalSleep) { // if sleeping
      if (max > stillMagLimit) { // if moved
        rfInterval = rfIntervalActive; // switch to Active mode
        rfCount = 1; // start sending RF right away
      } else { // if not moved stay sleeping
        stillCount = stillLimit;
      }
    } else { // if active mode
      if (max > stillMagLimit) { // if still moving
        stillCount = stillLimit; // reset still counter
      } else { // if not moved count how long it is still
        if (stillCount == 1) { // been still for a long time
          rfInterval = rfIntervalSleep; // switch to Sleep mode
          rfCount = rfInterval; // dont send RF right away
        } else { // countdown how many times die has been still in a row
          stillCount = stillCount - 1;
        }
      }
    }
    
    if (serOut) {
      Serial.print("G"); Serial.print(nodeId);
      Serial.print(' '); Serial.print(p[0]);
      Serial.print(' '); Serial.print(p[1]);
      Serial.print(' '); Serial.println(p[2]);
    }
    
    if (rfCount == 1) {
      if (serOut) {
        digitalWrite(ledPin, HIGH); // also flash LED every RF if serOut mode
      }
      while (!rf12_canSend())
        rf12_recvDone();
      if (serOut) {
        Serial.print("RF12");
      }
      rf12_sendStart(0, p, 3 * sizeof *p);
      rf12_sendWait(2);  
      rfCount = rfInterval;
    } else {
      rfCount = rfCount - 1;
    }


    digitalWrite(ledPin, LOW);  // RF send completed
  
  }

}
