# CLAUDE.md — Fortran Unit Test Library (FUT)

This file documents the codebase structure, build workflows, and conventions for AI assistants working in this repository.

## Project Overview

FUT is a pure-Fortran unit testing library designed for scientific Fortran programmers. It has no external dependencies and provides assertion functions, test case management, and test suite management via a simple Fortran module interface.

- **Language**: Fortran (free-form `.F90` files with preprocessing)
- **Build system**: CMake (minimum 3.0)
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
└── src/
    ├── unit_test.F90            # Public entry point: re-exports all public symbols
    ├── assert_mod.F90           # All assertion interfaces and implementations (~1457 lines)
    ├── test_case_mod.F90        # Test case create/report/query (~177 lines)
    ├── test_suite_mod.F90       # Test suite init/final/report/query (~181 lines)
    ├── test_common_mod.F90      # Shared types, to_string, write_header/footer (~191 lines)
    └── assert_test.F90          # Integration test program (built only as top-level project)
```

## Build Workflow

### Standalone build (includes `assert_test.exe`)

```sh
mkdir build && cd build
cmake ..
make
./assert_test.exe
```

### As a subdirectory of another CMake project

```cmake
add_subdirectory(<path-to-fortran-unit-test>)
include_directories(${UNIT_TEST_INCLUDE_DIR})
target_link_libraries(<your-target> fortran_unit_test)
```

When built as a subdirectory (`has_parent` is true), the `assert_test.exe` target is **not** created.

### Install

```sh
cmake --install build
```

Installs the shared library to `lib/` and CMake package files to `lib/cmake/FortranUnitTest/`.

### Fortran module files

Module `.mod` files are placed in `${CMAKE_CURRENT_BINARY_DIR}/modules`. Users of the installed library get the include path via the exported CMake target.

### Compiler flags

- GNU: `-ffree-line-length-none` (required for long lines in the source)
- PGI: no extra flags
- Intel: no extra flags defined in CMakeLists.txt

## Module Architecture

Dependency order (bottom to top):

```
test_common_mod   ← defines shared types and helpers (no deps)
test_case_mod     ← uses test_common_mod
assert_mod        ← uses test_common_mod, test_case_mod
test_suite_mod    ← uses test_common_mod, test_case_mod
unit_test         ← re-exports assert_mod, test_case_mod, test_suite_mod
```

End users only need `use unit_test`.

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

Memory must be freed explicitly with `test_suite_final(suite)`.

## Public API

### Initialization and lifecycle

```fortran
call test_suite_init()                          ! default suite
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

results = test_suite_get_assert_results(my_suite)   ! all assertions in suite
results = test_case_get_assert_results('case name', my_suite)  ! assertions in one case
```

## Naming Conventions

- **Types**: `snake_case_type` (e.g., `test_suite_type`, `assert_result_type`)
- **Subroutines/functions**: `snake_case` prefixed by module area (e.g., `test_suite_init`, `assert_equal`)
- **Internal procedure suffixes**: `_integer1`, `_integer2`, `_integer4`, `_integer8`, `_real4`, `_real8`, `_string`; append `_vec` for 1D arrays, `_array` for 2D arrays
- **Parameters**: `eps_default_kind4`, `eps_default_kind8` for default tolerances
- **Source files**: `.F90` extension (uppercase) for files that use C preprocessor macros (`__FILE__`, `__LINE__`, `#include`-style ifdefs if added)

## Adding New Assertion Overloads

When extending `assert_mod.F90` to support a new type or dimensionality:

1. Add a `module procedure` line to the appropriate `interface` block (e.g., `interface assert_equal`).
2. Implement the concrete subroutine following the naming pattern (e.g., `assert_equal_logical`).
3. The subroutine should call `test_case_append_assert(result, suite)` to record the result.
4. Mirror the pattern of existing procedures: compute pass/fail, build operand strings with `to_string`, call `test_case_append_assert`.

## Integration Test (`assert_test.F90`)

The file `src/assert_test.F90` is the integration test. Convention: **odd-numbered assertions within a test case are expected to fail; even-numbered assertions are expected to pass**. This pattern is verified at the end of the `great_than` suite using `test_suite_get_assert_results` and `test_case_get_assert_results`.

Run the integration test after any changes to assertion logic:

```sh
cd build && make && ./assert_test.exe
```

Successful output shows `N of N assertions succeed` summaries for each suite. Any regression will show `0 of N` or unexpected failure counts.

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
- `test_case_final` is referenced in the README example but is not defined in the source; the correct cleanup call is `test_suite_final`.
