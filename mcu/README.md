## Important notes

⚠️ The tree should not be powered by the USB connection alone.

**Local serial connection sequence:**
1. Power the tree with 5V external power
2. Connect to the MCU via USB

## Development setup

- Install [PlatformIO](https://platformio.org/)
- Install [clang-format](https://clang.llvm.org/docs/ClangFormat.html)
- Copy `src/wifi_config.h.sample` to `src/wifi_config.h` and fill in the appropriate values.
- Copy `src/ota_config.h.sample` to `src/ota_config.h` and fill in the appropriate values.

## Build environments

- `local` - for connecting locally via serial
- `ota` - for Over The Air uploads
  - Currently needs `upload_port` and `upload_flags` to be set in `platformio.ini`

### Building

`pio run -e [env name]`

### Uploading

`pio run -e [env name] -t upload`

## Command protocol

Commands are received on the MCU via UDP packets. Each packet starts with a 1-byte identifier followed by zero or more bytes specific to that command.

`UDP_BUFFER_SIZE` is the max buffer size to read from a UDP packet. It should be large enough to support the largest command, i.e. a command to uniquely set all pixels to a color would need (PIXEL_COUNT * 3) + 1 bytes. 1 byte for the command, and three 8-bit channels for each pixel.

| command | minimum data | maximum data |
| - | - | - |
| 1 byte  | 0 bytes | (`UDP_BUFFER_SIZE` - 1) bytes |

## Command list

- Each parameter is required.
- Each parameter is a byte unless otherwise noted.
- For values that are larger than 1 byte, we use big-endian.
- Parameter table rows correspond to data byte indices (row 0 is byte 0).

## Known issues

Repeatedly driving the LEDs quickly can lead to MCU restarts. After researching the issue, this is likely due to the NeoPixel library "bit banging" the LEDs and disabling interrupts which the ESP8266 needs for the WiFi stack and other system functionality. Most likely the watchdog timer causes a restart in these instances. Setting a higher delay in looping routines can increase stability.

---

### Off

Turns off the LEDs.

| Command |
| - |
| `0` |

----

### Brightness

Sets the brightness of the LEDs.

| Command | Level |
| - | - |
| `1` | `0 - 255` |

----

### Pixel Color

Sets the color of a single pixel.

| Command | Offset | Red | Green | Blue |
| - | - | - | - | - |
| `2` |  `0 - (PIXEL_COUNT-1)` | `0 - 255` | `0 - 255` | `0 - 255` |

---

### Fill Color

Fills all LEDs with a single color.

| Command | Red | Green | Blue |
| - | - | - | - |
| `3` | `0 - 255` | `0 - 255` | `0 - 255` |

---

### Pattern Fill

Fills the tree by repeating the colors provided.

| Command | Number of colors provided | Red | Green | Blue |
| - | - | - | - | - |
| `4` | `0 - 255` | `0 - 255` | `0 - 255` | `0 - 255` |

Red, green, and blue parameters can be repeated up to `PIXEL_COUNT` times.

---

### Rainbow

Animates the tree with a colorful rainbow effect. Repeatable. Optionally, a delay can be provided.

| Command | Repeat | _Delay High_ | _Delay Low_ |
| - | - | - | - |
| `5` | `0 - 1` | `0 - 255` | `0 - 255` |

Delay defaults to 20 ms. Range is 16-bit, two supplied bytes are big endian. Unit is milliseconds.

---

### Rainbow Cycle

Like Rainbow, but colors are equally distributed. Repeatable.

| Command | Repeat |
| - | - |
| `6` | `0 - 1` |

---

### Theater Chase

Shows theater-style crawling lights with provided color. Repeatable.

| Command | Repeat | Red | Green | Blue |
| - | - | - | - | - |
| `7` | `0 - 1` | `0 - 255` | `0 - 255` | `0 - 255` |

---

### Readback

A special command used by clients to get the currently running sequence on the tree.

| Command |
| - |
| `255` |

This command takes no parameters. The data received shouldn't be larger than `UDP_BUFFER_SIZE`.

**Important note:** Currently it's the responsibility of the reciever to know what bytes are valid, depending on the command. For instance:

1. The Pattern Fill command is sent with 10 colors (at least 30 bytes)
2. The Rainbow command is sent.
3. The Readback command is sent.

Because the Readback command sends the raw packet buffer and doesn't factor in the total length of the Rainbow command, it'll contain the previous values from step 1. The client should know (based on byte 0) that the tree is running the Rainbow command and to only read the valid bytes.

If the Pattern Fill command is being read, pay attention to the byte with the number of colors to know how many subsequent bytes to expect.
