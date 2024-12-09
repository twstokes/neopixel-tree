import socket
from config import UDP_IP, UDP_PORT
import commands

command = [commands.rainbow]
repeat = [1]
# in milliseconds
delay = 6000

delay_high = (delay >> 8) & 0xFF
delay_low = delay & 0xFF
delay_bytes = [delay_high, delay_low]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(bytes(command + repeat + delay_bytes), (UDP_IP, UDP_PORT))

