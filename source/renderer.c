// renderer.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <upnp/upnp.h>

#define DEFAULT_PORT 49494

int device_handle = -1;

// Callback function to handle UPnP events
int upnp_callback(Upnp_EventType event_type, const void *event, void *cookie) {
    switch (event_type) {
        case UPNP_EVENT_SUBSCRIPTION_REQUEST:
            printf("Subscription request received.\n");
            break;
        case UPNP_EVENT_AUTORENEWAL_FAILED:
            printf("Auto-renewal failed.\n");
            break;
        case UPNP_EVENT_SUBSCRIPTION_EXPIRED:
            printf("Subscription expired.\n");
            break;
        default:
            printf("Unhandled event: %d\n", event_type);
            break;
    }
    return UPNP_E_SUCCESS;
}

int start_upnp_renderer(int port) {
    int ret;

    // Initialize UPnP library
    ret = UpnpInit(NULL, port);
    if (ret != UPNP_E_SUCCESS) {
        printf("Error initializing UPnP library: %d\n", ret);
        return ret;
    }
    printf("UPnP Initialized on port %d\n", port);

    // Create a root device description
    ret = UpnpRegisterRootDevice("http://yourdeviceip:port/desc.xml", upnp_callback, NULL, &device_handle);
    if (ret != UPNP_E_SUCCESS) {
        printf("Error registering root device: %d\n", ret);
        UpnpFinish();
        return ret;
    }

    // Advertise the device on the network
    ret = UpnpSendAdvertisement(device_handle, 180);
    if (ret != UPNP_E_SUCCESS) {
        printf("Error sending advertisement: %d\n", ret);
        UpnpFinish();
        return ret;
    }

    printf("Device advertised successfully.\n");

    // Main loop to process events
    while (1) {
        UpnpProcess();
        sleep(1);
    }

    // Cleanup
    UpnpUnRegisterRootDevice(device_handle);
    UpnpFinish();
    return 0;
}

int main(int argc, char *argv[]) {
    int port = DEFAULT_PORT;
    if (argc > 1) {
        port = atoi(argv[1]);
    }

    printf("Starting UPnP Renderer on port %d...\n", port);
    return start_upnp_renderer(port);
}
