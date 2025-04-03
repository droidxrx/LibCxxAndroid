cmake_minimum_required(VERSION 3.18)

project(c++ DESCRIPTION "Custom lib++ combine libc++-abi without exception and RTTI for Android." LANGUAGES CXX)

set(LIBC++_TARGET_NAME "${PROJECT_NAME}_static")

option(IS_ROOT_PROJECT "" ON)
option(ENABLE_BUILD_WITH_NO_RTTI "" ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(ANDROID_ABIS "armeabi-v7a" "arm64-v8a" "x86" "x86_64" CACHE STRING "List of Android ABIs to build for")
set(LIBC++_COMPILE_OPTIONS -fno-exceptions -fvisibility-global-new-delete-hidden -fvisibility=hidden -fvisibility-inlines-hidden)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

if(NOT IS_ROOT_PROJECT)
    file(GLOB_RECURSE libc++_source ${SRC_DIR}/*.cpp)
    file(GLOB_RECURSE libc++abi_source ${SRC_DIR}/libcxxabi/*.cpp)

    add_library(${PROJECT_NAME} STATIC ${libc++_source})
    list(REMOVE_ITEM libc++_source ${libc++abi_source})

    if(ENABLE_BUILD_WITH_NO_RTTI)
        set_source_files_properties(${libc++_source} PROPERTIES COMPILE_OPTIONS -fno-rtti)
    endif()

    target_include_directories(${PROJECT_NAME} PRIVATE ${SRC_DIR}/../include ${SRC_DIR} ${SRC_DIR}/filesystem)
    target_compile_options(${PROJECT_NAME} PUBLIC ${LIBC++_COMPILE_OPTIONS})
    target_compile_options(${PROJECT_NAME} PRIVATE "-g0")

    target_compile_definitions(${PROJECT_NAME} PUBLIC
        _LIBCPP_BUILDING_LIBRARY
        _LIBCPP_DISABLE_NEW_DELETE_DEFINITIONS
        __STDC_FORMAT_MACROS
        ANDROID
        LIBCXX_BUILDING_LIBCXXABI
        _LIBCPP_DISABLE_EXTERN_TEMPLATE
        _LIBCXXABI_BUILDING_LIBRARY
        _LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS
    )

    set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "${LIBC++_TARGET_NAME}")

    if(ENABLE_BUILD_WITH_NO_RTTI)
        install(TARGETS ${PROJECT_NAME} ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}/${ANDROID_ABI}-no-rtti")
    else()
        install(TARGETS ${PROJECT_NAME} ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}/${ANDROID_ABI}")
    endif()

    return()
endif()

include(ExternalProject)

set(EXTERNAL_PROJECTS)

foreach(ABI ${ANDROID_ABIS})
    list(APPEND EXTERNAL_PROJECTS "${PROJECT_NAME}_${ABI}" "${PROJECT_NAME}_${ABI}_no_rtti")
    ExternalProject_Add("${PROJECT_NAME}_${ABI}"
        PREFIX "${CMAKE_BINARY_DIR}/${ABI}"
        SOURCE_DIR "${PROJECT_SOURCE_DIR}"
        CMAKE_ARGS
        --fresh
        -DIS_ROOT_PROJECT=OFF
        -DENABLE_BUILD_WITH_NO_RTTI=OFF
        -DANDROID_ABI=${ABI}
        -DANDROID_PLATFORM=${ANDROID_PLATFORM}
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
        -DANDROID_STL=none
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_C_COMPILER_LAUNCHER=/usr/bin/ccache
        -DCMAKE_CXX_COMPILER_LAUNCHER=/usr/bin/ccache
        -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
        -DSRC_DIR=${PROJECT_SOURCE_DIR}/src
    )
    ExternalProject_Add("${PROJECT_NAME}_${ABI}_no_rtti"
        PREFIX "${CMAKE_BINARY_DIR}/${ABI}_no_rtti"
        SOURCE_DIR "${PROJECT_SOURCE_DIR}"
        CMAKE_ARGS
        --fresh
        -DIS_ROOT_PROJECT=OFF
        -DENABLE_BUILD_WITH_NO_RTTI=ON
        -DANDROID_ABI=${ABI}
        -DANDROID_PLATFORM=${ANDROID_PLATFORM}
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
        -DANDROID_STL=none
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_C_COMPILER_LAUNCHER=/usr/bin/ccache
        -DCMAKE_CXX_COMPILER_LAUNCHER=/usr/bin/ccache
        -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
        -DSRC_DIR=${PROJECT_SOURCE_DIR}/src
    )
endforeach()

set(LIBC++_CONFIG_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}" CACHE INTERNAL "")
set(LIBC++_INCLUDE_INSTALL_DIR "${CMAKE_INSTALL_INCLUDEDIR}")
set(LIBC++_LIB_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}")
set(LIBC++_TARGETS_EXPORT_NAME "${PROJECT_NAME}Targets")
set(LIBC++_CMAKE_CONFIG_TEMPLATE "${PROJECT_SOURCE_DIR}/cmake/config.cmake.in")
set(LIBC++_CMAKE_TARGET_TEMPLATE "${PROJECT_SOURCE_DIR}/cmake/target-static.cmake.in")
set(LIBC++_CMAKE_TARGET_TEMPLATE_NO_RTTI "${PROJECT_SOURCE_DIR}/cmake/target-static_no_rtti.cmake.in")
set(LIBC++_CMAKE_CONFIG_DIR "${CMAKE_CURRENT_BINARY_DIR}")
set(LIBC++_CMAKE_PROJECT_CONFIG_FILE "${LIBC++_CMAKE_CONFIG_DIR}/${PROJECT_NAME}Config.cmake")
set(LIBC++_CMAKE_PROJECT_TARGETS_FILE "${LIBC++_CMAKE_CONFIG_DIR}/${LIBC++_TARGETS_EXPORT_NAME}.cmake")
set(LIBC++_CMAKE_PROJECT_TARGETS_ANDROID_ABI_FILE "${LIBC++_CMAKE_CONFIG_DIR}/${LIBC++_TARGETS_EXPORT_NAME}-static.cmake")
set(LIBC++_CMAKE_PROJECT_TARGETS_ANDROID_ABI_FILE_NO_RTTI "${LIBC++_CMAKE_CONFIG_DIR}/${LIBC++_TARGETS_EXPORT_NAME}-static_no_rtti.cmake")
set(LIBC++_INCLUDE_BUILD_DIR "${PROJECT_SOURCE_DIR}/include/")

add_library(static INTERFACE)
add_library(static_no_rtti INTERFACE)
target_compile_options(static INTERFACE ${LIBC++_COMPILE_OPTIONS})
target_compile_options(static_no_rtti INTERFACE ${LIBC++_COMPILE_OPTIONS} -fno-rtti)
target_include_directories(static INTERFACE $<INSTALL_INTERFACE:${LIBC++_INCLUDE_INSTALL_DIR}>)
target_include_directories(static_no_rtti INTERFACE $<INSTALL_INTERFACE:${LIBC++_INCLUDE_INSTALL_DIR}>)
add_dependencies(static ${EXTERNAL_PROJECTS})
add_dependencies(static_no_rtti static)

# Generate config files
configure_package_config_file(${LIBC++_CMAKE_CONFIG_TEMPLATE} ${LIBC++_CMAKE_PROJECT_CONFIG_FILE}
    INSTALL_DESTINATION ${LIBC++_CMAKE_CONFIG_DIR}
)

configure_file(${LIBC++_CMAKE_TARGET_TEMPLATE} ${LIBC++_CMAKE_PROJECT_TARGETS_ANDROID_ABI_FILE}
    @ONLY NEWLINE_STYLE LF
)

configure_file(${LIBC++_CMAKE_TARGET_TEMPLATE_NO_RTTI} ${LIBC++_CMAKE_PROJECT_TARGETS_ANDROID_ABI_FILE_NO_RTTI}
    @ONLY NEWLINE_STYLE LF
)

# Install config file
install(
    FILES ${LIBC++_CMAKE_PROJECT_CONFIG_FILE} ${LIBC++_CMAKE_PROJECT_TARGETS_ANDROID_ABI_FILE} ${LIBC++_CMAKE_PROJECT_TARGETS_ANDROID_ABI_FILE_NO_RTTI}
    DESTINATION ${LIBC++_CONFIG_INSTALL_DIR}
)

# Install include headers
install(
    DIRECTORY ${LIBC++_INCLUDE_BUILD_DIR}
    DESTINATION ${LIBC++_INCLUDE_INSTALL_DIR}
)

install(
    TARGETS static static_no_rtti
    EXPORT ${LIBC++_TARGETS_EXPORT_NAME}
)

install(
    EXPORT ${LIBC++_TARGETS_EXPORT_NAME}
    DESTINATION ${LIBC++_CONFIG_INSTALL_DIR}
    NAMESPACE ${PROJECT_NAME}::
)