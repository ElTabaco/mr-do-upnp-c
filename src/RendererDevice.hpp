#include <upnp/upnp.h>
#include <string>

class RendererDevice {
public:
    RendererDevice(int httpPort, int ssdpPort);
    ~RendererDevice();
    void run();

    RendererDevice(const RendererDevice&) = delete;
    RendererDevice& operator=(const RendererDevice&) = delete;

private:
    static int callback(Upnp_EventType, void*, void*);
    int m_deviceHandle{-1};
};
