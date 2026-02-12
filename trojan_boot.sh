#!/bin/bash
echo "[SERVER] 👻 Trojan Protocol Initiated..."

pkill -9 trojan 2>/dev/null; pkill -9 cloudflared 2>/dev/null

if [ ! -f "trojan" ]; then
  wget -q -O trojan.tar.xz https://github.com/trojan-gfw/trojan/releases/download/v1.16.0/trojan-1.16.0-linux-amd64.tar.xz
  tar -xf trojan.tar.xz; chmod +x trojan/trojan
fi
if [ ! -f "cloudflared" ]; then
  wget -q -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  chmod +x cloudflared
fi

openssl genrsa -out /tmp/trojan.key 2048 > /dev/null 2>&1
openssl req -new -x509 -key /tmp/trojan.key -out /tmp/trojan.crt -days 365 -subj "/CN=localhost" > /dev/null 2>&1

cat > trojan_server.json << 'TCONF'
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 8443,
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "password": [],
  "log_level": 1,
  "ssl": {
    "cert": "/tmp/trojan.crt",
    "key": "/tmp/trojan.key",
    "key_password": "",
    "cipher": "DEFAULT",
    "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256",
    "prefer_server_cipher": true,
    "alpn": [
      "http/1.1"
    ],
    "reuse_session": true,
    "session_ticket": false,
    "session_timeout": 600,
    "plain_http_response": "",
    "curves": "",
    "dhparam": ""
  }
}
TCONF

nohup ./trojan/trojan trojan_server.json > trojan.log 2>&1 &
echo "Trojan server started on :8443"
sleep 3

nohup ./cloudflared tunnel --url https://localhost:8443 > tunnel.log 2>&1 &
sleep 10

TUNNEL_URL=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' tunnel.log | head -n 1)

if [ ! -z "$TUNNEL_URL" ]; then
  echo "[SERVER] ✅ Signal Active: $TUNNEL_URL"
  echo "$TUNNEL_URL" > proxy_url.txt
  
  git config user.email "ghost@bot.com" && git config user.name "Ghost Bot"
  git add proxy_url.txt
  git commit -m "Trojan Signal [skip ci]" > /dev/null 2>&1
  git push > /dev/null 2>&1
else
  echo "[SERVER] ❌ Tunnel creation failed."
  tail -30 tunnel.log
fi
