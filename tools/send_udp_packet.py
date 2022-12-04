import socket

UDP_IP = ''
UDP_PORT = 8733

command = [2]

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.sendto(bytes(command), (UDP_IP, UDP_PORT))

