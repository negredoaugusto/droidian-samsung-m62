#!/usr/bin/env python3
"""Executa comandos no shell de depuração (telnet porta 23) do initramfs Halium e imprime a saída.
Uso: halium_sh.py 'comando1; comando2' [timeout_s]"""
import socket, sys, time

cmd = sys.argv[1]; tmo = float(sys.argv[2]) if len(sys.argv) > 2 else 8
s = socket.create_connection(('192.168.2.15', 23), timeout=5)
time.sleep(0.8)
def drain(t):
    s.settimeout(t); buf = b''
    try:
        while True:
            d = s.recv(65536)
            if not d: break
            # recusa negociações telnet (IAC DO/WILL -> WONT/DONT)
            out = bytearray(); i = 0
            while i < len(d):
                if d[i] == 255 and i + 2 < len(d):
                    s.sendall(bytes([255, 252 if d[i+1] == 253 else 254, d[i+2]])); i += 3
                else:
                    out.append(d[i]); i += 1
            buf += bytes(out)
    except socket.timeout:
        pass
    return buf
drain(1.0)
marker = '__FIM__'
s.sendall((cmd + "; echo __F''IM__\n").encode())
end = time.time() + tmo; buf = b''
while time.time() < end and marker.encode() not in buf.split(b'\n', 1)[-1]:
    buf += drain(0.5)
txt = buf.decode(errors='replace').replace('\r', '')
txt = txt.split("__F''IM__", 1)[-1]
print(txt.split(marker)[0] if marker in txt else txt)
s.close()
