#include <Arduino.h>
#include <Adafruit_NeoPixel.h>

void fill_and_show(uint32_t c, Adafruit_NeoPixel *strip);
void fill_pattern(uint32_t *c, uint8_t len, Adafruit_NeoPixel *strip);
void theater_chase(uint32_t c, uint8_t wait, Adafruit_NeoPixel *strip);
void theater_chase_rainbow(uint8_t wait, Adafruit_NeoPixel *strip);
void color_wipe(uint32_t c, uint8_t wait, Adafruit_NeoPixel *strip);
void rainbow(uint8_t wait, Adafruit_NeoPixel *strip);
void rainbow_cycle(uint8_t wait, Adafruit_NeoPixel *strip);

