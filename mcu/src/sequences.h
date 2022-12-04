#include <Arduino.h>
#include <Adafruit_NeoPixel.h>

void fill_and_show(Adafruit_NeoPixel *strip, uint32_t c);
void theaterChaseRainbow(Adafruit_NeoPixel *strip, uint8_t wait);
void theaterChase(Adafruit_NeoPixel *strip, uint32_t c, uint8_t wait);
void colorWipe(Adafruit_NeoPixel *strip, uint32_t c, uint8_t wait);
void rainbow(Adafruit_NeoPixel *strip, uint8_t wait);
void rainbowCycle(Adafruit_NeoPixel *strip, uint8_t wait);

