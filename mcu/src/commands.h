#include <Arduino.h>
#include <Adafruit_NeoPixel.h>

enum command {
  OFF,
  BRIGHTNESS,
  SET_COLOR
};

void process_command(uint8_t c, uint8_t *data, Adafruit_NeoPixel *strip);

