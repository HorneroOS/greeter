cmake_minimum_required(VERSION 3.21)
project(hornero-greetd-greeter VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.2 REQUIRED COMPONENTS Core Gui Network Qml Quick DBus)

# The speakable greetd protocol lives in its own library so the headless
# self-test binary (used by the protocol tests) links exactly the same
# client code as the fullscreen greeter.
add_library(greetd_client STATIC
    src/greetd_client.cpp
    src/session_model.cpp
    src/user_model.cpp
)
target_include_directories(greetd_client PUBLIC src)
target_link_libraries(greetd_client PUBLIC Qt6::Core Qt6::Network)

add_executable(hornero-greetd-greeter
    src/main.cpp
    src/backend.cpp
    src/power.cpp
    resources.qrc
)
target_link_libraries(hornero-greetd-greeter
    PRIVATE greetd_client Qt6::Gui Qt6::Qml Qt6::Quick Qt6::DBus)

add_executable(hornero-greetd-selftest
    src/selftest.cpp
)
target_link_libraries(hornero-greetd-selftest PRIVATE greetd_client)

install(TARGETS hornero-greetd-greeter RUNTIME DESTINATION bin)
install(FILES config/config.toml.example
              config/greetd-greeter.pam.example
        DESTINATION share/doc/hornero-greetd-greeter)
install(PROGRAMS config/hornero-greetd-session.example
        RENAME hornero-greetd-session
        DESTINATION share/doc/hornero-greetd-greeter)
