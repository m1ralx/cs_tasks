import socket
import base64
import re
import getpass
import quopri
import os


def get(cmd, arg1):
    sock.send("{} {}\r\n".format(cmd, arg1).encode())
    data = sock.recv(1024).decode()
    return data

def long_get(cmd, arg1, arg2):
    sock.send("{} {} {}\r\n".format(cmd, arg1, arg2).encode())
    sock.settimeout(0.5)
    data = ""
    while True:
        try:
            part = sock.recv(1024).decode()
            data += part
        except socket.error:
            break
    return data


def sadness():
    print("Session will be terminated")
    os._exit(0)
    

def check_ans(ans):
    if ans[:3] == '+OK':
        pass
    else:
        sadness()


def interactive(data):
    print(data)
    check_ans(data)


def encode(code):
    result = ""
    code = code.replace('"', '')
    if code.startswith("=?"):
        code = code[2:]
        mo = re.search(r"([^?]*)(\?)(\S)(\?)([^?]*)", code)
        encoding = mo.group(1)
        if mo.group(3).lower().startswith('b'):
            result = base64.b64decode(mo.group(5)).decode(encoding)
        elif mo.group(3).lower().startswith('q'):
            result = quopri.decodestring(mo.group(5)).decode(encoding)
        else:
            print("Can't decode the sender's name")
            sadness()
    else:
        result = re.match(r"\S*", code).group(0)
    return result


def get_sender(data):
    mo = re.search(r"(F|f)(rom: )([^<]*)", data)
    code = mo.group(3)
    sender = encode(code)
    return sender


def get_subject(data):
    mo = re.search(r"(S|s)(ubject: )([^ ]*)", data)
    code = mo.group(3)
    subject = encode(code)
    return subject


def get_size(number):
    data = get('LIST', str(number + 1))
    check_ans(data)
    return data.split(' ')[2]


def represent(letter, sender, subject, size):
    print("____________________________")
    print("Letter № {}".format(str(letter)))
    print("From: {}".format(sender))
    print("Subject: {}".format(subject))
    print("Size: {} octets".format(str(size)))
    


sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(10.0)
try:
    sock.connect((input('Choose the pop3 server: '), 110))
except socket.gaierror:
    print("Bad internet connection or non-existing pop3 server")
    sadness()
data = sock.recv(2048).decode()
interactive(data)

user = input('Enter your username: ')
data = get('USER', user)
interactive(data)

password = (getpass.getpass("Enter your password: "))
data = get('PASS', password)
check_ans(data)

data = get('STAT', '')
check_ans(data)
number = int(data.split(' ')[1])


for letter in range(number):
    data = long_get('TOP', str(letter + 1), '0')
    #print(data)
    sender = get_sender(data)
    subject = get_subject(data)
    size = get_size(letter).strip()
    represent(letter + 1, sender, subject, size)