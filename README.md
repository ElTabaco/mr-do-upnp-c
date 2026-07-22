# mr-do-upnp-c

Kodi/XBMC v21 (Omega) headless UPnP/DLNA **MediaRenderer**, built from
[xbmc/xbmc](https://github.com/xbmc/xbmc) source.  Shows up as a cast
target in UPnP/DLNA controller apps (VLC, BubbleUPnP, AirMusic, Windows
"Play To", Kodi's "play using").

Audio is rendered server-side by Kodi's built-in PAPlayer and routed via
ALSA to a named pipe that a [Snapcast](https://github.com/badaix/snapcast)
snapserver reads for multi-room playback.

## Docker image

[![CI](https://github.com/ElTabaco/mr-do-upnp-c/actions/workflows/docker-image-upnp-c.yml/badge.svg)](https://github.com/ElTabaco/mr-do-upnp-c/actions)
[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-upnp-c/latest?arch=amd64)](https://hub.docker.com/r/riemerk/mr-do-upnp-c)
[![docker pulls](https://img.shields.io/docker/pulls/riemerk/mr-do-upnp-c)](https://hub.docker.com/r/riemerk/mr-do-upnp-c)

```
riemerk/mr-do-upnp-c:latest    # amd64, arm64
riemerk/mr-do-upnp-c:0.1.0
```

## How it works

```
UPnP controller app (VLC, BubbleUPnP, ...)
        │  SSDP discovery (1900/UDP multicast)
        ▼
┌─────────────────────────────────────────┐
│  Kodi v21 headless (this image)         │
│  ├─ Xvfb virtual framebuffer (:99)      │  Kodi has no headless backend
│  ├─ PAPlayer (audio only, no video)     │
│  └─ ALSA default → /etc/asound.conf     │
│         → writes /tmp/music/upnpfifo    │  named pipe (FIFO)
└─────────────────────────────────────────┘
        │
        ▼
   snapserver (reads the FIFO → broadcasts to snapclients)
```

The container is designed to run as a **sidecar** alongside snapserver in
the same pod (see [mr-do-player](https://github.com/ElTabaco/mr-do-player)
for the full K8s deployment).

## Build

Requires Docker with BuildKit.

```console
docker build -t riemerk/mr-do-upnp-c:latest -f docker/Dockerfile .
```

The Kodi compile (~1600 ninja targets) takes ~15 min on a 16-core machine.
The final multi-stage image is ~650 MB (runtime only, builder discarded).

## Run

Standalone (for testing — no snapserver, audio goes to `/dev/null`):

```console
docker run -d --network host \
  -e UPNP_NAME="Living Room" \
  riemerk/mr-do-upnp-c:latest
```

With snapserver (production — mount `asound.conf` that routes ALSA to the
shared FIFO):

```console
docker run -d --network host \
  -e UPNP_NAME="Living Room" \
  -v ./asound.conf:/etc/asound.conf:ro \
  -v /shared/fifo/dir:/tmp/music \
  riemerk/mr-do-upnp-c:latest
```

`--network host` is required: UPnP/SSDP uses UDP multicast (239.255.255.250)
which Docker bridge NAT cannot forward.

## Configuration

| Env var      | Default        | Description                          |
|--------------|----------------|--------------------------------------|
| `UPNP_NAME`  | `mr-do UPnP`   | Friendly name shown in controller apps |
| `TZ`         | `UTC`          | Timezone                             |

## Architecture notes

- **Xvfb**: Kodi has no headless windowing backend. We run it inside a
  virtual X framebuffer at `DISPLAY=:99`. The GL renderer falls back to
  `llvmpipe` (software rasterizer).
- **ALSA-only**: PulseAudio/PipeWire dev headers are excluded at build
  time so Kodi compiles with ALSA as the sole audio backend. This
  guarantees audio goes to the FIFO pipe, not a pulse daemon.
- **Non-root**: Runs as UID/GID 1000. `$HOME` is `/tmp/kodi-home` (always
  writable via the `tmp` emptyDir in K8s).
- **Skin**: `skin.estuary` is kept because Kodi crashes during addon
  initialization without it, even in headless mode.

## Credits

- [Kodi / XBMC](https://github.com/xbmc/xbmc) — Team Kodi
- [Snapcast](https://github.com/badaix/snapcast) — badaix
