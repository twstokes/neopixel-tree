import socket
import struct
from config import UDP_IP, UDP_PORT
import commands

command = [commands.reset_info]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(bytes(command), (UDP_IP, UDP_PORT))

## 512 matches UDP_BUFFER_SIZE
data, address = sock.recvfrom(512)
print(data.decode("utf-8"))
