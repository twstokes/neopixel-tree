#include <Arduino.h>
#include <Adafruit_NeoPixel.h>

void fill_and_show(uint32_t c, Adafruit_NeoPixel *strip);
void theaterChaseRainbow(uint8_t wait, Adafruit_NeoPixel *strip);
void theaterChase(uint32_t c, uint8_t wait, Adafruit_NeoPixel *strip);
void colorWipe(uint32_t c, uint8_t wait, Adafruit_NeoPixel *strip);
void rainbow(uint8_t wait, Adafruit_NeoPixel *strip);
void rainbowCycle(uint8_t wait, Adafruit_NeoPixel *strip);

