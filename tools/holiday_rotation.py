import argparse
import socket

from config import UDP_IP, UDP_PORT
import commands


def main():
  parser = argparse.ArgumentParser(
      description="Run the holiday rotation sequence once or on repeat")
  parser.add_argument(
      "--repeat",
      action="store_true",
      help="loop the rotation until another command is sent",
  )
  args = parser.parse_args()

  payload = bytes([commands.holiday_rotation, int(args.repeat)])
  sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
  sock.sendto(payload, (UDP_IP, UDP_PORT))


if __name__ == "__main__":
  main()
