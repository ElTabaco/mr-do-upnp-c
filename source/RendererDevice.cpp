#include "RendererDevice.hpp"
#include <iostream>

RendererDevice::RendererDevice(int httpPort, int ssdpPort) {
    // Initialise libupnp. 0.0.0.0 = all interfaces
    if (UpnpInit2(nullptr, httpPort) != UPNP_E_SUCCESS) {
        throw std::runtime_error("UpnpInit2 failed");
    }
    UpnpSetMaxContentLength(256 * 1024);      // 256 kB body limit
    UpnpSetSsdpPort(ssdpPort);                // override default 1900/udp

    // Register a very small “renderer” (one AVTransport service stub)
    const char* descUrl = "http://www.example.com/renderer/description.xml";
    if (UpnpRegisterRootDevice2(UPNPREG_BUF_DESC, descUrl,
                                UpnpDevice_Callback_Func(&RendererDevice::callback),
                                this, &m_deviceHandle) != UPNP_E_SUCCESS) {
        throw std::runtime_error("UpnpRegisterRootDevice2 failed");
    }

    if (UpnpSendAdvertisement(m_deviceHandle, 1800) != UPNP_E_SUCCESS) {
        throw std::runtime_error("Failed to send initial SSDP advert");
    }
}

RendererDevice::~RendererDevice() {
    if (m_deviceHandle >= 0) UpnpUnRegisterRootDevice(m_deviceHandle);
    UpnpFinish();
}

void RendererDevice::run() {
    std::cout << "UPnP renderer running…  <Ctrl‑C> to stop\n";
    // Simple blocking loop
    while (true) {
        std::this_thread::sleep_for(std::chrono::seconds(60));
    }
}

int RendererDevice::callback(Upnp_EventType evt, void* /*event*/, void* cookie) {
    auto* self = static_cast<RendererDevice*>(cookie);
    (void)self;  // unused for now
    std::cout << "UPnP event received: " << evt << "\n";
    return 0;
}
