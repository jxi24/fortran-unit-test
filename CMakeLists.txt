cmake_minimum_required(VERSION 3.5)

set(CMAKE_MACOSX_RPATH ON)

# CXX is required for the Catch2 bridge; Fortran remains the primary language.
project(FortranUnitTest LANGUAGES Fortran CXX)

set(version 0.0.1)

# ---------------------------------------------------------------------------
# Compiler flags
# ---------------------------------------------------------------------------
if (CMAKE_Fortran_COMPILER_ID STREQUAL "GNU")
  set(CMAKE_Fortran_FLAGS "-ffree-line-length-none")
elseif (CMAKE_Fortran_COMPILER_ID STREQUAL "PGI")
endif ()

set(CMAKE_Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR})

# ---------------------------------------------------------------------------
# Core Fortran library — includes the ISO C Binding wrapper module so that
# C and C++ callers can drive FUT without touching any Fortran types.
# ---------------------------------------------------------------------------
set(sources
  src/assert_mod.F90
  src/test_common_mod.F90
  src/test_case_mod.F90
  src/test_suite_mod.F90
  src/fut_test_registry_mod.F90
  src/unit_test.F90
  src/fut_c_api.F90
)

get_directory_property(has_parent PARENT_DIRECTORY)

if (has_parent)
  include_directories(${CMAKE_BINARY_DIR})
endif ()

add_library(fortran_unit_test SHARED ${sources})
set_property(TARGET fortran_unit_test PROPERTY VERSION ${version})
set_property(TARGET fortran_unit_test PROPERTY SOVERSION 1)
set_property(TARGET fortran_unit_test PROPERTY Fortran_MODULE_DIRECTORY
    "${CMAKE_CURRENT_BINARY_DIR}/modules")

# Fortran .mod files (for Fortran consumers) + C/C++ headers (for C++ bridge).
target_include_directories(fortran_unit_test
    PUBLIC
        $<INSTALL_INTERFACE:include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)

# ---------------------------------------------------------------------------
# Testing (standalone build only)
# ---------------------------------------------------------------------------
if (NOT has_parent)

  enable_testing()
  include(CTest)

  # --- Fortran integration test (always built) ---
  add_executable(assert_test.exe src/assert_test.F90)
  target_link_libraries(assert_test.exe fortran_unit_test)

  # Register with CTest so `ctest` discovers and runs it automatically.
  add_test(NAME FortranIntegrationTest COMMAND assert_test.exe)

  # --- C++ / Catch2 tests (built only when Catch2 v3 is available) ---
  #
  # Install Catch2 via your system package manager or vcpkg, e.g.:
  #   Ubuntu/Debian : apt install catch2            (may be v2; prefer v3)
  #   vcpkg         : vcpkg install catch2
  #   Homebrew      : brew install catch2
  #   From source   : cmake --install <catch2-build>
  #
  find_package(Catch2 3 CONFIG QUIET)

  if (Catch2_FOUND)
    message(STATUS "Catch2 v3 found — building C++/Fortran cross-language tests")

    add_executable(fut_catch2_test
        tests/test_fortran_suite.cpp
        tests/fortran_native_tests.F90)

    target_include_directories(fut_catch2_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/include)

    target_link_libraries(fut_catch2_test PRIVATE
        fortran_unit_test
        Catch2::Catch2WithMain)

    # Set C++14 as minimum (Catch2 v3 requires C++14).
    target_compile_features(fut_catch2_test PRIVATE cxx_std_14)

    # catch_discover_tests() queries the test binary at build time and
    # registers every Catch2 TEST_CASE as a separate CTest entry.
    # This gives `ctest -R "[fortran]"` style filtering for free.
    include(Catch)
    catch_discover_tests(fut_catch2_test
        TEST_PREFIX    "Catch2::"
        REPORTER       console
        OUTPUT_DIR     ${CMAKE_CURRENT_BINARY_DIR}
        OUTPUT_SUFFIX  .xml)

  else ()
    message(STATUS "Catch2 v3 not found — skipping C++/Fortran Catch2 tests. "
                   "Install Catch2 v3 and re-run cmake to enable them.")
  endif ()

endif ()

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
install(TARGETS fortran_unit_test EXPORT FortranUnitTestTargets
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
)

# Install the C/C++ bridge headers.
install(DIRECTORY include/
    DESTINATION include/fortran_unit_test
    FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp")

include(CMakePackageConfigHelpers)
write_basic_package_version_file (
  "${CMAKE_CURRENT_BINARY_DIR}/FortranUnitTest/FortranUnitTestConfigVersion.cmake"
  VERSION ${version}
  COMPATIBILITY AnyNewerVersion
)

export(EXPORT FortranUnitTestTargets
  FILE "${CMAKE_CURRENT_BINARY_DIR}/FortranUnitTest/FortranUnitTestTargets.cmake"
)
configure_file(cmake/FortranUnitTestConfig.cmake.in
  "${CMAKE_CURRENT_BINARY_DIR}/FortranUnitTest/FortranUnitTestConfig.cmake"
)

set(ConfigPackageLocation lib/cmake/FortranUnitTest)
install(EXPORT FortranUnitTestTargets
  FILE FortranUnitTestTargets.cmake
  DESTINATION ${ConfigPackageLocation}
)
install(
  FILES
    "${CMAKE_CURRENT_BINARY_DIR}/FortranUnitTest/FortranUnitTestConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/FortranUnitTest/FortranUnitTestConfigVersion.cmake"
  DESTINATION
    ${ConfigPackageLocation}
)
