#include "RendererDevice.hpp"
#include <iostream>
#include <thread>
#include <chrono>

RendererDevice::RendererDevice(int httpPort, int /*ssdpPort*/) {
    if (UpnpInit2(nullptr, httpPort) != UPNP_E_SUCCESS) {
        throw std::runtime_error("UpnpInit2 failed");
    }

    // Alpine uses libupnp < 1.14, so no UpnpSetSsdpPort
    // Discovery must use default port: 1900/udp

    const char* descUrl = "http://www.example.com/renderer/description.xml";
    if (UpnpRegisterRootDevice2(UPNPREG_URL_DESC, descUrl,
                                &RendererDevice::callback,
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
    while (true) {
        std::this_thread::sleep_for(std::chrono::seconds(60));
    }
}

int RendererDevice::callback(Upnp_EventType evt, void* /*event*/, void* cookie) {
    auto* self = static_cast<RendererDevice*>(cookie);
    (void)self;
    std::cout << "UPnP event received: " << evt << "\n";
    return 0;
}
