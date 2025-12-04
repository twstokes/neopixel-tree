import socket
from config import UDP_IP, UDP_PORT
import commands

# A good stress test. This is known to crash an ESP8266 due to a single core, writing to (bit banging) all the LEDs in a short amount of time, and WiFi. This may also crash single-core ESP32s.

command = [commands.rainbow]
repeat = [1]
# in milliseconds
delay = 1

delay_high = (delay >> 8) & 0xFF
delay_low = delay & 0xFF
delay_bytes = [delay_high, delay_low]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(bytes(command + repeat + delay_bytes), (UDP_IP, UDP_PORT))

