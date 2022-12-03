#include "commands.h"

void process_command(uint8_t c, uint8_t *data, Adafruit_NeoPixel *strip) {
    switch (c) {
        case OFF:
            strip->fill(strip->Color(255, 0, 0));
            break;
        case BRIGHTNESS:
            strip->fill(strip->Color(0, 255, 0));
            break;
        case SET_COLOR:
            strip->fill(strip->Color(0, 0, 255));
            break;
    }
}

