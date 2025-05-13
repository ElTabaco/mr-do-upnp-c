#include "RendererDevice.hpp"
#include <iostream>
#include <thread>
#include <chrono>
#include <stdexcept>

RendererDevice::RendererDevice(int httpPort, int /*ssdpPort*/) {
    // Initialize UPnP stack
    if (UpnpInit2(nullptr, httpPort) != UPNP_E_SUCCESS) {
        throw std::runtime_error("UpnpInit2 failed");
    }

    // Static (minimal) device description
    const char* desc =
        "<?xml version=\"1.0\"?>"
        "<root xmlns=\"urn:schemas-upnp-org:device-1-0\">"
        "  <specVersion><major>1</major><minor>0</minor></specVersion>"
        "  <device>"
        "    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>"
        "    <friendlyName>Alpine Renderer</friendlyName>"
        "    <manufacturer>Test</manufacturer>"
        "    <modelName>UPnP-Renderer</modelName>"
        "    <UDN>uuid:12345678-1234-5678-1234-567812345678</UDN>"
        "  </device>"
        "</root>";

    if (UpnpRegisterRootDevice2(UPNPREG_BUF_DESC, desc,
                                (Upnp_FunPtr)&RendererDevice::callback,
                                this, &m_deviceHandle) != UPNP_E_SUCCESS) {
        throw std::runtime_error("UpnpRegisterRootDevice2 failed");
    }

    // Send initial advertisement
    if (UpnpSendAdvertisement(m_deviceHandle, 1800) != UPNP_E_SUCCESS) {
        throw std::runtime_error("Failed to send initial SSDP advert");
    }
}

RendererDevice::~RendererDevice() {
    if (m_deviceHandle >= 0) {
        UpnpUnRegisterRootDevice(m_deviceHandle);
    }
    UpnpFinish();
}

void RendererDevice::run() {
    std::cout << "UPnP renderer running… <Ctrl‑C> to stop\n";
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
