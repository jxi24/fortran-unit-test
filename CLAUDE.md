# CLAUDE.md — Fortran Unit Test Library (FUT)

This file documents the codebase structure, build workflows, and conventions for AI assistants working in this repository.

## Project Overview

FUT is a pure-Fortran unit testing library designed for scientific Fortran programmers. It has no external dependencies and provides assertion functions, test case management, and test suite management via a simple Fortran module interface.

A C/C++ interface layer (`src/fut_c_api.F90` + `include/fut_c_api.h`) allows cross-language projects to drive the library from C or C++ and integrate with Catch2 / CTest for automatic test discovery.

- **Languages**: Fortran (`.F90`), C/C++ (bridge headers only)
- **Build system**: CMake (minimum 3.5)
- **License**: MIT
- **Version**: 0.0.1
- **Compiler support**: GNU 4.8.5+, PGI 18.4+, Intel 17.0.2+

## Repository Structure

```
fortran-unit-test/
├── CMakeLists.txt               # Build configuration; produces libfortran_unit_test.so
├── README.md                    # User-facing documentation with examples and type tables
├── LICENSE                      # MIT License
├── .gitignore                   # Ignores build/
├── cmake/
│   └── FortranUnitTestConfig.cmake.in  # CMake package config template for downstream use
├── include/
│   ├── fut_c_api.h              # C header: declares all bind(C) symbols + convenience macros
│   └── fut_catch2.hpp           # C++ header: FutSuiteGuard RAII class + Catch2 macros
├── src/
│   ├── unit_test.F90            # Public entry point: re-exports all public Fortran symbols
│   ├── assert_mod.F90           # All assertion interfaces and implementations (~1457 lines)
│   ├── test_case_mod.F90        # Test case create/report/query (~177 lines)
│   ├── test_suite_mod.F90       # Test suite init/final/report/query (~181 lines)
│   ├── test_common_mod.F90      # Shared types, to_string, write_header/footer (~191 lines)
│   ├── fut_c_api.F90            # ISO C Binding wrapper — exposes FUT to C/C++ via handles
│   └── assert_test.F90          # Integration test program (built only as top-level project)
└── tests/
    └── test_fortran_suite.cpp   # Catch2 cross-language tests (requires Catch2 v3)
```

## Build Workflow

### Standalone build (includes `assert_test.exe` and optional Catch2 tests)

```sh
mkdir build && cd build
cmake ..
make
ctest           # runs all discovered tests
```

CTest automatically runs the Fortran integration test (`FortranIntegrationTest`) and, if Catch2 v3 was found, all Catch2 test cases prefixed with `Catch2::`.

### Run only Fortran integration test

```sh
ctest -R FortranIntegrationTest
# or directly:
./assert_test.exe
```

### Run only C++/Catch2 tests

```sh
ctest -R "Catch2::"
# or directly with Catch2 flags:
./fut_catch2_test "[fortran]"
```

### As a subdirectory of another CMake project

```cmake
add_subdirectory(<path-to-fortran-unit-test>)
include_directories(${UNIT_TEST_INCLUDE_DIR})
target_link_libraries(<your-target> fortran_unit_test)
```

When built as a subdirectory (`has_parent` is true), the test executables and CTest integration are **not** created.

### Install

```sh
cmake --install build
```

Installs the shared library to `lib/`, Fortran `.mod` files, C/C++ headers to `include/fortran_unit_test/`, and CMake package files to `lib/cmake/FortranUnitTest/`.

### Compiler flags

- GNU: `-ffree-line-length-none` (required for long lines in the source)
- PGI: no extra flags
- Intel: no extra flags defined in CMakeLists.txt

### Catch2 availability

Catch2 v3 is **optional**. If not found, CMake prints a status message and skips building `fut_catch2_test`. To enable:

```sh
# Ubuntu/Debian (check version — prefer v3)
apt install catch2
# vcpkg
vcpkg install catch2
# Homebrew
brew install catch2
# From source
cmake --install <catch2-build>
```

Re-run `cmake ..` after installing; CMake will pick it up automatically.

## Module Architecture

Dependency order (bottom to top):

```
test_common_mod   ← defines shared types and helpers (no deps)
test_case_mod     ← uses test_common_mod
assert_mod        ← uses test_common_mod, test_case_mod
test_suite_mod    ← uses test_common_mod, test_case_mod
unit_test         ← re-exports assert_mod, test_case_mod, test_suite_mod
fut_c_api_mod     ← uses unit_test + iso_c_binding; exposes flat C ABI
```

The C/C++ bridge (`fut_c_api_mod`) sits on top of the full Fortran stack. It uses a module-level registry of up to 32 `test_suite_type` instances and returns integer handles to callers, because Fortran derived types containing pointer components cannot cross the C ABI.

End users only need `use unit_test` (Fortran) or `#include "fut_c_api.h"` (C/C++).

## Key Data Structures (`test_common_mod.F90`)

All three types form **singly-linked lists**:

```
test_suite_type
  └── test_case_type  (linked list via .next)
        └── assert_result_type  (linked list via .next)
```

- `assert_result_type`: stores operator string, left/right operand strings, file name, line number, pass/fail flag, assertion ID.
- `test_case_type`: stores name, assertion count, pass count, head/tail pointers to assertion results.
- `test_suite_type`: stores name, test case count, head/tail pointers to test cases.
- `default_test_suite`: module-level `target` variable used when no explicit suite is provided.

Memory must be freed explicitly with `test_suite_final(suite)` (Fortran) or `fut_suite_finalize(handle)` (C/C++).

## Fortran Public API

### Initialization and lifecycle

```fortran
call test_suite_init('suite name')              ! default suite (name required)
call test_suite_init('suite name', my_suite)    ! named custom suite

call test_case_create('case name')              ! add to default suite
call test_case_create('case name', my_suite)    ! add to specific suite

call test_suite_report()                        ! print default suite report
call test_suite_report(my_suite)                ! print specific suite report
call test_case_report('case name', my_suite)    ! print single case report

call test_suite_final(my_suite)                 ! deallocate all memory
```

### Assertion functions

All assertions accept optional `file_name`, `line_number`, and `suite` arguments. Pass `__FILE__` and `__LINE__` preprocessor macros to get location info in failure reports.

```fortran
! Exact equality — integers (kind 1/2/4/8), reals (kind 4/8), character(*),
!                  plus _vec (1D) and _array (2D) variants
call assert_equal(x, y [, __FILE__, __LINE__ [, suite]])

! Approximate equality — reals (kind 4/8), _vec, _array
! Default epsilon: 1e-3
call assert_approximate(x, y [, __FILE__, __LINE__ [, eps, suite]])

! Greater-than — integers (kind 1/2/4/8), reals (kind 4/8), _vec, _array
call assert_great_than(x, y [, __FILE__, __LINE__ [, suite]])

! Boolean assertions
call assert_true(condition [, __FILE__, __LINE__ [, suite]])
call assert_false(condition [, __FILE__, __LINE__ [, suite]])

! Unconditional failure
call assert_failure([__FILE__, __LINE__ [, suite]])
```

**Note on keyword argument requirement**: When positional optional args are skipped (e.g., omitting `eps` but providing `suite`), use the keyword form: `suite=my_suite`.

### Result inspection

```fortran
logical, allocatable :: results(:)

results = test_suite_get_assert_results(my_suite)              ! all assertions in suite
results = test_case_get_assert_results('case name', my_suite)  ! assertions in one case
```

## C / C++ Public API (`include/fut_c_api.h`)

### Suite lifecycle

```c
// Create a suite; returns integer handle >= 1, or 0 if registry is full.
int  fut_suite_create(const char *name, int name_len);
void fut_suite_finalize(int handle);   // frees all memory
void fut_suite_report(int handle);     // prints ASCII tree to stdout
```

### Test case management

```c
// Subsequent assertions are recorded in this case until the next call.
void fut_case_create(int handle, const char *name, int name_len);
```

### Assertion functions

```c
void fut_assert_equal_int32(int handle, int x, int y,
                            const char *file, int file_len, int line);
void fut_assert_equal_real64(int handle, double x, double y,
                             const char *file, int file_len, int line);
void fut_assert_approximate_real64(int handle, double x, double y, double eps,
                                   const char *file, int file_len, int line);
void fut_assert_approximate_real32(int handle, float x, float y, float eps,
                                   const char *file, int file_len, int line);
void fut_assert_true(int handle, int cond,
                     const char *file, int file_len, int line);
void fut_assert_false(int handle, int cond,
                      const char *file, int file_len, int line);
void fut_assert_failure(int handle, const char *file, int file_len, int line);
```

`cond` follows C boolean convention: 0 = false, non-zero = true.

### Convenience macros (defined in `fut_c_api.h`)

```c
FUT_LOC                          // expands to: __FILE__, (int)(sizeof(__FILE__)-1), __LINE__
FUT_ASSERT_EQ_INT(h, x, y)      // fut_assert_equal_int32 at current location
FUT_ASSERT_EQ_DBL(h, x, y)      // fut_assert_equal_real64 at current location
FUT_ASSERT_APPROX(h, x, y)      // fut_assert_approximate_real64, eps=1e-3
FUT_ASSERT_APPROX_EPS(h,x,y,e)  // fut_assert_approximate_real64, explicit eps
FUT_ASSERT_TRUE(h, cond)
FUT_ASSERT_FALSE(h, cond)
```

### Result query

```c
int fut_suite_num_cases(int handle);       // number of test cases
int fut_suite_num_assertions(int handle);  // total assertion count
int fut_suite_num_passed(int handle);      // passed assertion count
```

### Minimal C usage example

```c
#include "fut_c_api.h"

int main(void) {
    int s = fut_suite_create("Physics tests", 13);
    fut_case_create(s, "momentum", 8);
    FUT_ASSERT_APPROX_EPS(s, 4.0, 4.0, 1e-10);
    fut_suite_report(s);
    int failed = fut_suite_num_assertions(s) - fut_suite_num_passed(s);
    fut_suite_finalize(s);
    return failed;   /* 0 = all passed */
}
```

## C++ / Catch2 Integration (`include/fut_catch2.hpp`)

### Classes

| Class | Purpose |
|---|---|
| `FutSuiteGuard` | RAII owner of a FUT suite. Constructor calls `fut_suite_create`, destructor calls `fut_suite_finalize`. Exposes `handle()`, `numPassed()`, `numFailed()`, `numAssertions()`, `numCases()`, `allPassed()`, `report()`. |
| `FutCaseGuard` | Calls `fut_case_create` on construction. Destruction is a no-op; case memory is owned by the suite. |

### Macros

| Macro | Behaviour |
|---|---|
| `FUT_CHECK_SUITE(guard)` | Catch2 `CHECK` that `numPassed() == numAssertions()`. Prints counts on failure. |
| `FUT_REQUIRE_SUITE(guard)` | `REQUIRE` variant — aborts the test on failure. |
| `FUT_CHECK_ALL_PASSED(guard)` | Checks that at least one assertion was recorded **and** all passed. |

### Catch2 usage example

```cpp
#include "fut_catch2.hpp"

TEST_CASE("Fortran FUT assertions via C++ Catch2", "[fortran]") {
    FutSuiteGuard suite("My physics suite");

    SECTION("conservation of momentum") {
        FutCaseGuard cas(suite, "momentum");
        FUT_ASSERT_APPROX_EPS(suite.handle(), 4.0, 4.0, 1e-10);
        FUT_CHECK_ALL_PASSED(suite);
    }

    SECTION("boolean checks") {
        FutCaseGuard cas(suite, "booleans");
        FUT_ASSERT_TRUE(suite.handle(), 1);
        FUT_ASSERT_FALSE(suite.handle(), 0);
        FUT_CHECK_ALL_PASSED(suite);
    }
}
```

`catch_discover_tests(fut_catch2_test TEST_PREFIX "Catch2::")` in `CMakeLists.txt` registers every `TEST_CASE` with CTest automatically.

## Naming Conventions

- **Types**: `snake_case_type` (e.g., `test_suite_type`, `assert_result_type`)
- **Fortran subroutines/functions**: `snake_case` prefixed by module area (e.g., `test_suite_init`, `assert_equal`)
- **Internal procedure suffixes**: `_integer1`, `_integer2`, `_integer4`, `_integer8`, `_real4`, `_real8`, `_string`; append `_vec` for 1D arrays, `_array` for 2D arrays
- **C API symbols**: `fut_` prefix, snake_case (e.g., `fut_suite_create`, `fut_assert_equal_int32`)
- **C++ classes**: `PascalCase` with `Fut` prefix (e.g., `FutSuiteGuard`, `FutCaseGuard`)
- **C/C++ macros**: `FUT_` prefix, all-caps (e.g., `FUT_ASSERT_EQ_INT`, `FUT_CHECK_SUITE`)
- **Parameters**: `eps_default_kind4`, `eps_default_kind8` for default tolerances
- **Source files**: `.F90` (uppercase) for files that use C preprocessor macros

## Adding New Assertion Overloads

### Fortran side

When extending `assert_mod.F90` to support a new type or dimensionality:

1. Add a `module procedure` line to the appropriate `interface` block (e.g., `interface assert_equal`).
2. Implement the concrete subroutine following the naming pattern (e.g., `assert_equal_logical`).
3. The subroutine should call `test_case_append_assert(result, suite)` to record the result.
4. Mirror the pattern of existing procedures: compute pass/fail, build operand strings with `to_string`, call `test_case_append_assert`.

### C API side

When adding a new assertion type to the C API (`src/fut_c_api.F90` + `include/fut_c_api.h`):

1. Add a `bind(C, name="fut_assert_<type>")` subroutine to `fut_c_api_mod` that converts C types to Fortran kinds and calls the appropriate Fortran assertion.
2. Declare it in `include/fut_c_api.h` inside the `extern "C"` block.
3. Optionally add a `FUT_ASSERT_<TYPE>` convenience macro to `fut_c_api.h`.

## Integration Test (`assert_test.F90`)

The file `src/assert_test.F90` is the integration test. Convention: **odd-numbered assertions within a test case are expected to fail; even-numbered assertions are expected to pass**. This pattern is verified at the end of the `great_than` suite using `test_suite_get_assert_results` and `test_case_get_assert_results`.

Run via CTest or directly:

```sh
cd build && make && ctest -V          # all tests
cd build && make && ./assert_test.exe  # Fortran only
```

Successful output shows `N of N assertions succeed` summaries for each suite. Any regression will show `0 of N` or unexpected failure counts.

## Cross-Language Test (`tests/test_fortran_suite.cpp`)

Contains four Catch2 `TEST_CASE`s that drive the Fortran library through the C API:

| TEST_CASE | Tag(s) | What it covers |
|---|---|---|
| `Fortran assert_equal_int32 via C API` | `[fortran][equal][int32]` | `FUT_ASSERT_EQ_INT`, mixed pass/fail, count verification |
| `Fortran assert_approximate_real64 via C API` | `[fortran][approximate][real64]` | Default and custom eps, relative tolerance boundary |
| `Fortran assert_true / assert_false via C API` | `[fortran][boolean]` | Both boolean directions, C non-zero convention |
| `Full cross-language workflow` | `[fortran][integration]` | Physics example + boundary values, all-pass suite |

Each `TEST_CASE` uses one or more `SECTION`s, each with its own `FutCaseGuard`. This means `catch_discover_tests` registers each `SECTION` as a separate CTest entry.

## Report Output Format

Reports use an ASCII tree format, 80 columns wide, with `/`-padded headers:

```
///////////////////// Report of Suite: Suite Name ///////////////////////

 +-> Details:
 |   |
 |   +-> Test Case: M of N assertions succeed.
 |   |   |
 |   |   +-> Assertion #K failed with reason: x ( val) OP y ( val)
 |   |   +-> Check line: filename.F90:42
 |
 +-> Summary:
 |   +-> Suite Name: M of N assertions succeed.

////////////////////////////////////////////////////////////////////////////////
```

Output goes to unit `6` (stdout). Errors would go to unit `0` (stderr), though currently all output uses `log_out_unit = 6`.

## No CI/CD

There is no automated CI pipeline in this repository. Tests must be run manually as described above.

## Known Issues / Notes

- `assert_great_than` has a typo in the name (should be `assert_greater_than`). Do **not** rename it without considering downstream users — it is the established public API.
- Terminal width is hardcoded to 80 columns in `write_header`/`write_footer` (noted as a TODO in source).
- `test_case_final` is referenced in the README example but is not defined in the source; the correct cleanup call is `test_suite_final` (Fortran) / `fut_suite_finalize` (C/C++).
- The C API suite registry (`FUT_MAX_SUITES = 32`) is module-level global state and is not thread-safe. Do not call `fut_suite_create` concurrently from multiple threads.
- `fut_c_api_mod` suites are never reset across a process lifetime even after `fut_suite_finalize`; the handle counter only ever increments. Do not exceed 32 concurrent live suites.
