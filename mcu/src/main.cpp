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

#define UDP_PORT 8733
WiFiUDP Udp;

#define UDP_BUFFER_SIZE 255
uint8_t packet[UDP_BUFFER_SIZE];


// initialize the strip and turn off all LEDs
void start_strip() {
    strip.begin();
    strip.show();
}

// start WiFi with visual feedback
void start_wifi() {
  uint32_t orange = strip.gamma32(strip.Color(255, 87, 51));
  uint32_t green = strip.Color(0, 255, 0);

  // set the strip to orange before establishing a WiFi connection
  fill_and_show(orange, &strip);

  WiFi.config(ip, gateway, subnet);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    // give it a moment to connect by running a theater chase sequence
    theaterChase(orange, 50, &strip);
  }

  // set the strip to green on success
  fill_and_show(green, &strip);
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
  if (Udp.parsePacket()) {
    uint8_t command_packet_length = Udp.read(packet, UDP_BUFFER_SIZE);
    if (command_packet_length) {
        process_command(packet[0], &packet[1], command_packet_length - 1, &strip);
    }
  }
}

