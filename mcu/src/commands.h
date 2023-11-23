#include "sequences.h"
#include <Adafruit_NeoPixel.h>
#include <Arduino.h>

enum command {
  OFF = 0,
  BRIGHTNESS = 1,
  PIXEL_COLOR = 2,
  FILL_COLOR = 3,
  FILL_PATTERN = 4,
  RAINBOW = 5,
  RAINBOW_CYCLE = 6,
  THEATER_CHASE = 7,
  READBACK = 255
};

struct Packet {
  uint8_t command;
  uint8_t *data;
  uint16_t data_len;
};

bool process_command(uint8_t c, uint8_t *data, uint16_t len,
                     Adafruit_NeoPixel *strip);
void cmd_packet_from_raw_packet(Packet *cmd_packet, uint8_t *raw_packet,
                                uint16_t data_len);
void brightness_cmd(uint8_t b, Adafruit_NeoPixel *strip);
void pixel_color_cmd(uint8_t *data, Adafruit_NeoPixel *strip);
void fill_color_cmd(uint8_t *data, Adafruit_NeoPixel *strip);
void fill_pattern_cmd(uint8_t *data, uint16_t len, Adafruit_NeoPixel *strip);
bool theater_chase_cmd(uint8_t *data, Adafruit_NeoPixel *strip);
