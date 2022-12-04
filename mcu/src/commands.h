#include <Arduino.h>
#include <Adafruit_NeoPixel.h>
#include "sequences.h"

enum command {
  OFF,
  BRIGHTNESS,
  PIXEL_COLOR,
  FILL_COLOR,
  RAINBOW,
  RAINBOW_CYCLE
};

void process_command(uint8_t c, uint8_t *data, uint8_t len, Adafruit_NeoPixel *strip);
void brightness(uint8_t b, Adafruit_NeoPixel *strip);
void pixel_color(uint8_t *data, Adafruit_NeoPixel *strip);
void fill_color(uint8_t *data, Adafruit_NeoPixel *strip);
