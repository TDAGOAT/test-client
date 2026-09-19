#!/bin/bash
nohup bash -c 'while true; do touch /workspaces/test-client/.keepalive; sleep 240; done' >/dev/null 2>&1 &

if [ -f browser-profile.tar.gz ]; then
  docker run --rm --entrypoint "" -v chromium_data:/config -v "$(pwd)":/backup lscr.io/linuxserver/chromium:latest tar -xzf /backup/browser-profile.tar.gz -C /config
fi

# High-Performance Flags (Cleanly formatted with zero spaces inside flags)
PERF_FLAGS="--disable-smooth-scrolling --num-raster-threads=2 --enable-zero-copy --disable-background-timer-throttling --disable-renderer-backgrounding --disable-backgrounding-occluded-windows --disable-breakpad --disable-component-update --disable-features=Translate,OptimizationHints,MediaRouter,CalculateNativeWinOcclusion --disable-blink-features=AutomationControlled https://discord.com/app https://www.instagram.com https://www.tiktok.com"

# Start container with Selkies speed environment variables
if ! docker start chromium 2>/dev/null; then
  docker run -d \
    --name=chromium \
    -e PUID=1000 \
    -e PGID=1000 \
    -e TZ=Etc/UTC \
    -e SELKIES_USE_CSS_SCALING=true \
    -e SELKIES_USE_CPU=true \
    -e SELKIES_CRF=28 \
    -e SELKIES_VIDEO_FPS=60 \
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

# Disable stuck key repeats
docker exec chromium bash -c "export DISPLAY=:1; xset -r 2>/dev/null || (export DISPLAY=:0; xset -r)" 2>/dev/null

# Inject Bitwarden policy and Bookmarks
docker exec -u 0 chromium mkdir -p /etc/chromium/policies/managed /config/.config/chromium/Default 2>/dev/null
docker cp .devcontainer/policies/custom_policy.json chromium:/etc/chromium/policies/managed/custom_policy.json 2>/dev/null
docker cp .devcontainer/browser-config/Bookmarks chromium:/config/.config/chromium/Default/Bookmarks 2>/dev/null

# Patch Selkies web interface to force optimal side-menu settings on open
docker exec -u 0 chromium bash -c '
  for html in $(find /usr/share/selkies -name "index.html" 2>/dev/null); do
    if ! grep -q "auto-speed-patch" "$html"; then
      sed -i "s|</head>|<script id=\"auto-speed-patch\">window.addEventListener(\"load\",()=>{setTimeout(()=>{try{localStorage.setItem(\"use_css_cursors\",\"true\");localStorage.setItem(\"hidpi\",\"false\");localStorage.setItem(\"use_paint_overs\",\"false\");localStorage.setItem(\"anti_aliasing\",\"false\");localStorage.setItem(\"crf\",\"28\");}catch(e){}},500);});</script></head>|g" "$html"
    fi
  done
' 2>/dev/null

# Install color emojis if missing
docker exec -u 0 chromium bash -c '
  if ! fc-list : family | grep -qi "emoji"; then
    command -v apt-get >/dev/null 2>&1 && apt-get update && apt-get install -y fonts-noto-color-emoji && fc-cache -f
  fi
' 2>/dev/null
