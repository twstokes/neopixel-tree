# ESPHome firmware

This folder contains an ESPHome rewrite of the tree firmware so it can pair directly with Home Assistant. The light entity exposes brightness, color, and a set of effects that mirror the original UDP commands (rainbow, rainbow cycle, theater chase) plus a few extra seasonal twinkles.

## Setup

1. Install the ESPHome add-on in Home Assistant or the [ESPHome CLI](https://esphome.io/guides/getting_started_command_line.html).
2. Copy `esphome/secrets.yaml.sample` to `esphome/secrets.yaml` and fill in your Wi-Fi credentials, static IP (or remove the `manual_ip` block in `tree.yaml` to use DHCP), and new API/OTA keys (`esphome random` can generate these).
3. Adjust `substitutions` in `esphome/tree.yaml` if your pin or LED count differs (defaults: 106 LEDs on GPIO18).

## Flashing

- **First flash (USB):** `esphome run esphome/tree.yaml --device /dev/ttyUSB0`
- **OTA updates:** After the first flash, run `esphome run esphome/tree.yaml` to push updates over Wi-Fi.

The device will expose a fallback AP named `NeoPixel Tree Fallback` if it cannot join Wi-Fi; connect to it to supply credentials.

## Home Assistant controls

You will get a single light entity named `NeoPixel Tree`. Use the standard brightness and color controls, and pick routines from the effect list:
- Rainbow Flow
- Rainbow Cycle
- Theater Chase
- Candy Cane
- Firefly Sparkle
- Random Sparkle

Additional telemetry entities are provided for Wi-Fi RSSI, uptime, IP address, and firmware version, plus a restart button.
