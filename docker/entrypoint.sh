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

# Ignore SIGPIPE — when snapserver closes the FIFO read end during
# restart, ALSA's write gets SIGPIPE which would kill gmediarender.
trap '' PIPE

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
#   -u          fixed UUID (persistent across restarts, so controllers
#               remember this device instead of seeing a new one each time)
#   -o gst      use GStreamer output module
#   --gstout-audiosink alsasink   write to ALSA (→ asound.conf → FIFO)
#   --mime-filter audio            audio only (no video)
#   --logfile stdout              log to stdout for kubectl logs
#
# UUID: derived from the hostname so it's stable across restarts
# (hostNetwork pods keep the node hostname).  Using a hash of the
# name avoids the "new device every restart" problem.
if [ -z "${UPNP_UUID:-}" ]; then
    # Generate a deterministic UUID from the friendly name
    UPNP_UUID=$(echo "$FRIENDLY_NAME" | md5sum | awk '{printf "uuid:%s-%s-%s-%s-%s", substr($1,1,8), substr($1,9,4), substr($1,13,4), substr($1,17,4), substr($1,21,12)}')
fi

exec gmediarender \
    -f "$FRIENDLY_NAME" \
    -u "$UPNP_UUID" \
    -o gst \
    --gstout-audiosink alsasink \
    --mime-filter audio \
    --logfile stdout
