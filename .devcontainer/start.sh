#!/bin/bash
# Keep-alive heartbeat
nohup bash -c 'while true; do touch /workspaces/test-client/.keepalive; sleep 240; done' >/dev/null 2>&1 &

# Auto-restore profile if present
if [ -f browser-profile.tar.gz ]; then
  docker run --rm --entrypoint "" -v chromium_data:/config -v "$(pwd)":/backup lscr.io/linuxserver/chromium:latest tar -xzf /backup/browser-profile.tar.gz -C /config
fi

# High-Performance Chromium Flags
PERF_FLAGS="--disable-smooth-scrolling --num-raster-threads=2 --enable-zero-copy --disable-background-timer-throttling --disable-renderer-backgrounding --disable-backgrounding-occluded-windows --disable-breakpad --disable-component-update --disable-features=Translate,OptimizationHints,MediaRouter,CalculateNativeWinOcclusion --disable-blink-features=AutomationControlled --user-agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36' https://discord.com/app https://www.instagram.com https://www.tiktok.com"

# Launch container
if ! docker start chromium 2>/dev/null; then
  docker run -d \
    --name=chromium \
    -e PUID=1000 \
    -e PGID=1000 \
    -e TZ=Etc/UTC \
    -e CHROME_CLI="$PERF_FLAGS" \
    -p 3000:3000 \
    -p 3001:3001 \
    -v chromium_data:/config \
    --security-opt seccomp=unconfined \
    --shm-size="2gb" \
    --restart unless-stopped \
    lscr.io/linuxserver/chromium:latest
fi

sleep 2

# Disable stuck key repeats immediately
docker exec chromium bash -c "export DISPLAY=:1; xset -r 2>/dev/null || (export DISPLAY=:0; xset -r)" 2>/dev/null

# Inject performance policy and bookmarks
docker exec -u 0 chromium mkdir -p /etc/chromium/policies/managed /config/.config/chromium/Default 2>/dev/null
docker cp .devcontainer/policies/custom_policy.json chromium:/etc/chromium/policies/managed/custom_policy.json 2>/dev/null
docker cp .devcontainer/browser-config/Bookmarks chromium:/config/.config/chromium/Default/Bookmarks 2>/dev/null

# Install color emojis if missing
docker exec -u 0 chromium bash -c '
  if ! fc-list : family | grep -qi "emoji"; then
    command -v apt-get >/dev/null 2>&1 && apt-get update && apt-get install -y fonts-noto-color-emoji && fc-cache -f
  fi
' 2>/dev/null
