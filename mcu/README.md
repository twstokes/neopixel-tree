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
- Copy `secrets.ini.sample` to `secrets.ini` and fill in the appropriate values.

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

- Parameters are required unless noted as optional.
- Each parameter is a byte unless otherwise noted.
- For values that are larger than 1 byte, we use big-endian.
- Parameter table rows correspond to data byte indices (row 0 is byte 0).

## Past issues

When using an ESP8266 we'd often experience random crashes due to watchdog timer resets. This was likely due to a single core + bit banging all the pixels in a tight loop + trying to run WiFi at the same time. The simple solution was to upgrade to an ESP32 with dual cores.

This is why the "Reset Info" command was introduced, where we got:

```
Fatal exception:4 flag:1 (Hardware Watchdog) epc1:0x40103341 epc2:0x00000000 epc3:0x00000000 excvaddr:0x00000000 depc:0x00000000
```

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

### Reset Info

A special command used by clients to get information on why the MCU reset.

**Returns:** `[uint8_t]` [ESP32 reset reason](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/system/misc_system_api.html#_CPPv418esp_reset_reason_t)

| Command |
| - |
| `253` |

This command takes no parameters. The data received shouldn't be larger than `UDP_BUFFER_SIZE`.

---

### Uptime

A special command used by clients to get the number of milliseconds since the MCU started.

**Returns:** `[uint8_t]` Number of milliseconds since the MCU started

| Command |
| - |
| `254` |

This command takes no parameters. The data received shouldn't be larger than `UDP_BUFFER_SIZE`.

---

### Readback

A special command used by clients to get the currently running sequence on the tree.

**Returns:** `[uint8_t]` Raw packet stored in the MCU

| Command |
| - |
| `255` |

This command takes no parameters. The data received shouldn't be larger than `UDP_BUFFER_SIZE`. It's the responsibility of the client to know which bytes returned are valid for the command.
