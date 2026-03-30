# cmake/CPM.cmake — thin bootstrap that downloads CPM on first configure.
#
# CPM (CMake Package Manager) wraps CMake's FetchContent with a cleaner API.
# The real CPM.cmake is cached in the build directory so subsequent configures
# are offline.  Set the CPM_SOURCE_CACHE environment variable to share the
# download cache across projects:
#   export CPM_SOURCE_CACHE=$HOME/.cache/CPM
#
# Reference: https://github.com/cpm-cmake/CPM.cmake

set(CPM_DOWNLOAD_VERSION 0.40.2)
set(CPM_DOWNLOAD_FILE
    "${CMAKE_BINARY_DIR}/cmake/CPM_${CPM_DOWNLOAD_VERSION}.cmake")

if(NOT EXISTS "${CPM_DOWNLOAD_FILE}")
  message(STATUS "Downloading CPM.cmake v${CPM_DOWNLOAD_VERSION}")
  file(DOWNLOAD
    "https://github.com/cpm-cmake/CPM.cmake/releases/download/v${CPM_DOWNLOAD_VERSION}/CPM.cmake"
    "${CPM_DOWNLOAD_FILE}"
  )
endif()

include("${CPM_DOWNLOAD_FILE}")
