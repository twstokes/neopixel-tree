#include <Arduino.h>
#include <Adafruit_NeoPixel.h>
#include <ESP8266WiFi.h>
#include <WiFiUdp.h>

#include "commands.h"
#include "sequences.h"
#include "wifi_config.h"

#define PIN D1
#define PIXEL_COUNT 106
Adafruit_NeoPixel strip = Adafruit_NeoPixel(PIXEL_COUNT, PIN, NEO_GRB + NEO_KHZ800);

WiFiUDP Udp;
#define UDP_PORT 8733

char packet[255];

/*
  TODO:
    Brightness command
        - save between restarts?
    Ability to toggle gamma8

    Sequences:
      - off
      - color wipe
      - theater chase
      - rainbow
      - rainbow cycle
      - theater chase rainbow
      - variable speeds of sequences that take a delay parameter
*/

// initialize the strip and turn off all LEDs
void start_strip() {
    strip.begin();
    strip.show();
}

void start_wifi() {
  uint32_t orange = strip.gamma32(strip.Color(255, 87, 51));
  uint32_t green = strip.Color(0, 255, 0);

  // set the strip to orange before establishing a WiFi connection
  fill_and_show(&strip, orange);
  WiFi.config(ip, gateway, subnet);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    // give it a moment to connect by running a theater chase sequence
    theaterChase(&strip, orange, 50);
  }

  // WiFi is good - go green
  fill_and_show(&strip, green);
  delay(1000);
}

void start_udp() {
    Udp.begin(UDP_PORT);
}

void setup() {
  start_strip();
  start_wifi();
  start_udp();
}

void loop() {
  int packetSize = Udp.parsePacket();
  if (packetSize) {
    int len = Udp.read(packet, 255);
    if (len > 0) {
        process_command(packet[0], NULL, &strip); 
    }
  }


  // Some example procedures showing how to display to the pixels:
  // colorWipe(&strip, strip.Color(255, 0, 0), 50); // Red
  // colorWipe(&strip, strip.Color(0, 255, 0), 50); // Green
  // colorWipe(&strip, strip.Color(0, 0, 255), 50); // Blue

  // Send a theater pixel chase in...
  // theaterChase(&strip, strip.Color(127, 127, 127), 50); // White
  // theaterChase(&strip, strip.Color(127, 0, 0), 50); // Red
  // theaterChase(&strip, strip.Color(0, 0, 127), 50); // Blue

  // rainbow(&strip, 20);
  // rainbowCycle(&strip, 20);
  // theaterChaseRainbow(&strip, 50);
}
