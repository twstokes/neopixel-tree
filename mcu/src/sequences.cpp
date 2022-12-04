#include "sequences.h"

/* 
 * Many of these sequences are from examples
 * included in the Adafruit NeoPixels library.
 *
 * https://github.com/adafruit/Adafruit_NeoPixel
*/

// fill the strip with the provided color and show immediately
void fill_and_show(uint32_t c, Adafruit_NeoPixel *strip) {
    strip->fill(c);
    strip->show();
}

// input a value 0 to 255 to get a color value
// the colors are a transition r - g - b - back to r
uint32_t wheel(byte wheel_pos, Adafruit_NeoPixel *strip) {
  wheel_pos = 255 - wheel_pos;
  if(wheel_pos < 85) {
    return strip->Color(255 - wheel_pos * 3, 0, wheel_pos * 3);
  }
  if(wheel_pos < 170) {
    wheel_pos -= 85;
    return strip->Color(0, wheel_pos * 3, 255 - wheel_pos * 3);
  }
  wheel_pos -= 170;
  return strip->Color(wheel_pos * 3, 255 - wheel_pos * 3, 0);
}

// fill the LEDs one after the other with a color
void color_wipe(uint32_t c, uint8_t wait, Adafruit_NeoPixel *strip) {
  for(uint16_t i=0; i<strip->numPixels(); i++) {
    strip->setPixelColor(i, c);
    strip->show();
    delay(wait);
  }
}

void rainbow(uint8_t wait, Adafruit_NeoPixel *strip) {
  uint16_t i, j;

  for(j=0; j<256; j++) {
    for(i=0; i<strip->numPixels(); i++) {
      strip->setPixelColor(i, wheel((i+j) & 255, strip));
    }
    strip->show();
    delay(wait);
  }
}

// make rainbow equally distributed throughout
void rainbow_cycle(uint8_t wait, Adafruit_NeoPixel *strip) {
  uint16_t i, j;

  for(j=0; j<256*5; j++) { // 5 cycles of all colors on wheel
    for(i=0; i< strip->numPixels(); i++) {
      strip->setPixelColor(i, wheel(((i * 256 / strip->numPixels()) + j) & 255, strip));
    }
    strip->show();
    delay(wait);
  }
}

// theater-style crawling lights
void theater_chase(uint32_t c, uint8_t wait, Adafruit_NeoPixel *strip) {
  for (int j=0; j<10; j++) {  //do 10 cycles of chasing
    for (int q=0; q < 3; q++) {
      for (uint16_t i=0; i < strip->numPixels(); i=i+3) {
        strip->setPixelColor(i+q, c);    //turn every third pixel on
      }
      strip->show();

      delay(wait);

      for (uint16_t i=0; i < strip->numPixels(); i=i+3) {
        strip->setPixelColor(i+q, 0);        //turn every third pixel off
      }
    }
  }
}

// theater-style crawling lights with rainbow effect
void theater_chase_rainbow(uint8_t wait, Adafruit_NeoPixel *strip) {
  for (int j=0; j < 256; j++) {     // cycle all 256 colors in the wheel
    for (int q=0; q < 3; q++) {
      for (uint16_t i=0; i < strip->numPixels(); i=i+3) {
        strip->setPixelColor(i+q, wheel((i+j) % 255, strip));    //turn every third pixel on
      }
      strip->show();

      delay(wait);

      for (uint16_t i=0; i < strip->numPixels(); i=i+3) {
        strip->setPixelColor(i+q, 0);        //turn every third pixel off
      }
    }
  }
}

