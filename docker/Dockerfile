# syntax=docker/dockerfile:1
# ═══════════════════════════════════════════════════════════
#  mr-do-upnp-c — lightweight UPnP/DLNA MediaRenderer
#
#  Uses gmediarender (GStreamer-based, ~90MB total) instead of
#  Kodi (659MB).  Purpose-built headless renderer — no X11, no
#  GL, no skin, no media center overhead.
#
#  Audio routing: GStreamer alsasink → /etc/asound.conf →
#  writes to /tmp/music/upnpfifo (named pipe) → snapserver reads.
#
#  Designed to run as non-root (UID 1000) with a read-only root
#  filesystem under Kubernetes.
# ═══════════════════════════════════════════════════════════

FROM debian:12-slim

ARG DEBIAN_FRONTEND=noninteractive

# Runtime packages — gmediarender + GStreamer ALSA + codecs.
# gstreamer1.0-libav: MP3, AAC, WMA, Opus (via ffmpeg — REQUIRED for MP3)
# gstreamer1.0-plugins-good: FLAC, OGG, WAV, MP3 (mpg123)
# gstreamer1.0-plugins-base: ALSA sink, decodebin, volume
# gstreamer1.0-alsa: ALSA audio sink plugin
# tini: PID 1 signal handling
RUN apt-get update && apt-get install -y --no-install-recommends \
      gmediarender \
      gstreamer1.0-plugins-base \
      gstreamer1.0-plugins-good \
      gstreamer1.0-libav \
      gstreamer1.0-alsa \
      libasound2 \
      tini \
      ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

# Create non-root user (UID/GID 1000 to match K8s securityContext).
RUN groupadd -g 1000 upnp && \
    useradd -u 1000 -g 1000 -d /home/upnp -s /bin/sh upnp

# ALSA config routes audio to the FIFO pipe.
# gmediarender writes to the ALSA default device; asound.conf
# redirects to /tmp/music/upnpfifo via the file plugin.
COPY etc/asound.conf /etc/asound.conf

# Entrypoint.
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# UPnP HTTP control port + SSDP discovery.
# NOTE: gmediarender uses libupnp which binds 49152+ (ephemeral).
# We EXPOSE the documented default but the actual port is dynamic.
EXPOSE 49152/tcp 1900/udp

# Run as non-root user.
USER 1000:1000

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
