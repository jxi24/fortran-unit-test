cmake_minimum_required(VERSION 3.14)   # CPM uses FetchContent, which needs 3.14
project(FutConsumerExample LANGUAGES Fortran CXX)

# ---------------------------------------------------------------------------
# CPM bootstrap
#   cmake/CPM.cmake downloads the real CPM.cmake into the build directory on
#   first configure, then caches it there for offline use.
#   Set CPM_SOURCE_CACHE to share the package download cache across projects:
#     export CPM_SOURCE_CACHE=$HOME/.cache/CPM
# ---------------------------------------------------------------------------
include(cmake/CPM.cmake)

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

# Fortran Unit Test library — the feature branch that includes the C/C++ bridge
CPMAddPackage(
  NAME           FortranUnitTest
  GITHUB_REPOSITORY jxi24/fortran-unit-test
  GIT_TAG        feature/cppinterface
)
# After this call the following are available:
#   target: fortran_unit_test   (link to get the library + include paths)
#   headers: fut_c_api.h and fut_catch2.hpp propagated via PUBLIC include dirs

# Catch2 v3 — C++ test driver with automatic CTest discovery
CPMAddPackage(
  NAME           Catch2
  GITHUB_REPOSITORY catchorg/Catch2
  VERSION        3.7.1
  OPTIONS
    "CATCH_INSTALL_DOCS OFF"
    "CATCH_INSTALL_EXTRAS OFF"
)

# ---------------------------------------------------------------------------
# Library under test
#   A small Fortran physics library with bind(C) exports so C++ can call it
#   directly.  In a real project this would be your existing Fortran library.
# ---------------------------------------------------------------------------
add_library(physics STATIC src/simple_physics.F90)

# ---------------------------------------------------------------------------
# Single test executable
#   All TEST_CASEs live in one binary.  Two CTest registration strategies are
#   provided below — pick the one that suits your workflow.
# ---------------------------------------------------------------------------
enable_testing()
include(CTest)

add_executable(physics_tests
  tests/test_suite.cpp     # 3-line Catch2 driver: include + extern "C" + FUT_AUTO_DISCOVER_TESTS
  tests/physics_tests.F90  # Fortran test suites using native FUT assertions + fut_register_test
)

# Require C++14 (minimum for Catch2 v3)
target_compile_features(physics_tests PRIVATE cxx_std_14)

# Allow long Fortran lines in physics_tests.F90 (assert calls with file/line
# macros can exceed the default 132-character limit on GNU Fortran).
if(CMAKE_Fortran_COMPILER_ID STREQUAL "GNU")
    target_compile_options(physics_tests PRIVATE
        $<$<COMPILE_LANGUAGE:Fortran>:-ffree-line-length-none>)
endif()

# fortran_unit_test propagates include/ (fut_c_api.h, fut_catch2.hpp) via its
# PUBLIC target_include_directories, so no explicit include_directories needed.
target_link_libraries(physics_tests PRIVATE
  physics               # Fortran library under test
  fortran_unit_test     # FUT assertion engine + C/C++ headers
  Catch2::Catch2WithMain
)

# ---------------------------------------------------------------------------
# CTest registration — choose ONE of the two options below.
# ---------------------------------------------------------------------------

# Option A ─ Single CTest entry ─────────────────────────────────────────────
#   The whole binary is one CTest test.  `ctest` passes if physics_tests
#   exits 0 (i.e. Catch2 reports no failures).  Simple, low overhead.
#
#   Run:  ctest --test-dir build -V
#         ctest --test-dir build --output-on-failure
# ---------------------------------------------------------------------------
add_test(NAME PhysicsTestSuite COMMAND physics_tests)

# ---------------------------------------------------------------------------
# Option B ─ Per-TEST_CASE CTest entries (uncomment to use instead of A) ────
#   catch_discover_tests() queries the binary at build time and registers
#   every Catch2 TEST_CASE as a separate CTest entry (prefix "Physics::").
#   This gives `ctest -R "Physics::[energy]"` tag filtering for free.
#
#   Run:  ctest --test-dir build -V
#         ctest --test-dir build -R "Physics::"
#         ctest --test-dir build -R "\[collision\]"
# ---------------------------------------------------------------------------
# include(Catch)
# catch_discover_tests(physics_tests
#   TEST_PREFIX    "Physics::"
#   REPORTER       console
#   OUTPUT_DIR     ${CMAKE_CURRENT_BINARY_DIR}
#   OUTPUT_SUFFIX  .xml)
