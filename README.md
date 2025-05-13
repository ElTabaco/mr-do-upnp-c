# Accessing the DLNA Server and TCP Stream

    Access the DLNA server using a DLNA client on your network at 
    http://<docker-host-ip>:8200
    Listen to the audio stream by connecting to the TCP stream on port 12345. Use tools like nc (Netcat) or a media player that supports streaming from TCP.

For example, using nc to play the stream:

```console
nc <docker-host-ip> 12345 | ffplay -f mp3 -
```
Or using VLC media player, open a network stream and input tcp://<docker-host-ip>:12345.

enter container

```console
docker run --rm -it -p 8200:8200 -p 12345:12345 --entrypoint sh riemerk/mr-do-upnp:latest

docker run (or equivalent) can you try adding the --device /dev/snd --device /dev/bus/usb flags? 
```

## Test local and on an other machine

```console
curl http://localhost:8200 | grep "MiniDLNA status"
nc -zv localhost 12345
```

## UPnP / dlna

### ARM64

[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-upnp-c/latest?arch=arm64)](https://hub.docker.com/r/riemerk/mr-do-upnp-c)

### ARM32

[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-upnp/latest?arch=arm)](https://hub.docker.com/r/riemerk/mr-do-upnp)

### AMD64

[![docker image size](https://img.shields.io/docker/image-size/riemerk/mr-do-upnp/latest?arch=amd64)](https://hub.docker.com/r/riemerk/mr-do-upnp)

### Docker pulls

[![docker pulls](https://img.shields.io/docker/pulls/riemerk/mr-do-upnp)](https://hub.docker.com/r/riemerk/mr-do-upnp)

[![docker pulls](https://img.shields.io/docker/pulls/riemerk/mr-do-upnp-c)](https://hub.docker.com/r/riemerk/mr-do-upnp-c)



A complete, opinion‑ated recipe for turning Kodi ( formerly XBMC ) into a head‑less, audio‑only UPnP / DLNA renderer that you can drop into any network as a Docker container.
Everything is built on Alpine Linux, and the image is only ~120 MiB even with the essential audio codecs.
1. Directory layout of the project repo

```console
xbmc-upnp-audio/
├── docker/
│   ├── Dockerfile            # multi‑stage build (Alpine → Alpine)
│   └── entrypoint.sh         # tiny wrapper for Kodi head‑less mode
├── patches/                  # optional – tweak Kodi at build‑time
│   └── 01-strip-video.diff
├── settings/
│   └── advancedsettings.xml  # force Kodi into audio‑only + UPnP renderer
└── README.md                 # build / run instructions
```

    Why keep everything in one repo?
    The Docker context stays tiny, CI/CD hooks are simple, and you can version your configuration patches alongside the build.