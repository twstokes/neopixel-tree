#include <Adafruit_NeoPixel.h>
#include <ArduinoOTA.h>
#include <ESPmDNS.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <cstring>
#include <esp_system.h>

#include "commands.h"
#include "ota_config.h"
#include "sequences.h"
#include "utils.h"
#include "wifi_config.h"

#define PIN 18
#define PIXEL_COUNT 106
Adafruit_NeoPixel strip =
    Adafruit_NeoPixel(PIXEL_COUNT, PIN, NEO_GRB + NEO_KHZ800);

#define UDP_PORT 8733
WiFiUDP Udp;

#define UDP_BUFFER_SIZE 512
uint8_t raw_packet[UDP_BUFFER_SIZE];

Packet latest_packet = {0, NULL, 0, false};

#define DEFAULT_DELAY_MS 5

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

  WiFi.mode(WIFI_STA);
  WiFi.config(ip, gateway, subnet);
  WiFi.begin(ssid, wifi_pass);
  WiFi.setSleep(false);

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

void restart_wifi() {
  WiFi.disconnect();

  while (WiFi.begin(ssid, wifi_pass) != WL_CONNECTED) {
    Serial.println("Connecting to WiFi...");
    delay(100);
  }
}

// starts OTA updates capability and uses the
// NeoPixel strip to show update progress
void start_ota() {
  ArduinoOTA.setPassword(ota_pass);
  ArduinoOTA.setMdnsEnabled(ota_useMDNS);

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
  ArduinoOTA.begin();
}

void start_udp() { Udp.begin(UDP_PORT); }

void process_packet(Packet *packet) {
  bool repeat =
      process_command(packet->command, packet->data, packet->data_len, &strip);
  packet->repeat = repeat;
}

// special command to send back to the client
// the last packet received, i.e. the running command
void send_readback_packet() {
  Udp.beginPacket(Udp.remoteIP(), Udp.remotePort());
  Udp.write(raw_packet, UDP_BUFFER_SIZE);
  Udp.endPacket();
  Udp.flush();
}

// responds with the last reset reason to the current UDP peer
void send_reset_info() {
  const char *reason = reset_reason_to_string(esp_reset_reason());
  size_t len = strlen(reason);

  Udp.beginPacket(Udp.remoteIP(), Udp.remotePort());
  // cap length to UDP_BUFFER_SIZE to avoid overruns
  if (len > UDP_BUFFER_SIZE)
    len = UDP_BUFFER_SIZE;
  Udp.write(reinterpret_cast<const uint8_t *>(reason), len);
  Udp.endPacket();
  Udp.flush();
}

// responds with uptime in milliseconds since boot
void send_uptime() {
  String uptime_ms = String(millis());
  size_t len = uptime_ms.length();

  Udp.beginPacket(Udp.remoteIP(), Udp.remotePort());
  if (len > UDP_BUFFER_SIZE)
    len = UDP_BUFFER_SIZE;
  Udp.write(reinterpret_cast<const uint8_t *>(uptime_ms.c_str()), len);
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
  if (WiFi.status() != WL_CONNECTED) {
    restart_wifi();
  }

  // available is supposed to be called after parsePacket, which is handled
  // in delay_with_udp
  if (Udp.available()) {
    uint8_t peeked_command = Udp.peek();
    if (peeked_command == READBACK) {
      send_readback_packet();
      delay_with_udp(DEFAULT_DELAY_MS);
    } else if (peeked_command == RESET_INFO) {
      send_reset_info();
      delay_with_udp(DEFAULT_DELAY_MS);
    } else if (peeked_command == UPTIME) {
      send_uptime();
      delay_with_udp(DEFAULT_DELAY_MS);
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
    delay_with_udp(DEFAULT_DELAY_MS);
  }
}
