#!/bin/bash
echo "[SERVER] 👻 Ghost Protocol Initiated..."

pkill -9 gost 2>/dev/null; pkill -9 cloudflared 2>/dev/null

if [ ! -f "gost" ]; then
  wget -q -O gost.gz https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz
  gzip -d gost.gz; chmod +x gost
fi
if [ ! -f "cloudflared" ]; then
  wget -q -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  chmod +x cloudflared
fi

nohup ./gost -L http://:8080 > gost.log 2>&1 &
GOST_PID=$!
echo "GOST HTTP started on :8080"
sleep 2

nohup ./cloudflared tunnel --url http://localhost:8080 > tunnel.log 2>&1 &
sleep 10

TUNNEL_URL=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' tunnel.log | head -n 1)

if [ ! -z "$TUNNEL_URL" ]; then
  echo "[SERVER] ✅ Signal Active: $TUNNEL_URL"
  echo "$TUNNEL_URL" > proxy_url.txt
  
  git config user.email "ghost@bot.com" && git config user.name "Ghost Bot"
  git add proxy_url.txt
  git commit -m "Signal Update [skip ci]" > /dev/null 2>&1
  git push > /dev/null 2>&1
  
  tail -20 gost.log
else
  echo "[SERVER] ❌ Tunnel creation failed."
  echo "Cloudflared logs:"
  tail -30 tunnel.log
fi
