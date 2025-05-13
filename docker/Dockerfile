# ──────────────  Stage 1 ─ Build  ──────────────
FROM alpine:3.19 AS builder
ARG KODI_VERSION=v21.2-Omega      # latest stable :contentReference[oaicite:0]{index=0}

RUN apk add --no-cache \
      build-base cmake git ninja python3 \
      nasm yasm zip unzip \
      dbus-dev libusb-dev libmicrohttpd-dev \
      alsa-lib-dev pulseaudio-dev libupnp-dev \
      expat-dev curl-dev samba-dev \
      lzo-dev zlib-dev jpeg-turbo-dev \
      libpng-dev \
      linux-headers

WORKDIR /src
RUN git clone --branch ${KODI_VERSION} --depth 1 https://github.com/xbmc/xbmc.git .

# ── optional size tweaks ──
COPY patches/ /patches
RUN for p in /patches/*.diff; do [ -f "$p" ] && patch -p1 < "$p"; done

RUN cmake -S . -B /build -GNinja \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCORE_SYSTEM_NAME=linux \
        -DAPP_RENDER_SYSTEM=offscreen \
        -DENABLE_X11=OFF -DENABLE_WAYLAND=OFF \
        -DENABLE_OPENGL=OFF -DENABLE_GLES=OFF \
        -DENABLE_VAAPI=OFF -DENABLE_VDPAU=OFF -DENABLE_MMAL=OFF \
        -DENABLE_CEC=OFF -DENABLE_AIRPLAY=OFF \
        -DENABLE_EVENTCLIENTS=OFF -DENABLE_GAME=OFF \
        -DENABLE_TEXTUREPACKER=OFF \
        -DENABLE_UPNP=ON \
        -DADDONS_TO_BUILD="audiodecoder.flac;audiodecoder.lame;audiodecoder.vorbis" \
        -DZERO_BUILD=ON

RUN cmake --build /build --target install

# ──────────────  Stage 2 ─ Runtime  ──────────────
FROM alpine:3.19

RUN apk add --no-cache alsa-lib pulseaudio dbus libupnp curl expat samba-common

# copy binaries & libs
COPY --from=builder /usr /usr

# user configuration
COPY settings/advancedsettings.xml /root/.kodi/userdata/

# entry point
COPY docker/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
