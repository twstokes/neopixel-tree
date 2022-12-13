import socket
from config import UDP_IP, UDP_PORT
import commands

command = [commands.brightness]
level = [75]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(bytes(command + level), (UDP_IP, UDP_PORT))

