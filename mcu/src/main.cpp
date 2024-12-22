#include <Adafruit_NeoPixel.h>
#include <Arduino.h>
#include <ArduinoOTA.h>
#include <ESP8266WiFi.h>
#include <WiFiUdp.h>

#include "commands.h"
#include "ota_config.h"
#include "sequences.h"
#include "utils.h"
#include "wifi_config.h"

#define PIN D1
#define PIXEL_COUNT 106
Adafruit_NeoPixel strip =
    Adafruit_NeoPixel(PIXEL_COUNT, PIN, NEO_GRB + NEO_KHZ800);

#define UDP_PORT 8733
WiFiUDP Udp;

#define UDP_BUFFER_SIZE 512
uint8_t packet[UDP_BUFFER_SIZE];

Packet latest_packet;
// if true, the last received packet will be repeated
bool repeat_packet = false;

// initialize the strip and turn off all LEDs
void start_strip() {
  strip.begin();
  strip.show();
}

// start WiFi with visual feedback
void start_wifi() {
  uint32_t green = strip.gamma32(strip.Color(0, 255, 0));
  uint32_t orange = strip.gamma32(strip.Color(255, 87, 51));
  uint32_t black = strip.Color(0, 0, 0);

  // set the strip to orange before establishing a WiFi connection
  fill_and_show(orange, &strip);

  WiFi.config(ip, gateway, subnet);
  WiFi.begin(ssid, wifi_pass);

  while (WiFi.status() != WL_CONNECTED) {
    // show that we're trying to establish a connection
    fill_and_show(orange, &strip);
    delay(1000);
    fill_and_show(black, &strip);
    delay(1000);
  }

  // set the strip to green on success
  fill_and_show(green, &strip);
  delay(1000);
}

// starts OTA updates capability and uses the
// NeoPixel strip to show update progress
void start_ota() {
  ArduinoOTA.setPassword(ota_pass);

  ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {
    if (total == 0)
      return;
    // fills the pixel strip based on OTA progress
    float perc = (float)progress / (float)total;
    uint32_t blue = strip.Color(0, 0, 255);
    fill_percent(blue, perc, &strip);
  });

  ArduinoOTA.onStart([]() {
    // stop whatever sequence is currently running
    // so upload progress is shown
    strip.clear();
    strip.show();
  });

  ArduinoOTA.onEnd([]() {});
  ArduinoOTA.onError([](ota_error_t error) {});
  ArduinoOTA.begin(ota_useMDNS);
}

void start_udp() { Udp.begin(UDP_PORT); }

bool process_packet(Packet *packet) {
  return process_command(packet->command, packet->data, packet->data_len,
                         &strip);
}

// return true if a packet arrived during the delay call
// should only be used after Udp and ArduinoOTA have been initialized
bool delay_with_udp(unsigned long ms) {
  unsigned long future = millis() + ms;

  while (millis() < future) {
    if (Udp.parsePacket())
      return true;
    yield();
    ArduinoOTA.handle();
  }

  return false;
}

void setup() {
  start_strip();
  start_wifi();
  start_udp();
  start_ota();
}

void loop() {
  // available is supposed to be called after parsePacket, which is handled
  // in delay_with_udp
  if (Udp.available()) {
    if (Udp.peek() == READBACK) {
      // special command to send back to the client
      // the last packet received, i.e. the running command
      Udp.beginPacket(Udp.remoteIP(), Udp.remotePort());
      Udp.write(packet, UDP_BUFFER_SIZE);
      Udp.endPacket();
      Udp.flush();
      // required
      delay_with_udp(10);
    } else {
      uint16_t command_packet_length = Udp.read(packet, UDP_BUFFER_SIZE);
      if (command_packet_length) {
        cmd_packet_from_raw_packet(&latest_packet, packet,
                                   command_packet_length - 1);
        repeat_packet = process_packet(&latest_packet);
      }
    }
  } else if (repeat_packet) {
    process_packet(&latest_packet);
  } else {
    delay_with_udp(10);
  }
}
