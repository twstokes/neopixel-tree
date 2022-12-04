#include "commands.h"

/*
 * @param   c       Command
 * @param   data    Optional array of bytes to use for the command
 * @param   len     Length of data in bytes
 * @param   strip   Pointer to NeoPixel strip
*/
void process_command(uint8_t c, uint8_t *data, uint8_t len, Adafruit_NeoPixel *strip) {
    switch (c) {
        case OFF:
            strip->clear();
            break;
        case BRIGHTNESS:
            if (len != 1) return;
            brightness(data[0], strip);
            break;
        case PIXEL_COLOR:
            if (len != 2) return;
            pixel_color(data, strip);
            break;
        case FILL_COLOR:
            if (len != 3) return;
            fill_color(data, strip);
            break;
        case RAINBOW:
            rainbow(strip, 20);
            break;
        case RAINBOW_CYCLE:
            rainbowCycle(strip, 20);
            break;
    }
}

void brightness(uint8_t b, Adafruit_NeoPixel *strip) {
    strip->setBrightness(b);
}

// sets the pixel color at the address location
// uses gamma correction
void pixel_color(uint8_t *data, Adafruit_NeoPixel *strip) {
    uint8_t address = data[0];
    uint32_t c = strip->Color(data[1], data[2], data[3]);
    strip->setPixelColor(address, strip->gamma32(c));
    strip->show();
}

// fills the strip with the color provided by first three bytes of data
// uses gamma correction
void fill_color(uint8_t *data, Adafruit_NeoPixel *strip) {
    uint32_t c = strip->Color(data[0], data[1], data[2]);
    fill_and_show(strip, strip->gamma32(c));
}
