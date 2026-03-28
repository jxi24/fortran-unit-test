/**
 * fut_catch2.hpp — Catch2 bridge for the Fortran Unit Test (FUT) library.
 *
 * Provides:
 *   - FutSuiteGuard   RAII wrapper that creates a FUT suite and frees it on
 *                     destruction.  Exposes typed accessors for result counts.
 *   - FutCaseGuard    Thin RAII helper that calls fut_case_create() and gives
 *                     each test case a clean scope.
 *   - FUT_CHECK_SUITE(guard)   Catch2 CHECK that all assertions in the suite
 *                              passed, with a descriptive failure message.
 *   - FUT_REQUIRE_SUITE(guard) REQUIRE variant — aborts the test on failure.
 *
 * Typical usage:
 *
 *   TEST_CASE("Fortran equality", "[fortran]") {
 *       FutSuiteGuard suite("My suite");
 *
 *       SECTION("integers") {
 *           FutCaseGuard cas(suite, "int checks");
 *           FUT_ASSERT_EQ_INT(suite.handle(), 6, 6);
 *           FUT_ASSERT_EQ_INT(suite.handle(), 6, 7);   // intentional fail
 *           FUT_CHECK_SUITE(suite);  // 1 of 2 passed → CHECK fails
 *       }
 *   }
 *
 * Requires Catch2 v3 (catch2/catch_all.hpp or catch2/catch_test_macros.hpp).
 */

#ifndef FUT_CATCH2_HPP
#define FUT_CATCH2_HPP

#include <catch2/catch_test_macros.hpp>
#include <catch2/catch_message.hpp>

#include "fut_c_api.h"

#include <string>
#include <stdexcept>

// ---------------------------------------------------------------------------
// FutSuiteGuard
// ---------------------------------------------------------------------------

/**
 * RAII owner of a FUT suite.
 *
 * The suite is created in the constructor and finalized (freed) in the
 * destructor.  Copy/assign are deleted — suites are unique resources.
 */
class FutSuiteGuard {
public:
    explicit FutSuiteGuard(const std::string &name)
        : handle_(fut_suite_create(name.c_str(),
                                   static_cast<int>(name.size()))),
          name_(name)
    {
        if (handle_ == 0) {
            throw std::runtime_error(
                "FutSuiteGuard: fut_suite_create returned 0 — "
                "FUT_MAX_SUITES (32) concurrent suites exceeded.");
        }
    }

    ~FutSuiteGuard() {
        fut_suite_finalize(handle_);
    }

    FutSuiteGuard(const FutSuiteGuard &) = delete;
    FutSuiteGuard &operator=(const FutSuiteGuard &) = delete;

    /** The raw integer handle; pass to all fut_* C API calls. */
    int handle() const noexcept { return handle_; }

    /** Name the suite was created with. */
    const std::string &name() const noexcept { return name_; }

    /** Total assertions recorded in the suite so far. */
    int numAssertions() const noexcept {
        return fut_suite_num_assertions(handle_);
    }

    /** Assertions that passed. */
    int numPassed() const noexcept {
        return fut_suite_num_passed(handle_);
    }

    /** Assertions that failed. */
    int numFailed() const noexcept {
        return numAssertions() - numPassed();
    }

    /** True iff every recorded assertion passed. */
    bool allPassed() const noexcept {
        int total = numAssertions();
        return total > 0 && numPassed() == total;
    }

    /** Number of test cases in the suite. */
    int numCases() const noexcept {
        return fut_suite_num_cases(handle_);
    }

    /** Print the ASCII-tree report to stdout. */
    void report() const {
        fut_suite_report(handle_);
    }

private:
    int handle_;
    std::string name_;
};

// ---------------------------------------------------------------------------
// FutCaseGuard
// ---------------------------------------------------------------------------

/**
 * Thin RAII helper that calls fut_case_create() on construction.
 * Destruction is a no-op (case memory is owned by the suite).
 * Mainly used to give each Catch2 SECTION a clearly labelled FUT case.
 */
class FutCaseGuard {
public:
    FutCaseGuard(const FutSuiteGuard &suite, const std::string &case_name)
        : handle_(suite.handle())
    {
        fut_case_create(handle_,
                        case_name.c_str(),
                        static_cast<int>(case_name.size()));
    }

    /** The suite handle — identical to the parent FutSuiteGuard's handle. */
    int handle() const noexcept { return handle_; }

private:
    int handle_;
};

// ---------------------------------------------------------------------------
// Catch2 integration macros
// ---------------------------------------------------------------------------

/**
 * FUT_CHECK_SUITE(guard)
 *
 * Emits a Catch2 CHECK that all assertions in the suite passed.
 * On failure, prints how many assertions failed before continuing.
 */
#define FUT_CHECK_SUITE(guard)                                                \
    do {                                                                      \
        int _fut_total  = (guard).numAssertions();                            \
        int _fut_passed = (guard).numPassed();                                \
        INFO("FUT suite \"" << (guard).name() << "\": "                      \
             << _fut_passed << " of " << _fut_total                          \
             << " assertions passed");                                        \
        CHECK(_fut_passed == _fut_total);                                     \
    } while (0)

/**
 * FUT_REQUIRE_SUITE(guard)
 *
 * REQUIRE variant — aborts the current Catch2 test on the first suite failure.
 */
#define FUT_REQUIRE_SUITE(guard)                                              \
    do {                                                                      \
        int _fut_total  = (guard).numAssertions();                            \
        int _fut_passed = (guard).numPassed();                                \
        INFO("FUT suite \"" << (guard).name() << "\": "                      \
             << _fut_passed << " of " << _fut_total                          \
             << " assertions passed");                                        \
        REQUIRE(_fut_passed == _fut_total);                                   \
    } while (0)

/**
 * FUT_CHECK_ALL_PASSED(guard)
 *
 * Equivalent to FUT_CHECK_SUITE but also checks that at least one assertion
 * was recorded (guards against accidentally empty suites).
 */
#define FUT_CHECK_ALL_PASSED(guard)                                           \
    do {                                                                      \
        CHECK((guard).numAssertions() > 0);                                   \
        FUT_CHECK_SUITE(guard);                                               \
    } while (0)

#endif /* FUT_CATCH2_HPP */
