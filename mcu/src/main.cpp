#include <Adafruit_NeoPixel.h>
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
uint8_t raw_packet[UDP_BUFFER_SIZE];

Packet latest_packet = {0, NULL, 0, false};

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

void process_packet(Packet *packet) {
  bool repeat =
      process_command(packet->command, packet->data, packet->data_len, &strip);
  packet->repeat = repeat;
}

// return true if a packet arrived during the delay call
bool delay_with_udp(unsigned long ms) {
  unsigned long start = millis();

  while (millis() - start < ms) {
    if (Udp.parsePacket())
      return true;
    yield();
    ArduinoOTA.handle();
  }

  return false;
}

// special command to send back to the client
// the last packet received, i.e. the running command
void send_readback_packet() {
  Udp.beginPacket(Udp.remoteIP(), Udp.remotePort());
  Udp.write(raw_packet, UDP_BUFFER_SIZE);
  Udp.endPacket();
  Udp.flush();
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
      send_readback_packet();
      delay_with_udp(10);
    } else {
      uint16_t command_packet_length = Udp.read(raw_packet, UDP_BUFFER_SIZE);
      if (command_packet_length) {
        cmd_packet_from_raw_packet(&latest_packet, raw_packet,
                                   command_packet_length - 1);
        process_packet(&latest_packet);
      }
    }
  } else if (latest_packet.repeat) {
    process_packet(&latest_packet);
  } else {
    delay_with_udp(10);
  }
}
