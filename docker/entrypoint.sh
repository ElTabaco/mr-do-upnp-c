#!/bin/sh
set -e

# ═══════════════════════════════════════════════════════════
#  mr-do-upnp-c entrypoint
#
#  Kodi has no headless windowing backend, so we launch Xvfb
#  (a virtual framebuffer) and run Kodi inside it on DISPLAY=:99.
#
#  Audio routing is handled entirely by /etc/asound.conf (mounted
#  from the K8s ConfigMap): ALSA default → rate conversion →
#  write to /tmp/music/upnpfifo (named pipe).  Snapserver reads
#  the other end of that pipe for server-side playback.
#  We must NOT start PulseAudio — it would grab the ALSA default
#  device and bypass the pipe.
# ═══════════════════════════════════════════════════════════

# Start Xvfb on a detached display.
Xvfb :99 -screen 0 1280x720x24 -nolisten tcp &
XVFB_PID=$!

# Give Xvfb a moment to create the socket.
sleep 1
if ! kill -0 "$XVFB_PID" 2>/dev/null; then
    echo "[entrypoint] FATAL: Xvfb failed to start" >&2
    exit 1
fi
echo "[entrypoint] Xvfb started (PID $XVFB_PID) on :99"

# Kodi's UPnP renderer must know its own IP to build correct
# device-description URLs.  On hostNetwork this is the node's LAN IP.
# Let Kodi auto-detect; override via DEVICE_IP if needed.
export DISPLAY=:99
export KODI_AIRPLAY=0
export KODI_AIRPLAYY=0

# Friendly name override — shows up in UPnP/DLNA controller apps.
FRIENDLY_NAME="${UPNP_NAME:-mr-do UPnP}"
echo "[entrypoint] Starting Kodi UPnP renderer as '$FRIENDLY_NAME'"

# kodi-standalone wraps kodi with D-Bus/session setup.
# --player=PAPlayer forces the built-in audio player (no video).
# --nolirc disables infrared remote.
exec kodi-standalone --player=PAPlayer --nolirc
