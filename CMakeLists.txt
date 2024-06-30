cmake_minimum_required(VERSION 3.13.4)

project(libcxx DESCRIPTION "Custom libcxx without exception and RTTI for Android." LANGUAGES CXX)

option(IS_ROOT_PROJECT "" ON)
option(LIBCXX_REBUILD ON)

set(CMAKE_CXX_STANDARD 20)
set(CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(_COMPILE_OPTIONS -fno-exceptions -fvisibility-global-new-delete-hidden -fvisibility=hidden -fvisibility-inlines-hidden)

macro(build_for_abi ABI SRC_DIR)
    set(BUILD_DIR ${CMAKE_CURRENT_BINARY_DIR}/${ABI})

    file(REMOVE_RECURSE ${BUILD_DIR})
    file(MAKE_DIRECTORY ${BUILD_DIR})

    execute_process(
        COMMAND ${CMAKE_COMMAND}
        -H${CMAKE_SOURCE_DIR}
        -B${BUILD_DIR}
        -GNinja
        -DCMAKE_TOOLCHAIN_FILE=/opt/NDK/25.0.8775105/build/cmake/android.toolchain.cmake
        -DIS_ROOT_PROJECT=OFF
        -DSRC_DIR=${SRC_DIR}
        -DANDROID_ABI=${ABI}
        -DANDROID_PLATFORM=24
        -DANDROID_STL=none
        -DCMAKE_BUILD_TYPE=Release
    )

    execute_process(COMMAND ${CMAKE_COMMAND} --build ${BUILD_DIR})
endmacro()

if(NOT IS_ROOT_PROJECT)
    file(GLOB_RECURSE libcxx_source ${SRC_DIR}/*.cpp)
    file(GLOB_RECURSE libcxxabi_source ${SRC_DIR}/libcxxabi/*.cpp)

    add_library(${PROJECT_NAME} STATIC ${libcxx_source})

    list(REMOVE_ITEM libcxx_source ${libcxxabi_source})
    set_source_files_properties(${libcxx_source} PROPERTIES COMPILE_OPTIONS -fno-rtti)

    target_include_directories(${PROJECT_NAME} PRIVATE ${SRC_DIR}/../include)
    target_include_directories(${PROJECT_NAME} PRIVATE ${SRC_DIR} ${SRC_DIR}/filesystem)

    target_compile_options(${PROJECT_NAME} PRIVATE ${_COMPILE_OPTIONS})

    target_compile_definitions(${PROJECT_NAME} PRIVATE
        _LIBCPP_BUILDING_LIBRARY
        _LIBCPP_DISABLE_NEW_DELETE_DEFINITIONS
        __STDC_FORMAT_MACROS
        ANDROID
        LIBCXX_BUILDING_LIBCXXABI
        _LIBCPP_DISABLE_EXTERN_TEMPLATE
        _LIBCXXABI_BUILDING_LIBRARY
        _LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS
    )

    set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "cxx-${ANDROID_ABI}")

    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_STRIP} --strip-debug $<TARGET_FILE:${PROJECT_NAME}>
    )
    return()
endif()

set(ANDROID_ABIS "armeabi-v7a" "arm64-v8a" "x86" "x86_64")

if(LIBCXX_REBUILD)
    foreach(ABI ${ANDROID_ABIS})
        build_for_abi(${ABI} ${CMAKE_CURRENT_SOURCE_DIR}/src)
    endforeach()
endif()

set(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_SOURCE_DIR}/dist)

include(GNUInstallDirs)

set(LIBCXX_TARGET_NAME                             LibCxxAndroid)
set(LIBCXX_CONFIG_INSTALL_DIR                      "${CMAKE_INSTALL_LIBDIR}/cmake/${LIBCXX_TARGET_NAME}" CACHE INTERNAL "")
set(LIBCXX_INCLUDE_INSTALL_DIR                     "${CMAKE_INSTALL_INCLUDEDIR}")
set(LIBCXX_LIB_INSTALL_DIR                         "${CMAKE_INSTALL_LIBDIR}")
set(LIBCXX_TARGETS_EXPORT_NAME                     "${LIBCXX_TARGET_NAME}Targets")
set(LIBCXX_CMAKE_CONFIG_TEMPLATE                   "cmake/config.cmake.in")
set(LIBCXX_CMAKE_TARGET_TEMPLATE                   "cmake/target.cmake.in")
set(LIBCXX_CMAKE_CONFIG_DIR                        "${CMAKE_CURRENT_BINARY_DIR}")
set(LIBCXX_CMAKE_PROJECT_CONFIG_FILE               "${LIBCXX_CMAKE_CONFIG_DIR}/${LIBCXX_TARGET_NAME}Config.cmake")
set(LIBCXX_CMAKE_PROJECT_TARGETS_FILE              "${LIBCXX_CMAKE_CONFIG_DIR}/${LIBCXX_TARGET_NAME}Targets.cmake")
set(LIBCXX_CMAKE_PROJECT_TARGETS_ANDROID_ABI_FILE  "${LIBCXX_CMAKE_CONFIG_DIR}/${LIBCXX_TARGET_NAME}Targets-Abi.cmake")
set(LIBCXX_INCLUDE_BUILD_DIR                       "${PROJECT_SOURCE_DIR}/include/")
set(LIBCXX_COMPILE_OPTIONS                         ${_COMPILE_OPTIONS} -fno-rtti)
set(LIBCXX_LIBRARY_BUILD)

foreach(ABI ${ANDROID_ABIS})
    list(APPEND LIBCXX_LIBRARY_BUILD "${CMAKE_CURRENT_BINARY_DIR}/${ABI}/libcxx-${ABI}.a")
endforeach()

add_library(${LIBCXX_TARGET_NAME} INTERFACE)
target_compile_options(${LIBCXX_TARGET_NAME} INTERFACE ${LIBCXX_COMPILE_OPTIONS})

target_include_directories(
    ${LIBCXX_TARGET_NAME} INTERFACE
    $<BUILD_INTERFACE:${LIBCXX_INCLUDE_BUILD_DIR}>
)

include(CMakePackageConfigHelpers)

configure_file(
    ${LIBCXX_CMAKE_CONFIG_TEMPLATE}
    ${LIBCXX_CMAKE_PROJECT_CONFIG_FILE}
    @ONLY
)

configure_file(
    ${LIBCXX_CMAKE_TARGET_TEMPLATE}
    ${LIBCXX_CMAKE_PROJECT_TARGETS_ANDROID_ABI_FILE}
    @ONLY
)

install(
    DIRECTORY ${LIBCXX_INCLUDE_BUILD_DIR}
    DESTINATION ${LIBCXX_INCLUDE_INSTALL_DIR}
)

install(
    FILES ${LIBCXX_CMAKE_PROJECT_TARGETS_ANDROID_ABI_FILE}
    DESTINATION ${LIBCXX_CONFIG_INSTALL_DIR}
)

install(
    FILES ${LIBCXX_CMAKE_CONFIG_TEMPLATE} ${LIBCXX_CMAKE_PROJECT_CONFIG_FILE}
    DESTINATION ${LIBCXX_CONFIG_INSTALL_DIR}
)

install(
    FILES ${LIBCXX_LIBRARY_BUILD}
    DESTINATION ${LIBCXX_LIB_INSTALL_DIR}
)

export(
    TARGETS ${LIBCXX_TARGET_NAME}
    FILE ${LIBCXX_CMAKE_PROJECT_TARGETS_FILE}
)

install(
    TARGETS ${LIBCXX_TARGET_NAME}
    EXPORT ${LIBCXX_TARGETS_EXPORT_NAME}
    INCLUDES DESTINATION ${LIBCXX_INCLUDE_INSTALL_DIR}
)

install(
    EXPORT ${LIBCXX_TARGETS_EXPORT_NAME}
    DESTINATION ${LIBCXX_CONFIG_INSTALL_DIR}
)

message(STATUS "${CMAKE_MINIMUM_REQUIRED_VERSION}")