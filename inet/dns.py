import socket
import struct
import sys
import time


stats4, stats6, limits = {}, {}, {}


def receive(sock):
    data = b''
    while True:
        try:    
            temp = sock.recv(1024)
            data += temp
        except socket.timeout:
            break
    return data 


def get_forwarder():
    if len(sys.argv) < 2:
        print("8.8.8.8 has been chosen the default forwarder")
        print("use dns.py [forwarder] to determine the certain forwarder") 
        return '8.8.8.8'
    else:
        return sys.argv[1]


def get_domain(query):
    return query[12: -4].decode()


def get_type(query):
    temp = query[-4: -2]
    return struct.unpack("!H", temp)[0]


def get_id(query):
    temp = query[:2]
    return struct.unpack("!H", temp)[0]


def get_header(data, qlength):
    if len(data) >= qlength:
        return data[:qlength]
    return False


def get_answers(data, qlength):
    temp = data[qlength:]
    if temp:
        return temp
    return False


def cut_answers(data, is_ipv4):
    length = 28 - 12 * int(is_ipv4)
    qtype = 28 - 27 * int(is_ipv4)
    temp = data
    res = []
    while temp[:length] and (get_answer_type(temp) == qtype):
        res.append(temp[:length])
        temp = temp[length:]
    return res


def get_ip(answer, is_ipv4):
    offset = 16 - 12 * int(is_ipv4)
    ip = answer[-offset:]
    return ip


def get_ttl(answer):
    temp = answer[6:10]
    return struct.unpack('!I', temp)[0]


def get_answer_type(answer):
    temp = answer[2:4]
    return struct.unpack("!H", temp)[0]


def check_cache(domain, is_ipv4):
    global stats4, stats6
    if is_ipv4:
        return domain in stats4.keys()
    return domain in stats6.keys()


def ask_forwarder(query, forwarder):
    conn = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    conn.connect((forwarder, 53))
    conn.send(query)
    answer = conn.recv(1024)
    return answer


def update_stats(domain, answers, qlength, is_ipv4):
    global stats4, stats6
    if is_ipv4:
        stats4[domain] = [get_header(answers, qlength)]
    else:
        stats6[domain] = [get_header(answers, qlength)]
    answers = get_answers(answers, qlength)
    answers = cut_answers(answers, is_ipv4)
    if is_ipv4:
        for answer in answers:
            stats4[domain].append(answer)
    else:
        for answer in answers:
            stats6[domain].append(answer)


def update_limits(answers, time, is_ipv4):
    global limits
    answers = get_answers(answers, qlength)
    answers = cut_answers(answers, is_ipv4)
    for answer in answers:
        ttl = get_ttl(answer)
        print(ttl)
        ip = get_ip(answer, is_ipv4)
        limits[ip] = ttl + time


def check_limit(domain, is_ipv4):
    global stats4, stats6, limits
    if is_ipv4:
        for answer in stats4[domain][1:]:
            ip = get_ip(answer, is_ipv4)
            limit = limits[ip]
            if time.time() > limit:
                del stats4[domain]
                return False
        return True
    else:
        for answer in stats6[domain][1:]:
            ip = get_ip(answer, is_ipv4)
            limit = limits[ip]
            if time.time() > limit:
                del stats6[domain]
                return False
        return True


def pack_answer(query, domain, is_ipv4):
    global stats4, stats6
    temp = query[:2]
    if is_ipv4:
        temp += stats4[domain][0][2:]
        for answer in stats4[domain][1:]:
            temp += answer
    else:
        temp += stats6[domain][0][2:]
        for answer in stats6[domain][1:]:
            temp += answer
    return temp


forwarder = get_forwarder()
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(('', 53))
while True:
    query, addr = sock.recvfrom(1024)
    qlength = len(query)
    qdomain = get_domain(query)
    qtype = get_type(query)
    
    if qtype % 27 != 1:
        answer = ask_forwarder(query, forwarder)
        sock.sendto(answer, addr)
        continue

    if check_cache(qdomain, qtype == 1) and check_limit(qdomain, qtype == 1):
        answer = pack_answer(query, qdomain, qtype == 1)
        sock.sendto(answer, addr)
        print("taken from cache memory")

    else:
        answer = ask_forwarder(query, forwarder)
        sock.sendto(answer, addr)
        print("got by forwarder")
        update_stats(qdomain, answer, qlength, qtype == 1)
        cur_time = time.time()
        print(cur_time)
        update_limits(answer, cur_time, qtype == 1)