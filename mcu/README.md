### Important notes

Local serial connection sequence:
1. Power the tree with 5V external power
2. Connect to the MCU via USB

### Setup

- Copy `src/wifi_config.h.sample` to `src/wifi_config.h` and fill in the appropriate values.
- Copy `src/ota_config.h.sample` to `src/ota_config.h` and fill in the appropriate values.

### Command Protocol

Commands are received via UDP packets. Each packet starts with a 1-byte identifier followed by data specific to that command.

`UDP_BUFFER_SIZE` is the max buffer size to read from a UDP packet. It should be large enough to support
the largest command, e.g. a command to uniquely set all pixels to a color would need (PIXEL_COUNT * 3) + 1 bytes
since a command is 1 byte and each pixel has three 8-bit channels.

```
| command | command data  |
| 1 byte  | 1 - 254 bytes |
```

