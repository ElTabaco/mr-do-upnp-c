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

# Kodi's GL subsystem writes shader cache to $HOME/.cache before our
# entrypoint runs.  Point XDG_CACHE_HOME at the writable tmp dir so
# it doesn't try /home/kodi/.cache (read-only root filesystem).
export XDG_CACHE_HOME="/tmp/kodi-home/.cache"
mkdir -p "$XDG_CACHE_HOME"

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
# Use awk instead of sed to avoid injection via sed metacharacters
# (|, &, backslashes) in the UPNP_NAME value.
if [ -n "${UPNP_NAME:-}" ]; then
    awk -v name="$UPNP_NAME" \
        '{gsub(/<devicename>.*<\/devicename>/, "<devicename>" name "</devicename>"); print}' \
        "$USERDATA/guisettings.xml" > "$USERDATA/guisettings.xml.tmp" 2>/dev/null && \
        mv "$USERDATA/guisettings.xml.tmp" "$USERDATA/guisettings.xml" || \
        rm -f "$USERDATA/guisettings.xml.tmp"
fi

# ── 3. Ensure the ALSA→snapserver FIFO exists ──
# In K8s an initContainer creates this; for standalone Docker we
# create it here.  ALSA's file plugin needs a FIFO (named pipe),
# not a regular file.  The umask is cleared so the FIFO gets mode
# 0666 (readable+writable by snapserver running as another UID).
FIFO="/tmp/music/upnpfifo"
mkdir -p /tmp/music
if [ ! -p "$FIFO" ]; then
    rm -f "$FIFO"
    (umask 0 && mkfifo -m 0666 "$FIFO")
fi

# ── 4. Start Xvfb (virtual framebuffer) ──
# Kodi has no headless backend; Xvfb provides a dummy X display.
# Remove stale lock files from a previous crash (K8s container restart
# reuses the same emptyDir, so /tmp/.X99-lock can persist).
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
Xvfb :99 -screen 0 1280x720x24 -nolisten tcp -ac &
XVFB_PID=$!
export DISPLAY=:99

# Wait for the X socket to appear (more reliable than a fixed sleep).
i=0
while [ $i -lt 50 ]; do
    [ -S /tmp/.X11-unix/X99 ] && break
    sleep 0.1
    i=$((i + 1))
done

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
echo "[entrypoint] Starting Kodi UPnP renderer as '${UPNP_NAME:-mr-do UPnP}'"

# Run kodi in the foreground (NOT exec) so the trap fires on exit
# and Xvfb gets a clean SIGTERM instead of relying on PID namespace
# teardown.
/usr/bin/kodi --standalone &
KODI_PID=$!

# Clean up Xvfb when Kodi exits (crash, signal, etc.)
trap 'kill "$KODI_PID" "$XVFB_PID" 2>/dev/null' EXIT INT TERM

# Wait for Kodi to exit.  When it does, the trap kills Xvfb.
wait "$KODI_PID"
