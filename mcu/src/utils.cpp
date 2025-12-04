#include <Arduino.h>
#include <ArduinoOTA.h>
#include <WiFiUdp.h>
#include <esp_system.h>

#include "utils.h"

extern WiFiUDP Udp;

const char *reset_reason_to_string(esp_reset_reason_t reason) {
  switch (reason) {
  case ESP_RST_UNKNOWN:
    return "ESP_RST_UNKNOWN";
  case ESP_RST_POWERON:
    return "ESP_RST_POWERON";
  case ESP_RST_EXT:
    return "ESP_RST_EXT";
  case ESP_RST_SW:
    return "ESP_RST_SW";
  case ESP_RST_PANIC:
    return "ESP_RST_PANIC";
  case ESP_RST_INT_WDT:
    return "ESP_RST_INT_WDT";
  case ESP_RST_TASK_WDT:
    return "ESP_RST_TASK_WDT";
  case ESP_RST_WDT:
    return "ESP_RST_WDT";
  case ESP_RST_DEEPSLEEP:
    return "ESP_RST_DEEPSLEEP";
  case ESP_RST_BROWNOUT:
    return "ESP_RST_BROWNOUT";
  case ESP_RST_SDIO:
    return "ESP_RST_SDIO";
  default:
    return "ESP_RST_UNKNOWN";
  }
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
