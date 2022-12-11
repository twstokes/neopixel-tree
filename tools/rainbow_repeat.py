import socket
from config import UDP_IP, UDP_PORT
import commands

command = [commands.rainbow]
repeat = [1]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(bytes(command + repeat), (UDP_IP, UDP_PORT))

