/**
 * test_suite.cpp — minimal Catch2 driver for Fortran test suites.
 *
 * This file never changes when tests are added.  All test logic lives in
 * physics_tests.F90.  Adding a new test suite = write a Fortran subroutine
 * and register it with one call add_test(...) line.
 *
 * Mechanism:
 *   physics_register_tests()   — populate the Fortran registry (idempotent)
 *   physics_num_tests()        — how many test suites are registered
 *   physics_get_test_name(i,…) — name of the i-th suite (0-based)
 *   physics_run_test(i, h)     — run the i-th suite into FUT handle h
 *
 * Catch2's GENERATE_COPY(range(0, n)) turns one TEST_CASE into n
 * independent test instances, one per registered Fortran suite.
 *
 * Build & run:
 *   cmake -S .. -B build && cmake --build build
 *   ctest --test-dir build -V
 */

#include "fut_catch2.hpp"   // FutSuiteGuard, FUT_CHECK_ALL_PASSED
#include <catch2/generators/catch_generators.hpp>
#include <catch2/generators/catch_generators_range.hpp>
#include <string>

extern "C" {
    void physics_register_tests();
    int  physics_num_tests();
    void physics_get_test_name(int idx, char* buf, int* len);
    void physics_run_test     (int idx, int  handle);
}

TEST_CASE("Physics", "[physics]") {
    // Idempotent: populates the registry on first call only.
    physics_register_tests();

    const int n   = physics_num_tests();
    const int idx = GENERATE_COPY(range(0, n));

    // Retrieve the test name from Fortran.
    char name_buf[65] = {};
    int  name_len     = 0;
    physics_get_test_name(idx, name_buf, &name_len);
    const std::string name(name_buf, static_cast<std::size_t>(name_len));

    // Each index becomes its own named section in the Catch2 output.
    DYNAMIC_SECTION(name) {
        FutSuiteGuard suite(name);
        physics_run_test(idx, suite.handle());
        FUT_CHECK_ALL_PASSED(suite);
    }
}
