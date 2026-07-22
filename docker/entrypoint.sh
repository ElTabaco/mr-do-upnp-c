#!/bin/sh
set -e

# ═══════════════════════════════════════════════════════════
#  mr-do-upnp-c entrypoint (gmediarender)
#
#  Runs as UID 1000 (non-root). The root filesystem is read-only
#  in K8s; writable mounts are:
#    /tmp        → emptyDir (GStreamer cache, temp)
#    /tmp/music  → emptyDir shared with snapserver (FIFO)
#
#  Audio: gmediarender → GStreamer alsasink → /etc/asound.conf
#  → /tmp/music/upnpfifo → snapserver
# ═══════════════════════════════════════════════════════════

FRIENDLY_NAME="${UPNP_NAME:-mr-do UPnP}"

# Ensure the ALSA→snapserver FIFO exists (standalone Docker fallback).
# In K8s an initContainer creates this.
FIFO="/tmp/music/upnpfifo"
mkdir -p /tmp/music
if [ ! -p "$FIFO" ]; then
    rm -f "$FIFO"
    (umask 0 && mkfifo -m 0666 "$FIFO")
fi

# Set GStreamer cache to writable tmp (read-only root FS).
export GST_REGISTRY="/tmp/gstreamer-registry.cache"
export XDG_CACHE_HOME="/tmp/.cache"
mkdir -p "$XDG_CACHE_HOME"

echo "[entrypoint] Starting gmediarender UPnP renderer as '$FRIENDLY_NAME'"
echo "[entrypoint] Audio: GStreamer alsasink → /etc/asound.conf → $FIFO"

# gmediarender flags:
#   -f          friendly name shown in UPnP controller apps
#   -o gst      use GStreamer output module
#   --gstout-audiosink alsasink   write to ALSA (→ asound.conf → FIFO)
#   --mime-filter audio            audio only (no video)
#   --logfile stdout              log to stdout for kubectl logs
exec gmediarender \
    -f "$FRIENDLY_NAME" \
    -o gst \
    --gstout-audiosink alsasink \
    --mime-filter audio \
    --logfile stdout
