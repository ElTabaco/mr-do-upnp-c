# syntax=docker/dockerfile:1
# ═══════════════════════════════════════════════════════════
#  mr-do-upnp-c — Kodi/XBMC headless UPnP/DLNA MediaRenderer
#
#  Built from xbmc/xbmc source for maximum UPnP compatibility
#  (same UPnP stack Kodi itself ships).  Audio is routed via ALSA
#  to a named pipe that snapserver consumes (server-side playback).
#
#  Kodi has NO headless windowing backend, so we run it under
#  Xvfb (a virtual framebuffer X server) at runtime.
#
#  Designed to run as non-root (UID 1000) with a read-only root
#  filesystem under Kubernetes.
# ═══════════════════════════════════════════════════════════

# ──────────────  Stage 1 — Build Kodi from source  ──────────────
FROM debian:12 AS builder

ARG KODI_VERSION=21.3-Omega
ARG DEBIAN_FRONTEND=noninteractive

# Build dependencies — curated for X11 windowing + UPnP + ALSA audio.
# PulseAudio/PipeWire dev headers are deliberately excluded so Kodi
# compiles ALSA-only and can't accidentally route audio to a pulse
# daemon instead of the FIFO pipe.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git ninja-build python3-dev python3-pil \
      pkg-config gperf swig zip unzip curl ca-certificates \
      autoconf automake autopoint autotools-dev gettext libtool lsb-release \
      libasound2-dev libupnp-dev \
      libavahi-client-dev libavahi-common-dev \
      libbluetooth-dev libbluray-dev libbz2-dev \
      libcdio-dev libcrossguid-dev libcurl4-openssl-dev \
      libdbus-1-dev libdrm-dev libegl1-mesa-dev \
      libenca-dev libexpat1-dev libflac-dev libfmt-dev \
      libfontconfig1-dev libfreetype6-dev libfribidi-dev \
      libfstrcmp-dev libgcrypt20-dev libgl1-mesa-dev \
      libgles2-mesa-dev libglew-dev libglu1-mesa-dev \
      libgif-dev libass-dev \
      libgpg-error-dev libiso9660-dev libjpeg-dev \
      liblcms2-dev libltdl-dev liblzo2-dev \
      libmicrohttpd-dev libnfs-dev libogg-dev \
      libpcre3-dev libplist-dev \
      libpng-dev \
      libsmbclient-dev libsndfile1-dev libspdlog-dev \
      libsqlite3-dev libssl-dev libtag1-dev \
      libtiff-dev libtinyxml-dev libtinyxml2-dev \
      libudev-dev libunistring-dev \
      libuuid1 libva-dev libvdpau-dev libvorbis-dev \
      libxkbcommon-dev libxmu-dev libxrandr-dev \
      libxslt1-dev libxt-dev libx11-dev libxext-dev \
      libxml2-dev zlib1g-dev \
      rapidjson-dev libflatbuffers-dev flatbuffers-compiler \
      wayland-protocols meson nasm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Shallow clone of the exact Kodi release tag (NO "v" prefix).
RUN git clone --branch "${KODI_VERSION}" --depth 1 \
      https://github.com/xbmc/xbmc.git .

# ── CMake configure ──
# X11 windowing is mandatory — Kodi has no headless backend, so we
# run it under Xvfb at runtime.  Everything not needed for audio
# playback + UPnP is disabled to shrink the binary.
#
# NOTE: Kodi's optional_deps list (Alsa, PulseAudio, Pipewire, Sndio)
# is discovered via find_package.  We simply don't install the
# PulseAudio/PipeWire dev headers above, so only ALSA is compiled in
# and AUDIO_BACKENDS_LIST resolves to "alsa" only.
RUN cmake -S . -B /build -GNinja \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_BUILD_TYPE=Release \
      -DCORE_SYSTEM_NAME=linux \
      -DCORE_PLATFORM_NAME=x11 \
      -DAPP_RENDER_SYSTEM=gl \
      -DENABLE_UPNP=ON \
      -DENABLE_OPTICAL=OFF \
      -DENABLE_PYTHON=OFF \
      -DENABLE_TESTING=OFF \
      -DENABLE_AIRTUNES=OFF \
      -DENABLE_CEC=OFF \
      -DENABLE_EVENTCLIENTS=OFF \
      -DENABLE_GAME=OFF \
      -DENABLE_BLUETOOTH=OFF \
      -DENABLE_LIRC=OFF \
      -DENABLE_VAAPI=OFF \
      -DENABLE_VDPAU=OFF \
      -DENABLE_MMAL=OFF \
      -DENABLE_SNDIO=OFF \
      -DENABLE_DVDCSS=OFF \
      -DENABLE_INTERNAL_FFMPEG=OFF

# Build core + install.
RUN cmake --build /build --target install

# Strip debug symbols from Kodi binaries (saves ~40 MB).
# Binary is kodi-x11 (55 MB unstripped); kodi-xrandr is tiny.
RUN strip --strip-unneeded /usr/lib/kodi/kodi-x11 /usr/lib/kodi/kodi-xrandr 2>/dev/null || true

# Remove bundled GUI skins — headless, no GUI is ever shown.
# Keep system/ (fonts, keymaps) and media/ (sounds) Kodi needs.
RUN rm -rf /usr/share/kodi/addons/skin.* \
           /usr/share/kodi/media/Splash.png

# ──────────────  Stage 2 — Minimal runtime  ──────────────
FROM debian:12-slim AS runtime

ARG DEBIAN_FRONTEND=noninteractive

# Runtime shared libraries — only what Kodi actually links against.
# Xvfb provides the virtual framebuffer for headless operation.
# No PulseAudio/PipeWire/Bluetooth libs (disabled at build, dead weight).
RUN apt-get update && apt-get install -y --no-install-recommends \
      # Audio stack (ALSA only)
      libasound2 libflac12 libogg0 libvorbis0a libvorbisenc2 \
      libsndfile1 \
      # Rendering / display
      libgl1 libglu1-mesa libegl1 libglew2.2 \
      libdrm2 libgbm1 \
      # X11 windowing (for Xvfb)
      xvfb xauth \
      libx11-6 libxext6 libxrandr2 libxmu6 libxt6 \
      libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
      libxrender1 libxshmfence1 libxxf86vm1 \
      # Networking / UPnP
      libupnp13 libixml10 libcurl4 libmicrohttpd12 libavahi-client3 \
      libavahi-common3 libssl3 libsqlite3-0 \
      # Media libs
      libbluray2 libcdio19 libtag1v5 libjpeg62-turbo \
      libpng16-16 libtiff6 libfreetype6 libfontconfig1 \
      libfribidi0 liblzo2-2 libgif7 libass9 liblcms2-2 \
      # Misc Kodi deps
      libcrossguid0 libfmt9 libpcre3 libspdlog1.10 \
      libtinyxml2.6.2v5 libtinyxml2-9 libfstrcmp0 \
      libgcrypt20 libgpg-error0 liblzma5 libbz2-1.0 \
      libxml2 libxslt1.1 libexpat1 libunistring2 \
      libuuid1 libdbus-1-3 \
      libplist3 \
      libsmbclient libnfs13 libiso9660-11 \
      libltdl7 libudev1 \
      # PID 1 signal handler
      tini \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user (UID/GID 1000 to match K8s securityContext).
RUN groupadd -g 1000 kodi && \
    useradd -u 1000 -g 1000 -d /home/kodi -s /bin/sh kodi && \
    mkdir -p /home/kodi/.kodi/userdata /home/kodi/.kodi/temp

# Copy Kodi install from builder.
# CMAKE_INSTALL_LIBDIR=lib forces install to /usr/lib/kodi/ (not arch-specific).
COPY --from=builder /usr/lib/kodi /usr/lib/kodi
COPY --from=builder /usr/share/kodi /usr/share/kodi
COPY --from=builder /usr/bin/kodi /usr/bin/kodi
COPY --from=builder /usr/bin/kodi-standalone /usr/bin/kodi-standalone

# Kodi default configuration — copied to $HOME on first boot by
# entrypoint.sh (HOME is writable emptyDir, root FS is read-only).
COPY settings/advancedsettings.xml /defaults/advancedsettings.xml
COPY settings/guisettings.xml /defaults/guisettings.xml

# Entrypoint — launches Xvfb then Kodi headless inside it.
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Ensure Kodi home dir is owned by the runtime user.
RUN chown -R 1000:1000 /home/kodi

# UPnP HTTP control port + SSDP discovery (UDP multicast 239.255.255.250)
EXPOSE 49494/tcp 1900/udp

# Run as non-root user (matches K8s securityContext runAsUser: 1000)
USER 1000:1000

# Run as PID 1 via tini for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
