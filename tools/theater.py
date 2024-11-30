import socket
from config import UDP_IP, UDP_PORT
import commands

command = [commands.theater_chase]
data = [0, 0, 255, 0]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(bytes(command + data), (UDP_IP, UDP_PORT))
