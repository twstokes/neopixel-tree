import socket
import struct
from config import UDP_IP, UDP_PORT
import commands

command = [commands.readback]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(bytes(command), (UDP_IP, UDP_PORT))

# 512 matches UDP_BUFFER_SIZE
data, address = sock.recvfrom(512)
data_iter = struct.iter_unpack("B", data)

ints = list(data_iter)
print(len(ints))
# only print out the first ten
print(ints[:10])

