import socket
from config import UDP_IP, UDP_PORT
import commands

command = [commands.off]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(bytes(command), (UDP_IP, UDP_PORT))

