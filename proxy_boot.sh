#!/bin/bash
echo "[SERVER] Starting SOCKS5 proxy..."

pkill -9 python3 2>/dev/null

python3 << 'PYEOF'
import socket
import sys
import threading
import select

PORT = 1080

def handle_client(client_socket):
    try:
        data = client_socket.recv(2)
        if data[0:1] != b'\x05':
            client_socket.close()
            return
        
        nmethods = data[1]
        methods = client_socket.recv(nmethods)
        client_socket.send(b'\x05\x00')
        
        request = client_socket.recv(4)
        if request[0:1] != b'\x05':
            client_socket.close()
            return
        
        cmd = request[1]
        atyp = request[3]
        
        if atyp == 1:
            addr = client_socket.recv(4)
            ip = '.'.join(map(str, addr))
        elif atyp == 3:
            addr_len = client_socket.recv(1)[0]
            addr = client_socket.recv(addr_len).decode()
            ip = addr
        
        port_bytes = client_socket.recv(2)
        port = int.from_bytes(port_bytes, 'big')
        
        response = b'\x05\x00\x00\x01' + ip.encode() if atyp == 1 else b'\x05\x00\x00\x03' + bytes([len(ip)]) + ip.encode()
        response += port_bytes
        client_socket.send(response)
        
        target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target.connect((ip, port))
        
        def forward(src, dst):
            while True:
                data = src.recv(4096)
                if not data:
                    break
                dst.send(data)
        
        t1 = threading.Thread(target=forward, args=(client_socket, target))
        t2 = threading.Thread(target=forward, args=(target, client_socket))
        t1.daemon = True
        t2.daemon = True
        t1.start()
        t2.start()
        
    except:
        pass
    finally:
        try:
            client_socket.close()
        except:
            pass

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('127.0.0.1', PORT))
server.listen(5)
print(f"SOCKS5 proxy listening on port {PORT}")

while True:
    client, addr = server.accept()
    t = threading.Thread(target=handle_client, args=(client,))
    t.daemon = True
    t.start()
PYEOF
