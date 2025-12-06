import socket
from config import UDP_IP, UDP_PORT
import commands
import random
import time

command = [commands.pixel_color]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

while True:
    offset = random.randrange(106)
    color = [random.randrange(255), random.randrange(255), random.randrange(255)]
    payload = command + [offset] + color
    sock.sendto(bytes(payload), (UDP_IP, UDP_PORT))
    #time.sleep(0.1)
