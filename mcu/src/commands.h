#include <Arduino.h>
#include <Adafruit_NeoPixel.h>
#include "sequences.h"

enum command {
  OFF,
  BRIGHTNESS,
  PIXEL_COLOR,
  FILL_COLOR,
  FILL_PATTERN,
  RAINBOW,
  RAINBOW_CYCLE
};

struct Packet {
    uint8_t command;
    uint8_t* data;
    uint16_t data_len;
};

bool process_command(uint8_t c, uint8_t *data, uint16_t len, Adafruit_NeoPixel *strip);
void cmd_packet_from_raw_packet(Packet *cmd_packet, uint8_t *raw_packet, uint16_t data_len);
void brightness_cmd(uint8_t b, Adafruit_NeoPixel *strip);
void pixel_color_cmd(uint8_t *data, Adafruit_NeoPixel *strip);
void fill_color_cmd(uint8_t *data, Adafruit_NeoPixel *strip);
void fill_pattern_cmd(uint8_t *data, uint16_t len, Adafruit_NeoPixel *strip);

