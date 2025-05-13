#pragma once
#include <upnp/upnp.h>
#include <string>

class RendererDevice {
public:
    RendererDevice(int httpPort, int ssdpPort);
    ~RendererDevice();

    // Non‑copyable
    RendererDevice(const RendererDevice&) = delete;
    RendererDevice& operator=(const RendererDevice&) = delete;

    void run();          // Blocking event‑loop
private:
    static int callback(Upnp_EventType, void*, void*);
    int         m_deviceHandle{-1};
};
