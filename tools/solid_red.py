import socket
from config import UDP_IP, UDP_PORT
import commands

command = [commands.fill_color]
color = [255, 0, 0]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(bytes(command + color), (UDP_IP, UDP_PORT))

