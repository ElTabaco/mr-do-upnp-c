#include "RendererDevice.hpp"
#include <cstdlib>
#include <iostream>

static int envOrDefault(const char* name, int def) {
    const char* v = std::getenv(name);
    return v ? std::atoi(v) : def;
}

int main() {
    const int httpPort   = envOrDefault("RENDERER_PORT", 5000);
    const int ssdpPort   = envOrDefault("DISCOVERY_PORT", 1900);

    try {
        RendererDevice renderer(httpPort, ssdpPort);
        renderer.run();
    } catch (const std::exception& ex) {
        std::cerr << "FATAL: " << ex.what() << "\n";
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
