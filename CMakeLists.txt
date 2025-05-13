cmake_minimum_required(VERSION 3.15)
project(upnp_renderer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBUPNP REQUIRED libupnp)

add_executable(upnp-renderer
        src/main.cpp
        src/RendererDevice.cpp
        src/RendererDevice.hpp)

target_include_directories(upnp-renderer PRIVATE ${LIBUPNP_INCLUDE_DIRS})
target_link_libraries(upnp-renderer PRIVATE ${LIBUPNP_LIBRARIES})
target_compile_definitions(upnp-renderer PRIVATE ${LIBUPNP_CFLAGS_OTHER})
