#!/bin/sh
set -e

# ═══════════════════════════════════════════════════════════
#  mr-do-upnp-c entrypoint
#
#  Runs as UID 1000 (non-root).  The root filesystem is read-only
#  in K8s (readOnlyRootFilesystem: true); writable mounts are:
#    /tmp              → emptyDir (Xvfb sockets, Kodi userdata/temp)
#    /tmp/music        → emptyDir shared with snapserver (FIFO)
#
#  We use /tmp/kodi-home as HOME (always writable via the tmp
#  emptyDir) so Kodi can write guisettings.xml, temp/, and logs
#  without needing a separate PVC.
#
#  Audio routing: Kodi PAPlayer → ALSA default → /etc/asound.conf
#  → writes to /tmp/music/upnpfifo → snapserver reads the pipe.
#  PulseAudio/PipeWire are not compiled in (ALSA-only build).
# ═══════════════════════════════════════════════════════════

# Use /tmp/kodi-home as HOME — always writable (tmp emptyDir).
export HOME="/tmp/kodi-home"

# ── 1. Seed Kodi config from defaults on first boot ──
# advancedsettings.xml / guisettings.xml are baked into /defaults/
# (read-only).  Copy them to the writable home on first run.
USERDATA="${HOME}/.kodi/userdata"
mkdir -p "$USERDATA" "${HOME}/.kodi/temp"
if [ ! -f "$USERDATA/advancedsettings.xml" ] && [ -f /defaults/advancedsettings.xml ]; then
    cp /defaults/advancedsettings.xml "$USERDATA/"
    cp /defaults/guisettings.xml "$USERDATA/"
    echo "[entrypoint] Seeded Kodi config from /defaults/"
fi

# ── 2. Apply UPNP_NAME override (friendly device name) ──
# Kodi reads the device name from guisettings.xml <devicename>,
# not from an env var, so patch the file if UPNP_NAME is set.
if [ -n "${UPNP_NAME:-}" ]; then
    sed -i "s|<devicename>.*</devicename>|<devicename>${UPNP_NAME}</devicename>|" \
        "$USERDATA/guisettings.xml" 2>/dev/null || true
fi

# ── 3. Ensure the ALSA→snapserver FIFO exists ──
# In K8s an initContainer creates this; for standalone Docker we
# create it here.  ALSA's file plugin needs a FIFO (named pipe),
# not a regular file.
FIFO="/tmp/music/upnpfifo"
mkdir -p /tmp/music
if [ ! -p "$FIFO" ]; then
    rm -f "$FIFO"
    mkfifo -m 0666 "$FIFO"
fi

# ── 4. Start Xvfb (virtual framebuffer) ──
# Kodi has no headless backend; Xvfb provides a dummy X display.
# Remove stale lock files from a previous crash (K8s container restart
# reuses the same emptyDir, so /tmp/.X99-lock can persist).
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
Xvfb :99 -screen 0 1280x720x24 -nolisten tcp -ac &
XVFB_PID=$!
export DISPLAY=:99

# Clean up Xvfb when the script exits (Kodi crash, signal, etc.)
trap 'kill "$XVFB_PID" 2>/dev/null' EXIT INT TERM

# Give Xvfb a moment to create the socket.
sleep 1
if ! kill -0 "$XVFB_PID" 2>/dev/null; then
    echo "[entrypoint] FATAL: Xvfb failed to start" >&2
    exit 1
fi
echo "[entrypoint] Xvfb started (PID $XVFB_PID) on :99"

# ── 5. Launch Kodi ──
# Valid Kodi v21 CLI flags: --standalone, --debug, --settings=,
# -p/--portable, -fs.  (--player and --nolirc do NOT exist.)
# --standalone = run without a window manager / desktop session.
# PAPlayer is enforced via <defaultplayer> in advancedsettings.xml.
FRIENDLY_NAME="${UPNP_NAME:-mr-do UPnP}"
echo "[entrypoint] Starting Kodi UPnP renderer as '$FRIENDLY_NAME'"

# Call the kodi wrapper directly (not kodi-standalone) to avoid the
# D-Bus session-bus and PulseAudio setup that kodi-standalone.sh does.
# The wrapper sets up KODI_DATA, CRASHLOG_DIR and execs kodi-x11.
exec /usr/bin/kodi --standalone
