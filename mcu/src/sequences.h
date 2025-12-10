#include <Adafruit_NeoPixel.h>

void fill_and_show(uint32_t c, Adafruit_NeoPixel *strip);
void fill_pattern(uint32_t *c, uint16_t len, Adafruit_NeoPixel *strip);
void fill_percent(uint32_t c, float p, Adafruit_NeoPixel *strip);
void theater_chase(uint32_t c, uint8_t wait, Adafruit_NeoPixel *strip);
void theater_chase_rainbow(uint8_t wait, Adafruit_NeoPixel *strip);
void color_wipe(uint32_t c, uint8_t wait, Adafruit_NeoPixel *strip);
void rainbow(uint8_t wait, Adafruit_NeoPixel *strip);
void rainbow_cycle(uint8_t wait, Adafruit_NeoPixel *strip);
bool run_for_duration(unsigned long duration_ms, uint16_t wait_ms);
bool rainbow_cycle_for(uint8_t wait, unsigned long duration_ms,
                       Adafruit_NeoPixel *strip);
