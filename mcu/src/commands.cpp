#include "commands.h"

/*
 * @param   c       Command
 * @param   data    Optional array of bytes to use for the command
 * @param   len     Length of data in bytes
 * @param   strip   Pointer to NeoPixel strip
 *
 * Returns bool if the command should be repeated
 */
bool process_command(uint8_t c, uint8_t *data, uint16_t len,
                     Adafruit_NeoPixel *strip) {
  switch (c) {
  case OFF:
    strip->clear();
    strip->show();
    break;
  case BRIGHTNESS:
    if (len != 1)
      break;
    brightness_cmd(data[0], strip);
    break;
  case PIXEL_COLOR:
    if (len != 4)
      break;
    pixel_color_cmd(data, strip);
    break;
  case FILL_COLOR:
    if (len != 3)
      break;
    fill_color_cmd(data, strip);
    break;
  case FILL_PATTERN:
    if (len < 4)
      break;
    fill_pattern_cmd(data, len, strip);
    break;
  case RAINBOW:
    if (len == 1) {
      // only repeat byte was passed
      rainbow(20, strip);
    } else if (len == 3) {
      // two delay bytes were passed
      uint16_t delay = process_delay(data[1], data[2]);
      rainbow(delay, strip);
    } else {
      break;
    }
    return data[0];
  case RAINBOW_CYCLE:
    if (len != 1)
      break;
    rainbow_cycle(20, strip);
    return data[0];
  case THEATER_CHASE:
    if (len != 4)
      break;
    return theater_chase_cmd(data, strip);
  }

  return false;
}

void cmd_packet_from_raw_packet(Packet *cmd_packet, uint8_t *raw_packet,
                                uint16_t data_len) {
  cmd_packet->command = raw_packet[0];
  cmd_packet->data = data_len > 0 ? &raw_packet[1] : NULL;
  cmd_packet->data_len = data_len;
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
void unpack_colors_from_data(uint8_t *data, uint8_t num_colors,
                             uint32_t *colors) {
  uint8_t *chan_ptr = data;
  for (int i = 0; i < num_colors; i++) {
    colors[i] =
        Adafruit_NeoPixel::Color(*chan_ptr, *(chan_ptr + 1), *(chan_ptr + 2));
    chan_ptr += 3;
  }
}

// fills the strip by repeating the provided color(s)
// uses gamma correction
void fill_pattern_cmd(uint8_t *data, uint16_t len, Adafruit_NeoPixel *strip) {
  // the first byte is the number of colors provided
  // note: not the total number of bytes, which is this number * 3
  const uint8_t num_colors = data[0];
  // the remaining number of bytes in data must
  // be equal to num_colors * 3
  if (len - 1 != num_colors * 3)
    return;
  // number of provided colors can't exceed number of pixels
  if (num_colors > strip->numPixels())
    return;
  // stores all the colors provided
  uint32_t c[num_colors * 3];
  unpack_colors_from_data(&data[1], num_colors, c);
  fill_pattern(c, num_colors, strip);
}

bool theater_chase_cmd(uint8_t *data, Adafruit_NeoPixel *strip) {
  uint8_t repeat = data[0];
  uint32_t c = strip->Color(data[1], data[2], data[3]);
  theater_chase(c, 20, strip);
  return repeat;
}

// uses big endian ordering to create a 16-bit value for delay
uint16_t process_delay(uint8_t high, uint8_t low) {
  return ((uint16_t)high << 8) | (uint16_t)low;
}

