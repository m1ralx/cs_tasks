import socket
import time
import struct

fractial = lambda x: x - int(x)
stratum = b'\x05'


def get_timestamp(diff, time):
    timestamp = struct.pack('!I', int(time) + diff)
    timestamp += struct.pack('!I', int(fractial(time) * (1 << 32)))
    return timestamp


def make_dump(data, diff):
    start_time = time.time()
    li_vn_mode = int(data[0]) & 0b11111000 | 0b00000100
    dump = bytes([li_vn_mode])
    dump += stratum
    dump += data[2:24]
    dump += data[40:48]
    dump += get_timestamp(diff, start_time)
    dump += get_timestamp(diff, time.time())
    return dump
    

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(('', 123))
diff = int(input("Enter required difference (it can be negative): "))

while True:
    data, addr = sock.recvfrom(1024)
    print("I get {} ".format(data))
    answer = make_dump(data, diff)
    sock.sendto(answer, addr)
    print('{} was sent to {}'.format(answer, addr))





