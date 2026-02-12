#!/bin/bash
echo "[SERVER] 👻 Ghost Protocol Initiated..."

# 1. Clean Slate
pkill -9 gost 2>/dev/null; pkill -9 cloudflared 2>/dev/null

# 2. Install Tools (If Missing)
if [ ! -f "gost" ]; then
  wget -q -O gost.gz https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz
  gzip -d gost.gz; chmod +x gost
fi
if [ ! -f "cloudflared" ]; then
  wget -q -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
  chmod +x cloudflared
fi

# 3. Start Engines (SOCKS5 over WSS)
nohup ./gost -L ws://:8080 > /dev/null 2>&1 &
nohup ./cloudflared tunnel --url http://localhost:8080 > tunnel.log 2>&1 &

# 4. Broadcast Signal
sleep 8
TUNNEL_URL=$(grep -o 'https://.*\.trycloudflare.com' tunnel.log | head -n 1)

if [ ! -z "$TUNNEL_URL" ]; then
  echo "[SERVER] ✅ Signal Active: $TUNNEL_URL"
  echo "$TUNNEL_URL" > proxy_url.txt
  
  # Dead Drop to Repo
  git config user.email "ghost@bot.com" && git config user.name "Ghost Bot"
  git add proxy_url.txt
  git commit -m "Signal Update [skip ci]" > /dev/null 2>&1
  git push > /dev/null 2>&1
else
  echo "[SERVER] ❌ Tunnel creation failed."
fi
