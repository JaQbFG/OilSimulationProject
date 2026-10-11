cmake_minimum_required(VERSION 3.16)

project(OilSpillProject VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.10)

# Content of downloaded design from Figma to Qt or similar
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
        SOURCES copernicusmanager.h copernicusmanager.cpp
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appOilSpillProject PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appOilSpillProject
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appOilSpillProject
    PRIVATE Qt6::Quick
)
# Automatyczne kopiowanie copernicusmarine.exe oraz credentials.txt do folderu z wyjściowym .exe
add_custom_command(TARGET appOilSpillProject POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_CURRENT_SOURCE_DIR}/copernicusmarine.exe"
    $<TARGET_FILE_DIR:appOilSpillProject>
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_CURRENT_SOURCE_DIR}/credentials.txt"
    $<TARGET_FILE_DIR:appOilSpillProject>
)

install(TARGETS appOilSpillProject
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
