/*
 * fut_c_api.h — C interface to the Fortran Unit Test (FUT) library.
 *
 * Suites are identified by an integer handle returned by fut_suite_create().
 * All memory for a suite is owned by the Fortran runtime; call
 * fut_suite_finalize() when done to release it.
 *
 * String arguments (name, file) are passed as a pointer + explicit byte-count
 * so that neither a NUL terminator nor fixed-size buffers are required.
 *
 * Usage (C):
 *   int s = fut_suite_create("MySuite", 7);
 *   fut_case_create(s, "Case 1", 6);
 *   fut_assert_equal_int32(s, 1, 1, __FILE__, (int)sizeof(__FILE__)-1, __LINE__);
 *   fut_suite_report(s);
 *   fut_suite_finalize(s);
 */

#ifndef FUT_C_API_H
#define FUT_C_API_H

#ifdef __cplusplus
extern "C" {
#endif

/* -------------------------------------------------------------------------
 * Suite lifecycle
 * ---------------------------------------------------------------------- */

/**
 * Create a new test suite with the given name.
 * Returns a handle >= 1 on success, or 0 if the internal registry is full
 * (FUT_MAX_SUITES = 32 concurrent suites).
 */
int fut_suite_create(const char *name, int name_len);

/** Free all memory associated with the suite identified by handle. */
void fut_suite_finalize(int handle);

/** Print the ASCII-tree report for the suite to stdout (unit 6). */
void fut_suite_report(int handle);

/* -------------------------------------------------------------------------
 * Test case management
 * ---------------------------------------------------------------------- */

/** Append a new test case to the suite. Subsequent assertions are recorded
 *  in this case until the next fut_case_create() call for the same handle. */
void fut_case_create(int handle, const char *name, int name_len);

/* -------------------------------------------------------------------------
 * Assertion functions
 *
 * file / file_len  — source file name and its byte length (pass __FILE__ and
 *                    (int)sizeof(__FILE__)-1).  May be "" / 0 to omit.
 * line             — source line number (pass __LINE__).  May be 0 to omit.
 * ---------------------------------------------------------------------- */

/** Exact equality — 32-bit integers. */
void fut_assert_equal_int32(int handle, int x, int y,
                            const char *file, int file_len, int line);

/** Exact equality — 64-bit IEEE doubles. */
void fut_assert_equal_real64(int handle, double x, double y,
                             const char *file, int file_len, int line);

/**
 * Approximate equality — 64-bit IEEE doubles.
 * Passes when |x - y| / max(|x|, |y|, 1) <= eps.
 * Recommended default for eps: 1e-3.
 */
void fut_assert_approximate_real64(int handle, double x, double y, double eps,
                                   const char *file, int file_len, int line);

/**
 * Approximate equality — 32-bit IEEE floats.
 * Recommended default for eps: 1e-3f.
 */
void fut_assert_approximate_real32(int handle, float x, float y, float eps,
                                   const char *file, int file_len, int line);

/**
 * Assert condition is true.
 * cond: 0 = false, non-zero = true (standard C boolean convention).
 */
void fut_assert_true(int handle, int cond,
                     const char *file, int file_len, int line);

/**
 * Assert condition is false.
 * cond: 0 = false, non-zero = true (standard C boolean convention).
 */
void fut_assert_false(int handle, int cond,
                      const char *file, int file_len, int line);

/** Unconditionally record a failure in the current test case. */
void fut_assert_failure(int handle, const char *file, int file_len, int line);

/* -------------------------------------------------------------------------
 * Result query functions (call after running assertions, before finalize)
 * ---------------------------------------------------------------------- */

/** Number of test cases registered in the suite. */
int fut_suite_num_cases(int handle);

/** Total number of assertions recorded across all cases in the suite. */
int fut_suite_num_assertions(int handle);

/** Number of assertions that passed across all cases in the suite. */
int fut_suite_num_passed(int handle);

/* -------------------------------------------------------------------------
 * Test registry — auto-discovery of Fortran test suites from C++
 *
 * Usage:
 *   1. In Fortran, call fut_register_test("Suite Name", my_subroutine)
 *      for every test suite you want Catch2 to discover.
 *   2. In C++, call your registration function once, then use
 *      FUT_AUTO_DISCOVER_TESTS() (defined in fut_catch2.hpp) to run all
 *      registered suites as independent Catch2 test instances.
 * ---------------------------------------------------------------------- */

/** Return the number of registered Fortran test suites. */
int fut_num_registered_tests(void);

/**
 * Copy the name of the idx-th registered suite (0-based) into buf.
 * buf must be at least 129 bytes.  *buf_len receives the length written
 * (not counting the NUL terminator that is always appended).
 */
void fut_get_registered_test_name(int idx, char *buf, int *buf_len);

/**
 * Run the idx-th registered suite (0-based) into the FUT suite handle.
 * The handle must have been obtained from fut_suite_create().
 */
void fut_run_registered_test(int idx, int handle);

/** Clear all registrations (useful for isolated test runs). */
void fut_clear_registered_tests(void);

/* -------------------------------------------------------------------------
 * Convenience macros
 * ---------------------------------------------------------------------- */

/** Pass source location arguments without typing them out each time. */
#define FUT_LOC __FILE__, (int)(sizeof(__FILE__) - 1), __LINE__

/** Assert exact int32 equality at the current source location. */
#define FUT_ASSERT_EQ_INT(handle, x, y) \
    fut_assert_equal_int32((handle), (x), (y), FUT_LOC)

/** Assert exact double equality at the current source location. */
#define FUT_ASSERT_EQ_DBL(handle, x, y) \
    fut_assert_equal_real64((handle), (x), (y), FUT_LOC)

/** Assert approximate double equality (eps = 1e-3) at the current source location. */
#define FUT_ASSERT_APPROX(handle, x, y) \
    fut_assert_approximate_real64((handle), (x), (y), 1e-3, FUT_LOC)

/** Assert approximate double equality with explicit eps. */
#define FUT_ASSERT_APPROX_EPS(handle, x, y, eps) \
    fut_assert_approximate_real64((handle), (x), (y), (eps), FUT_LOC)

/** Assert that cond is true (C boolean). */
#define FUT_ASSERT_TRUE(handle, cond) \
    fut_assert_true((handle), (cond) ? 1 : 0, FUT_LOC)

/** Assert that cond is false (C boolean). */
#define FUT_ASSERT_FALSE(handle, cond) \
    fut_assert_false((handle), (cond) ? 1 : 0, FUT_LOC)

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* FUT_C_API_H */
