### Setup

Copy `src/wifi_config.h.sample` to `src/wifi_config.h` and fill in the appropriate values.

### Command Protocol

| command | command data  |
| 1 byte  | 1 - 254 bytes |

### Sequences

#### Off

Enables / Disables the LEDs based on boolean value.

| on / off |
| 1 byte   |

#### Set Color

Sets color(s) of LEDs starting at offset O repeating N colors.

| offset (valid value is 0 to number of LEDS - 1) | pattern to repeat - up to (Number of LEDS - offset) |
| 1 byte                                          | 1 - 253 bytes | 


#### Set Brightness

Sets brightness of tree. Valid values are 0-255.

| 0 - 255 |
| 1 byte  |

