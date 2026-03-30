! fortran_native_tests.F90 — Fortran-native test subroutines callable from
! C++ Catch2 via the handle bridge.
!
! Pattern:
!   1. C++ creates a suite with fut_suite_create() → handle
!   2. C++ calls one of these subroutines, passing the handle
!   3. The subroutine obtains a Fortran pointer via fut_get_suite_ptr(handle)
!   4. All native FUT calls (test_case_create, assert_equal, …) are made
!      on that pointer — no C API wrappers needed
!   5. C++ reads results back via fut_suite_num_passed() / FUT_CHECK_ALL_PASSED
!
! Each subroutine uses bind(C) so the C++ side only needs an extern "C" decl.

! ---------------------------------------------------------------------------
! fortran_assert_equal_tests
!   Exercises assert_equal for integer and real kinds using the native Fortran
!   API.  Even-numbered assertions pass; odd-numbered ones intentionally fail.
! ---------------------------------------------------------------------------
subroutine fortran_assert_equal_tests(handle) bind(C, name="fortran_assert_equal_tests")

  use iso_c_binding
  use unit_test
  use fut_c_api_mod, only: fut_get_suite_ptr

  implicit none

  integer(c_int), value :: handle
  type(test_suite_type), pointer :: suite

  suite => fut_get_suite_ptr(int(handle))

  ! --- integer(4) ---
  call test_case_create('integer4 equal (Fortran)', suite)
  call assert_equal(int(1,4), int(2,4), __FILE__, __LINE__, suite)  ! fail
  call assert_equal(int(3,4), int(3,4), __FILE__, __LINE__, suite)  ! pass

  ! --- real(8) ---
  call test_case_create('real8 equal (Fortran)', suite)
  call assert_equal(1.0d0, 2.0d0, __FILE__, __LINE__, suite)        ! fail
  call assert_equal(3.0d0, 3.0d0, __FILE__, __LINE__, suite)        ! pass

end subroutine fortran_assert_equal_tests

! ---------------------------------------------------------------------------
! fortran_assert_approximate_tests
!   Exercises assert_approximate (the formerly-crashing optional-eps path).
! ---------------------------------------------------------------------------
subroutine fortran_assert_approximate_tests(handle) bind(C, name="fortran_assert_approximate_tests")

  use iso_c_binding
  use unit_test
  use fut_c_api_mod, only: fut_get_suite_ptr

  implicit none

  integer(c_int), value :: handle
  type(test_suite_type), pointer :: suite

  suite => fut_get_suite_ptr(int(handle))

  call test_case_create('approximate real8 (Fortran)', suite)

  ! default eps = 1e-3
  call assert_approximate(1.0d0, 1.1d0,           suite=suite)     ! fail (10 %)
  call assert_approximate(1.0d0, 1.0009d0,         suite=suite)     ! pass (< 0.1 %)

  ! explicit eps
  call assert_approximate(1.0d0, 1.0001d0, suite=suite, eps=1.0d-6) ! fail
  call assert_approximate(1.0d0, 1.0001d0, suite=suite, eps=1.0d-3) ! pass

end subroutine fortran_assert_approximate_tests

! ---------------------------------------------------------------------------
! fortran_all_pass_tests
!   All assertions pass — used by FUT_CHECK_ALL_PASSED in Catch2.
! ---------------------------------------------------------------------------
subroutine fortran_all_pass_tests(handle) bind(C, name="fortran_all_pass_tests")

  use iso_c_binding
  use unit_test
  use fut_c_api_mod, only: fut_get_suite_ptr

  implicit none

  integer(c_int), value :: handle
  type(test_suite_type), pointer :: suite

  suite => fut_get_suite_ptr(int(handle))

  call test_case_create('all pass (Fortran)', suite)

  call assert_equal(int(42,4), int(42,4), __FILE__, __LINE__, suite)
  call assert_approximate(1.0d0, 1.0d0,  __FILE__, __LINE__, suite=suite)
  call assert_true (.true.,               __FILE__, __LINE__, suite)
  call assert_false(.false.,              __FILE__, __LINE__, suite)

end subroutine fortran_all_pass_tests
