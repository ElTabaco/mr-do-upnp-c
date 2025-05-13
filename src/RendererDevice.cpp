#include "RendererDevice.hpp"
#include <iostream>
#include <thread>
#include <chrono>
#include <cstring>
#include <stdexcept>

RendererDevice::RendererDevice(int httpPort, int /*ssdpPort*/) {
    // Initialize UPnP stack with given HTTP port
    if (UpnpInit2(nullptr, httpPort) != UPNP_E_SUCCESS) {
        throw std::runtime_error("UpnpInit2 failed");
    }

    // Minimal static device description (MediaRenderer with UUID)
    const char* desc = R"(
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>Alpine Renderer</friendlyName>
    <manufacturer>Test</manufacturer>
    <modelName>UPnP-Renderer</modelName>
    <UDN>uuid:12345678-1234-5678-1234-567812345678</UDN>
  </device>
</root>
    )";

    // Register the static XML buffer as the device description
    if (UpnpRegisterRootDevice2(
            UPNPREG_BUF_DESC,
            desc,
            std::strlen(desc),
            0,
            &RendererDevice::callback,
            this,
            &m_deviceHandle) != UPNP_E_SUCCESS)
    {
        throw std::runtime_error("UpnpRegisterRootDevice2 failed");
    }

    // Send SSDP advertisements
    if (UpnpSendAdvertisement(m_deviceHandle, 1800) != UPNP_E_SUCCESS) {
        throw std::runtime_error("Failed to send initial SSDP advertisement");
    }

    std::cout << "UPnP device registered on HTTP port " << httpPort << std::endl;
}

RendererDevice::~RendererDevice() {
    if (m_deviceHandle >= 0) {
        UpnpUnRegisterRootDevice(m_deviceHandle);
    }
    UpnpFinish();
