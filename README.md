# mr-do-upnp-c

UPnP/DLNA **MediaRenderer** that feeds audio into
[Snapcast](https://github.com/badaix/snapcast) for multi-room playback.

Built on [gmediarender](https://github.com/hzeller/gmediarender) — a
purpose-built headless UPnP renderer using GStreamer. Shows up as a cast
target in BubbleUPnP, VLC, AirMusic, Windows "Play To", etc.

**This repo exists to provide the UPnP/DLNA front-end for the
[mr-do-player](https://github.com/ElTabaco/mr-do-player) Snapcast
stack.** Cast to this device from any UPnP app → audio goes into the
Snapcast pipeline → plays on all snapclients.

## Docker image

[![CI](https://github.com/ElTabaco/mr-do-upnp-c/actions/workflows/docker-image-upnp-c.yml/badge.svg)](https://github.com/ElTabaco/mr-do-upnp-c/actions)
[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-upnp-c/latest?arch=amd64)](https://hub.docker.com/r/riemerk/mr-do-upnp-c)
[![docker pulls](https://img.shields.io/docker/pulls/riemerk/mr-do-upnp-c)](https://hub.docker.com/r/riemerk/mr-do-upnp-c)

```
riemerk/mr-do-upnp-c:latest    # amd64, arm64
riemerk/mr-do-upnp-c:1.0.0
```

## How it works

```
Phone / laptop running a UPnP controller app
        │
        │  SSDP discovery (1900/UDP multicast 239.255.255.250)
        │  → finds "mrCast" as a MediaRenderer
        │  → user picks a song and casts to it
        │
        ▼
┌──────────────────────────────────────────────┐
│  mr-do-upnp-c (this image, 310MB)            │
│                                              │
│  gmediarender (UPnP MediaRenderer)           │
│  ├─ GStreamer decodes MP3/FLAC/AAC/OGG       │
│  ├─ GStreamer audioresample (sinc, q=10)     │
│  ├─ GStreamer alsasink → ALSA default        │
│  └─ /etc/asound.conf routes to a file plugin │
│         → writes /tmp/music/upnpfifo (FIFO)  │
└──────────────────────────────────────────────┘
        │  raw PCM (44100 Hz, S16_LE, stereo)
        ▼
┌──────────────────────────────────────────────┐
│  snapserver                                  │
│  ├─ reads /tmp/music/upnpfifo                │
│  ├─ encodes as FLAC                          │
│  └─ broadcasts to all snapclients            │
└──────────────────────────────────────────────┘
        │
        ▼
   snapclients (speakers throughout the house)
```

## Why gmediarender (not Kodi)?

Previous versions used Kodi/XBMC from source (659MB). Kodi is a full
media center — X11, OpenGL, skins, video codecs — massive overkill for
a headless audio renderer. gmediarender is purpose-built:

|              | Kodi (old)   | gmediarender (now) |
|--------------|-------------|-------------------|
| Image size   | 659 MB       | 310 MB            |
| X11/GL       | Required     | Not needed        |
| Boot time    | ~30s         | ~2s               |
| Build time   | 15 min       | 5 seconds         |

## Build

```console
./build.sh                    # local (native arch)
VERSION=1.0.0 ./push.sh       # multi-arch push to Docker Hub
```

## Run (Docker Compose)

```console
mkdir -p tmp/music
docker compose up -d
```

## Configuration

### Environment variables

| Var         | Default       | Description                                  |
|-------------|---------------|----------------------------------------------|
| `UPNP_NAME` | `mr-do UPnP`  | Friendly name shown in UPnP controller apps  |
| `UPNP_UUID` | derived from `UPNP_NAME` (MD5) | UPnP device UUID (stable across restarts) |
| `SAMPLE_RATE` | `44100` | Output rate (Hz). Must equal `rate` in `/etc/asound.conf` and snapserver's `sampleformat`. |
| `RESAMPLE_QUALITY` | `10` | GStreamer `audioresample` quality 0–10 (GStreamer default 4), used only for files whose rate differs from `SAMPLE_RATE` |
| `TZ`        | `UTC`         | Timezone                                     |

### Ports

| Port      | Protocol | Purpose                                              |
|-----------|----------|------------------------------------------------------|
| `49152`   | TCP      | UPnP HTTP control (gmediarender default, may vary)  |
| `1900`    | UDP      | SSDP discovery (multicast 239.255.255.250)           |

`hostNetwork: true` (K8s) or `network_mode: host` (Docker) is required.

### Volumes

| Path                 | Type        | Why                                            |
|----------------------|-------------|------------------------------------------------|
| `/etc/asound.conf`   | file (ro)   | ALSA routing to FIFO                           |
| `/tmp/music`         | shared dir  | FIFO pipe shared with snapserver               |
| `/tmp/music/upnpfifo`| named pipe  | Bridge: gmediarender writes → snapserver reads |
| `/tmp`               | emptyDir    | Writable: GStreamer cache, temp                |

### Audio format

```
sampleformat = 44100:16:2    # 44100 Hz, 16-bit, stereo
```

Must match between `SAMPLE_RATE`, `rate` in `etc/asound.conf` and `etc/snapserver.conf`.
44.1 kHz because most music (CD, most streams) is 44.1 kHz: those files are not resampled.

Resampling (files at other rates, e.g. 48/96 kHz) is done by GStreamer `audioresample`
(windowed sinc, `quality=RESAMPLE_QUALITY`) before `alsasink`, not by ALSA's `rate` plugin
(linear interpolation; no alsa-plugins resamplers in the image). Measured in the container
(48 kHz test tones, 15 kHz and 1 kHz, -6 dBFS, output 44.1 kHz S16):

| Path | SNR 15 kHz | SNR 1 kHz | 44.1 kHz input |
|---|---|---|---|
| ALSA `rate` plugin (before) | 13 dB | 64 dB | bit-exact |
| GStreamer `audioresample quality=10` (now) | 79 dB | 79 dB | bit-exact |

79 dB is the limit of S16 without dither at -6 dBFS; a float intermediate stage would
reach 89 dB but dropped about 0.4 s of audio at stream start through the FIFO in tests.

### User

Runs as **UID/GID 1000** (non-root).

## Files

```
docker/
├── Dockerfile              # Debian 12-slim + gmediarender + GStreamer
└── entrypoint.sh           # FIFO creation + gmediarender launch
etc/
├── asound.conf             # ALSA → FIFO routing
└── snapserver.conf         # snapserver config (reads FIFO, encodes FLAC)
docker-compose.yml          # Full stack: renderer + init-fifo + snapserver
build.sh / push.sh          # Build helpers
```

## Credits

- [gmediarender](https://github.com/hzeller/gmediarender) — Hampus Sand
- [Snapcast](https://github.com/badaix/snapcast) — badaix
