cmake_minimum_required(VERSION 3.16)

project(OilSpillProject VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.10 REQUIRED COMPONENTS
    Quick
    Concurrent
)

qt_standard_project_setup(REQUIRES 6.10)

if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

qt_add_executable(appOilSpillProject
    main.cpp
)

qt_add_qml_module(appOilSpillProject
    URI OilSpillProject
    QML_FILES
        Main.qml
    SOURCES
        copernicusmanager.h
        copernicusmanager.cpp
        OceanData.h
        surfacecurrentparser.h
        surfacecurrentparser.cpp
        currentfield.h
        currentfield.cpp
        oilsimulation.h
        oilsimulation.cpp
        oceanparsers.h
        oceanparsers.cpp
        copernicusmanager_underwater.cpp
        underwaterfield.h
        underwaterfield.cpp
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you develop for iOS or macOS, consider setting an explicit bundle identifier.
set_target_properties(appOilSpillProject PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING
        ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appOilSpillProject
    PRIVATE
        Qt6::Quick
        Qt6::Concurrent
)


add_custom_command(TARGET appOilSpillProject POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/copernicusmarine.exe"
        "$<TARGET_FILE_DIR:appOilSpillProject>"

    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/credentials.txt"
        "$<TARGET_FILE_DIR:appOilSpillProject>"
)

include(GNUInstallDirs)

install(TARGETS appOilSpillProject
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)