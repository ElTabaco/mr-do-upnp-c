# mr-do-upnp-c

UPnP/DLNA **MediaRenderer** that feeds audio into
[Snapcast](https://github.com/badaix/snapcast) for multi-room playback.

Built from [Kodi/XBMC v21 (Omega)](https://github.com/xbmc/xbmc) source —
the same UPnP stack Kodi itself ships, so it shows up reliably as a cast
target in VLC, BubbleUPnP, AirMusic, Windows "Play To", etc.

**This repo exists to provide the UPnP/DLNA front-end for the
[mr-do-player](https://github.com/ElTabaco/mr-do-player) Snapcast
stack.** The whole point is: cast to this device from any UPnP app →
audio goes into the Snapcast pipeline → plays on all snapclients.

## Docker image

[![CI](https://github.com/ElTabaco/mr-do-upnp-c/actions/workflows/docker-image-upnp-c.yml/badge.svg)](https://github.com/ElTabaco/mr-do-upnp-c/actions)
[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-upnp-c/latest?arch=amd64)](https://hub.docker.com/r/riemerk/mr-do-upnp-c)
[![docker pulls](https://img.shields.io/docker/pulls/riemerk/mr-do-upnp-c)](https://hub.docker.com/r/riemerk/mr-do-upnp-c)

```
riemerk/mr-do-upnp-c:latest    # amd64, arm64
riemerk/mr-do-upnp-c:0.2.0
```

## How it works

```
Phone / laptop running a UPnP controller app
        │
        │  SSDP discovery (1900/UDP multicast 239.255.255.250)
        │  → finds "mr-do UPnP" as a MediaRenderer
        │  → user picks a song and casts to it
        │
        ▼
┌──────────────────────────────────────────────┐
│  mr-do-upnp-c (this image)                   │
│                                              │
│  Kodi v21 headless under Xvfb                │
│  ├─ PAPlayer renders the audio               │
│  ├─ ALSA default device                      │
│  └─ /etc/asound.conf routes to a file plugin │
│         → writes /tmp/music/upnpfifo (FIFO)  │
└──────────────────────────────────────────────┘
        │  raw PCM (48000 Hz, S16_LE, stereo)
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

The FIFO pipe (`/tmp/music/upnpfifo`) is the bridge between this container
and snapserver. In K8s both containers share an emptyDir at `/tmp/music`;
in Docker Compose they share a host directory.

## Quick start (Docker Compose)

The included `docker-compose.yml` runs the full stack: this renderer +
snapserver + an init container that creates the FIFO.

```console
# Create the shared dir + FIFO
mkdir -p tmp/music

# Start the full stack
docker compose up -d
```

Then open a UPnP controller app on your phone (e.g. BubbleUPnP, VLC) and
cast to "mr-do UPnP". Connect snapclients to the snapserver to hear the
audio on your speakers.

## Build

```console
# Local (native arch)
./build.sh

# Multi-arch push to Docker Hub (needs docker login + buildx)
VERSION=0.1.0 ./push.sh
```

The Kodi compile (~1600 ninja targets) takes ~15 min on a 16-core machine.
The final multi-stage image is ~650 MB (builder stage discarded).

## Files

```
docker/
├── Dockerfile              # Multi-stage: build Kodi from source → slim runtime
└── entrypoint.sh           # Xvfb + config seeding + mkfifo + Kodi launch
etc/
├── asound.conf             # ALSA → FIFO pipe routing (used by Kodi PAPlayer)
└── snapserver.conf         # Snapserver config (reads the FIFO, encodes FLAC)
settings/
├── advancedsettings.xml    # UPnP renderer=ON, audio-only, PAPlayer default
└── guisettings.xml         # Pre-seeded device name + service flags
docker-compose.yml          # Full stack: renderer + init-fifo + snapserver
build.sh / push.sh          # Build / push helpers
```

## Configuration

### Environment variables

| Var         | Default       | Description                                  |
|-------------|---------------|----------------------------------------------|
| `UPNP_NAME` | `mr-do UPnP`  | Friendly name shown in UPnP controller apps  |
| `TZ`        | `UTC`         | Timezone (e.g. `Europe/Berlin`)              |

### Ports

| Port      | Protocol | Purpose                                              |
|-----------|----------|------------------------------------------------------|
| `49494`   | TCP      | UPnP HTTP control — device description + SOAP actions |
| `1900`    | UDP      | SSDP discovery (multicast 239.255.255.250)            |

`hostNetwork: true` (K8s) or `network_mode: host` (Docker) is required —
SSDP multicast cannot traverse Docker bridge NAT or MetalLB L2.

### Volumes / mounts

| Path                 | Type        | Why                                                |
|----------------------|-------------|----------------------------------------------------|
| `/etc/asound.conf`   | ConfigMap / file (ro) | ALSA routing to FIFO — see `etc/asound.conf` |
| `/tmp/music`         | shared dir  | Contains the FIFO pipe, shared with snapserver     |
| `/tmp/music/upnpfifo`| named pipe  | The bridge: Kodi writes PCM → snapserver reads     |
| `/tmp`               | emptyDir    | Writable: Xvfb sockets, Kodi `$HOME` (`/tmp/kodi-home`) |

### User

Runs as **UID/GID 1000** (non-root). The `tmp` volume must be writable
by UID 1000.

### Audio format

Kodi PAPlayer outputs stereo PCM. The ALSA `asound.conf` rate-converts
and writes raw `S16_LE` at `48000 Hz` to the FIFO. Snapserver must read
the same format:

```
sampleformat = 48000:16:2    # 48000 Hz, 16-bit, stereo
codec = flac                 # snapserver encodes for network transport
```

If you change the sample rate in `asound.conf`, update `snapserver.conf`
to match.

### Build arguments

| Arg              | Default       | Description                          |
|------------------|---------------|--------------------------------------|
| `KODI_VERSION`   | `21.3-Omega`  | xbmc/xbmc git tag to build from      |

## Design decisions

- **Kodi from source** (not gmediarender): Kodi's UPnP stack (Platinum)
  has the broadest device compatibility. The previous gmediarender image
  had renderer discovery issues.
- **Xvfb**: Kodi has no headless windowing backend. We run it inside a
  virtual X framebuffer. GL falls back to `llvmpipe` (software rasterizer).
- **ALSA-only build**: PulseAudio/PipeWire dev headers are excluded at
  compile time so Kodi can't accidentally route audio to a pulse daemon
  instead of the FIFO pipe.
- **Non-root**: Runs as UID/GID 1000. `$HOME` is `/tmp/kodi-home` (the
  `tmp` emptyDir in K8s is always writable).
- **Skin kept**: `skin.estuary` stays because Kodi crashes during addon
  initialization without it, even headless.

## Credits

- [Kodi / XBMC](https://github.com/xbmc/xbmc) — Team Kodi
- [Snapcast](https://github.com/badaix/snapcast) — badaix
