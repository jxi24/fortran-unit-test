/**
 * test_fortran_suite.cpp — Cross-language Catch2 tests for the FUT library.
 *
 * Each TEST_CASE creates a FUT suite via the C API, runs Fortran assertion
 * functions through it, then uses FUT_CHECK_SUITE / CHECK to verify the
 * results from the C++ side.  catch_discover_tests() in CMakeLists.txt makes
 * these visible to `ctest` with automatic test discovery — no manual
 * registration needed.
 *
 * Convention used throughout:
 *   - Assertions that are *expected to pass* are labelled "// pass"
 *   - Assertions that are *expected to fail* are labelled "// intentional fail"
 *   The final CHECK(s) verify the exact counts so that regressions in the
 *   Fortran library's pass/fail logic are caught on the C++ side as well.
 */

#include "fut_catch2.hpp"  // pulls in fut_c_api.h and catch2 headers

// ---------------------------------------------------------------------------
// Helper: string literal length as int (excludes NUL terminator)
// ---------------------------------------------------------------------------
#define FUT_SLEN(s) (static_cast<int>(sizeof(s) - 1))

// ---------------------------------------------------------------------------
// TEST_CASE 1 — Integer equality
// ---------------------------------------------------------------------------
TEST_CASE("Fortran assert_equal_int32 via C API", "[fortran][equal][int32]") {

    FutSuiteGuard suite("CppTest: int32 equality");

    SECTION("matching values pass, mismatched values fail") {
        FutCaseGuard cas(suite, "int32 checks");

        FUT_ASSERT_EQ_INT(suite.handle(), 42, 42);          // pass
        FUT_ASSERT_EQ_INT(suite.handle(), -7, -7);          // pass
        FUT_ASSERT_EQ_INT(suite.handle(),  0,  1);          // intentional fail
        FUT_ASSERT_EQ_INT(suite.handle(), 100, 100);        // pass

        CHECK(suite.numAssertions() == 4);
        CHECK(suite.numPassed()     == 3);
        CHECK(suite.numFailed()     == 1);
    }

    SECTION("zero compared to zero") {
        FutCaseGuard cas(suite, "zero equality");

        FUT_ASSERT_EQ_INT(suite.handle(), 0, 0);            // pass

        FUT_CHECK_ALL_PASSED(suite);
    }
}

// ---------------------------------------------------------------------------
// TEST_CASE 2 — Double-precision approximate equality
// ---------------------------------------------------------------------------
TEST_CASE("Fortran assert_approximate_real64 via C API",
          "[fortran][approximate][real64]") {

    FutSuiteGuard suite("CppTest: real64 approximate");

    SECTION("within tolerance passes, outside tolerance fails") {
        FutCaseGuard cas(suite, "approx checks");

        // Default eps = 1e-3 (relative tolerance)
        FUT_ASSERT_APPROX(suite.handle(), 1.0, 1.0);        // pass
        FUT_ASSERT_APPROX(suite.handle(), 1.0, 1.0009);     // pass  (< 0.1 %)
        FUT_ASSERT_APPROX(suite.handle(), 1.0, 1.1);        // intentional fail (10 %)
        FUT_ASSERT_APPROX(suite.handle(), 2.0, 2.0);        // pass

        CHECK(suite.numAssertions() == 4);
        CHECK(suite.numPassed()     == 3);
        CHECK(suite.numFailed()     == 1);
    }

    SECTION("tight custom tolerance") {
        FutCaseGuard cas(suite, "tight eps");

        FUT_ASSERT_APPROX_EPS(suite.handle(), 1.0, 1.0,     1e-9); // pass
        FUT_ASSERT_APPROX_EPS(suite.handle(), 1.0, 1.0001,  1e-9); // intentional fail
        FUT_ASSERT_APPROX_EPS(suite.handle(), 1.0, 1.0001,  1e-3); // pass

        CHECK(suite.numAssertions() == 3);
        CHECK(suite.numPassed()     == 2);
    }
}

// ---------------------------------------------------------------------------
// TEST_CASE 3 — Boolean assertions
// ---------------------------------------------------------------------------
TEST_CASE("Fortran assert_true / assert_false via C API",
          "[fortran][boolean]") {

    FutSuiteGuard suite("CppTest: boolean assertions");

    SECTION("assert_true") {
        FutCaseGuard cas(suite, "true checks");

        FUT_ASSERT_TRUE(suite.handle(), 1);                 // pass
        FUT_ASSERT_TRUE(suite.handle(), 42);                // pass  (any non-zero)
        FUT_ASSERT_TRUE(suite.handle(), 0);                 // intentional fail

        CHECK(suite.numAssertions() == 3);
        CHECK(suite.numPassed()     == 2);
    }

    SECTION("assert_false") {
        FutCaseGuard cas(suite, "false checks");

        FUT_ASSERT_FALSE(suite.handle(), 0);                // pass
        FUT_ASSERT_FALSE(suite.handle(), 1);                // intentional fail
        FUT_ASSERT_FALSE(suite.handle(), 0);                // pass

        CHECK(suite.numAssertions() == 3);
        CHECK(suite.numPassed()     == 2);
    }
}

// ---------------------------------------------------------------------------
// TEST_CASE 4 — Mixed cross-language test demonstrating full workflow
//
// This mirrors what a consumer of the library would write: Fortran does the
// numerics, Catch2 drives the test harness and reports failures in the normal
// Catch2 style.
// ---------------------------------------------------------------------------
TEST_CASE("Full cross-language workflow", "[fortran][integration]") {

    FutSuiteGuard suite("CppTest: cross-language integration");

    SECTION("numerical physics example — conservation of momentum") {
        FutCaseGuard cas(suite, "momentum conservation");

        // Simulate a simple elastic collision: p_before == p_after
        double m1 = 2.0, v1_before =  3.0, v1_after = -1.0;
        double m2 = 2.0, v2_before = -1.0, v2_after =  3.0;

        double p_before = m1 * v1_before + m2 * v2_before;
        double p_after  = m1 * v1_after  + m2 * v2_after;

        FUT_ASSERT_APPROX_EPS(suite.handle(), p_before, p_after, 1e-10); // pass

        FUT_CHECK_ALL_PASSED(suite);
    }

    SECTION("boundary condition checks") {
        FutCaseGuard cas(suite, "boundary values");

        // Zero array sum check via multiple scalar assertions
        FUT_ASSERT_EQ_INT(suite.handle(), 0, 0);            // pass
        FUT_ASSERT_TRUE(suite.handle(), (1 > 0));           // pass
        FUT_ASSERT_FALSE(suite.handle(), (0 > 1));          // pass

        FUT_CHECK_ALL_PASSED(suite);
    }

    // Optionally print the full Fortran-style report for debugging.
    // suite.report();
}

// ---------------------------------------------------------------------------
// TEST_CASE 5 — Fortran-native tests called by Catch2
//
// These subroutines are written entirely in Fortran using the native FUT API
// (use unit_test; call assert_equal / assert_approximate / …).  They accept
// an integer handle, obtain a Fortran pointer to the suite via
// fut_get_suite_ptr, and write tests as normal Fortran code.
//
// The C++ side just calls the subroutine and checks the aggregate results.
// ---------------------------------------------------------------------------
extern "C" {
    void fortran_assert_equal_tests(int handle);
    void fortran_assert_approximate_tests(int handle);
    void fortran_all_pass_tests(int handle);
}

TEST_CASE("Fortran-native tests driven by Catch2", "[fortran][native]") {

    SECTION("assert_equal written in Fortran — odd fail / even pass") {
        FutSuiteGuard suite("Native Fortran: assert_equal");
        fortran_assert_equal_tests(suite.handle());

        // 2 test cases × (1 fail + 1 pass) = 4 total, 2 passed
        CHECK(suite.numAssertions() == 4);
        CHECK(suite.numPassed()     == 2);
        CHECK(suite.numFailed()     == 2);
    }

    SECTION("assert_approximate written in Fortran — odd fail / even pass") {
        FutSuiteGuard suite("Native Fortran: assert_approximate");
        fortran_assert_approximate_tests(suite.handle());

        // 1 test case × (1 fail + 1 pass + 1 fail + 1 pass) = 4 total, 2 passed
        CHECK(suite.numAssertions() == 4);
        CHECK(suite.numPassed()     == 2);
        CHECK(suite.numFailed()     == 2);
    }

    SECTION("all-pass Fortran suite passes FUT_CHECK_ALL_PASSED") {
        FutSuiteGuard suite("Native Fortran: all pass");
        fortran_all_pass_tests(suite.handle());
        FUT_CHECK_ALL_PASSED(suite);
    }
}
