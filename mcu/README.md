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

```
| command | command data  |
| 1 byte  | 1 - 254 bytes |
```

### Uploading

`pio run -e [env name] -t upload`

## Command Protocol

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

---

### Off

Turns off the LEDs.

Parameters:
- None

----

### Brightness

Sets the brightness of the LEDs.

| Parameter | Value |
| - | - |
| Level | `0 - 255` |

----

### Pixel Color

Sets the color of a single pixel.

| Parameter | Value |
| - | - |
| Offset | `0 - (PIXEL_COUNT-1)` |
| Red | `0 - 255` |
| Green | `0 - 255` |
| Blue | `0 - 255` |

---

### Fill Color

Fills all LEDs with a single color.

| Parameter | Value |
| - | - |
| Red | `0 - 255` |
| Green | `0 - 255` |
| Blue | `0 - 255` |

---

### Pattern Fill

Fills the tree by repeating the colors provided.

| Parameter | Value |
| - | - |
| Number of colors provided | `0 - 255` |
| Red | `0 - 255` |
| Green | `0 - 255` |
| Blue | `0 - 255` |

Red, green, and blue parameters can be repeated up to `PIXEL_COUNT` times.

---

### Rainbow

Animates the tree with a colorful rainbow effect. Repeatable.

| Parameter | Value |
| - | - |
| Repeat | `0 - 1` |

---

### Rainbow Cycle

Like Rainbow, but colors are equally distributed. Repeatable.

| Parameter | Value |
| - | - |
| Repeat | `0 - 1` |

---

### Theater Chase

Shows theater-style crawling lights with provided color. Repeatable.

| Parameter | Value |
| - | - |
| Repeat | `0 - 1` |
| Red | `0 - 255` |
| Green | `0 - 255` |
| Blue | `0 - 255` |

---

### Readback

A special command used by clients to get the currently running sequence on the tree.

This command takes no parameters. The data received shouldn't be larger than `UDP_BUFFER_SIZE`.

**Important note:** Currently it's the responsibility of the reciever to know what bytes are valid, depending on the command. For instance:

1. The Pattern Fill command is sent with 10 colors (at least 30 bytes)
2. The Rainbow command is sent.
3. The Readback command is sent.

Because the Readback command sends the raw packet buffer and doesn't factor in the total length of the Rainbow command, it'll contain the previous values from setup 1. The client should know (based on byte 0) that the tree is running the Rainbow command and to only read the valid bytes.

If the Pattern Fill command is being read, pay attention to the byte with the number of colors to know how many subsequent bytes to expect.
