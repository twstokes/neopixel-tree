import socket
from struct import pack
from config import UDP_IP, UDP_PORT, PIXEL_COUNT
import commands

command = [commands.fill_pattern]

colors = []
for x in range(PIXEL_COUNT):
  colors += [x, 255, x]

print(len(colors))

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(bytes(command) + pack(">H", int(len(colors) / 3)) + bytes(colors), (UDP_IP, UDP_PORT))
# this command should have no effect as the second byte doesn't equal len(colors) * 3
#sock.sendto(bytes(command + [100] + colors), (UDP_IP, UDP_PORT))
