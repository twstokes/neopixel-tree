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
            strip->show();
            break;
        case BRIGHTNESS:
            if (len != 1) return;
            brightness_cmd(data[0], strip);
            break;
        case PIXEL_COLOR:
            if (len != 4) return;
            pixel_color_cmd(data, strip);
            break;
        case FILL_COLOR:
            if (len != 3) return;
            fill_color_cmd(data, strip);
            break;
        case FILL_PATTERN:
            if (len < 4) return;
            fill_pattern_cmd(data, strip);
            break;
        case RAINBOW:
            rainbow(20, strip);
            break;
        case RAINBOW_CYCLE:
            rainbow_cycle(20, strip);
            break;
    }
}

void brightness_cmd(uint8_t b, Adafruit_NeoPixel *strip) {
    strip->setBrightness(b);
}

// sets the pixel color at the pixel offset
// uses gamma correction
void pixel_color_cmd(uint8_t *data, Adafruit_NeoPixel *strip) {
    uint8_t offset = data[0];
    uint32_t c = strip->Color(data[1], data[2], data[3]);
    strip->setPixelColor(offset, strip->gamma32(c));
    strip->show();
}

// fills the strip with the color provided by first three bytes of data
// uses gamma correction
void fill_color_cmd(uint8_t *data, Adafruit_NeoPixel *strip) {
    uint32_t c = strip->Color(data[0], data[1], data[2]);
    fill_and_show(strip->gamma32(c), strip);
}

// converts an RGB byte array to an array of packed colors
void load_colors_from_data(uint8_t *data, uint8_t num_colors, uint32_t *colors) {
    uint8_t *chan_ptr = data;
    for (int i=0; i<num_colors; i++) {
        colors[i] = Adafruit_NeoPixel::Color(*chan_ptr, *(chan_ptr + 1), *(chan_ptr + 2));
        chan_ptr += 3;
    }
}

// fills the strip by repeating the provided color(s)
// uses gamma correction
void fill_pattern_cmd(uint8_t *data, Adafruit_NeoPixel *strip) {
    // rgb - 1 byte per channel
    const uint8_t num_channels = 3;
    // the first byte is the number of colors provided
    // note: not the total number of bytes
    const uint8_t num_colors = data[0];
    // numer of provided colors can't exceed number of pixels
    if (num_colors > strip->numPixels()) return;
    // stores all the colors provided
    uint32_t c[num_colors * num_channels];
    // pointer to first color channel
    uint8_t *chan_ptr = &data[1];
    for (int i=0; i<num_colors; i++) {
        uint32_t color = strip->Color(*chan_ptr, *(chan_ptr + 1), *(chan_ptr + 2));
        c[i] = strip->gamma32(color);
        chan_ptr += num_channels;
    }
    fill_pattern(c, num_colors, strip);
}

