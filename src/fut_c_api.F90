! fut_c_api.F90 — ISO C Binding wrapper for the Fortran Unit Test library.
!
! Exposes a flat C ABI so C and C++ callers can drive the FUT library without
! touching any Fortran-specific types.  Suite objects (which contain Fortran
! pointer components and cannot cross the C ABI) are kept in a module-level
! registry; callers receive and pass back an integer handle (1-based index).
!
! Thread safety: not thread-safe.  Suite handles are global to the process.

module fut_c_api_mod

  use iso_c_binding
  use unit_test

  implicit none
  private

  ! Public non-bind(C) accessor — lets Fortran test subroutines use the native
  ! FUT API (assert_equal, test_case_create, …) on a suite that was created via
  ! the C handle system.  See CLAUDE.md for the usage pattern.
  public :: fut_get_suite_ptr

  ! Maximum number of concurrently live suites accessible via C handles.
  integer, parameter :: FUT_MAX_SUITES = 32

  type(test_suite_type), target, save :: suite_registry(FUT_MAX_SUITES)
  integer, save :: num_registered_suites = 0

contains

  ! ---------------------------------------------------------------------------
  ! Internal helper: copy a C character array (not null-terminated; explicit
  ! length) into a Fortran CHARACTER variable.
  ! ---------------------------------------------------------------------------
  subroutine c_str_to_fortran(c_chars, c_len, f_str)
    integer(c_int), value, intent(in) :: c_len
    character(kind=c_char), intent(in) :: c_chars(c_len)
    character(len=*), intent(out) :: f_str
    integer :: i
    f_str = ' '
    do i = 1, min(c_len, len(f_str))
      f_str(i:i) = c_chars(i)
    end do
  end subroutine c_str_to_fortran

  ! ---------------------------------------------------------------------------
  ! fut_suite_create
  !   name     — suite name (NOT null-terminated; pass the raw string bytes)
  !   name_len — byte count of name
  !   returns  — integer handle (>= 1) used in all subsequent calls
  !              returns 0 on failure (registry full)
  ! ---------------------------------------------------------------------------
  function fut_suite_create(name, name_len) result(handle) &
      bind(C, name="fut_suite_create")

    character(kind=c_char), intent(in) :: name(*)
    integer(c_int), value, intent(in) :: name_len
    integer(c_int) :: handle

    character(256) :: f_name

    if (num_registered_suites >= FUT_MAX_SUITES) then
      handle = 0
      return
    end if

    num_registered_suites = num_registered_suites + 1
    handle = num_registered_suites

    call c_str_to_fortran(name(1:name_len), name_len, f_name)
    call test_suite_init(trim(f_name), suite_registry(handle))

  end function fut_suite_create

  ! ---------------------------------------------------------------------------
  ! fut_suite_finalize  — free all memory associated with handle
  ! ---------------------------------------------------------------------------
  subroutine fut_suite_finalize(handle) bind(C, name="fut_suite_finalize")

    integer(c_int), value, intent(in) :: handle

    call test_suite_final(suite_registry(handle))

  end subroutine fut_suite_finalize

  ! ---------------------------------------------------------------------------
  ! fut_suite_report  — print the ASCII tree report for handle to stdout
  ! ---------------------------------------------------------------------------
  subroutine fut_suite_report(handle) bind(C, name="fut_suite_report")

    integer(c_int), value, intent(in) :: handle

    call test_suite_report(suite_registry(handle))

  end subroutine fut_suite_report

  ! ---------------------------------------------------------------------------
  ! fut_case_create  — append a new test case to the suite identified by handle
  ! ---------------------------------------------------------------------------
  subroutine fut_case_create(handle, name, name_len) &
      bind(C, name="fut_case_create")

    integer(c_int), value, intent(in) :: handle
    character(kind=c_char), intent(in) :: name(*)
    integer(c_int), value, intent(in) :: name_len

    character(256) :: f_name

    call c_str_to_fortran(name(1:name_len), name_len, f_name)
    call test_case_create(trim(f_name), suite_registry(handle))

  end subroutine fut_case_create

  ! ---------------------------------------------------------------------------
  ! Assertion wrappers
  !   All accept: handle, operands, file (raw bytes), file_len, line_number.
  !   file and line_number may be passed as empty string / 0 to omit location.
  ! ---------------------------------------------------------------------------

  subroutine fut_assert_equal_int32(handle, x, y, file, file_len, line) &
      bind(C, name="fut_assert_equal_int32")

    integer(c_int), value, intent(in) :: handle, x, y, file_len, line
    character(kind=c_char), intent(in) :: file(*)

    character(256) :: f_file

    call c_str_to_fortran(file(1:file_len), file_len, f_file)
    call assert_equal(int(x, 4), int(y, 4), trim(f_file), line, &
                      suite_registry(handle))

  end subroutine fut_assert_equal_int32

  subroutine fut_assert_equal_real64(handle, x, y, file, file_len, line) &
      bind(C, name="fut_assert_equal_real64")

    integer(c_int), value, intent(in) :: handle, file_len, line
    real(c_double), value, intent(in) :: x, y
    character(kind=c_char), intent(in) :: file(*)

    character(256) :: f_file

    call c_str_to_fortran(file(1:file_len), file_len, f_file)
    call assert_equal(real(x, 8), real(y, 8), trim(f_file), line, &
                      suite_registry(handle))

  end subroutine fut_assert_equal_real64

  subroutine fut_assert_approximate_real64(handle, x, y, eps, file, file_len, line) &
      bind(C, name="fut_assert_approximate_real64")

    integer(c_int), value, intent(in) :: handle, file_len, line
    real(c_double), value, intent(in) :: x, y, eps
    character(kind=c_char), intent(in) :: file(*)

    character(256) :: f_file

    call c_str_to_fortran(file(1:file_len), file_len, f_file)
    call assert_approximate(real(x, 8), real(y, 8), trim(f_file), line, &
                            real(eps, 8), suite_registry(handle))

  end subroutine fut_assert_approximate_real64

  subroutine fut_assert_approximate_real32(handle, x, y, eps, file, file_len, line) &
      bind(C, name="fut_assert_approximate_real32")

    integer(c_int), value, intent(in) :: handle, file_len, line
    real(c_float), value, intent(in) :: x, y, eps
    character(kind=c_char), intent(in) :: file(*)

    character(256) :: f_file

    call c_str_to_fortran(file(1:file_len), file_len, f_file)
    call assert_approximate(real(x, 4), real(y, 4), trim(f_file), line, &
                            real(eps, 4), suite_registry(handle))

  end subroutine fut_assert_approximate_real32

  ! cond: 0 = false, non-zero = true (matches C boolean convention)
  subroutine fut_assert_true(handle, cond, file, file_len, line) &
      bind(C, name="fut_assert_true")

    integer(c_int), value, intent(in) :: handle, cond, file_len, line
    character(kind=c_char), intent(in) :: file(*)

    character(256) :: f_file

    call c_str_to_fortran(file(1:file_len), file_len, f_file)
    call assert_true(cond /= 0, trim(f_file), line, suite_registry(handle))

  end subroutine fut_assert_true

  subroutine fut_assert_false(handle, cond, file, file_len, line) &
      bind(C, name="fut_assert_false")

    integer(c_int), value, intent(in) :: handle, cond, file_len, line
    character(kind=c_char), intent(in) :: file(*)

    character(256) :: f_file

    call c_str_to_fortran(file(1:file_len), file_len, f_file)
    call assert_false(cond /= 0, trim(f_file), line, suite_registry(handle))

  end subroutine fut_assert_false

  subroutine fut_assert_failure(handle, file, file_len, line) &
      bind(C, name="fut_assert_failure")

    integer(c_int), value, intent(in) :: handle, file_len, line
    character(kind=c_char), intent(in) :: file(*)

    character(256) :: f_file

    call c_str_to_fortran(file(1:file_len), file_len, f_file)
    call assert_failure(trim(f_file), line, suite_registry(handle))

  end subroutine fut_assert_failure

  ! ---------------------------------------------------------------------------
  ! Query functions
  ! ---------------------------------------------------------------------------

  ! Total number of test cases registered in a suite.
  function fut_suite_num_cases(handle) result(n) &
      bind(C, name="fut_suite_num_cases")

    integer(c_int), value, intent(in) :: handle
    integer(c_int) :: n

    n = int(suite_registry(handle)%num_test_case, c_int)

  end function fut_suite_num_cases

  ! Total number of assertions recorded across all test cases in a suite.
  function fut_suite_num_assertions(handle) result(n) &
      bind(C, name="fut_suite_num_assertions")

    integer(c_int), value, intent(in) :: handle
    integer(c_int) :: n

    logical, allocatable :: results(:)

    if (suite_registry(handle)%num_test_case == 0) then
      n = 0
      return
    end if

    results = test_suite_get_assert_results(suite_registry(handle))
    n = int(size(results), c_int)

  end function fut_suite_num_assertions

  ! Number of assertions that passed across all test cases in a suite.
  function fut_suite_num_passed(handle) result(n) &
      bind(C, name="fut_suite_num_passed")

    integer(c_int), value, intent(in) :: handle
    integer(c_int) :: n

    logical, allocatable :: results(:)

    if (suite_registry(handle)%num_test_case == 0) then
      n = 0
      return
    end if

    results = test_suite_get_assert_results(suite_registry(handle))
    n = int(count(results), c_int)

  end function fut_suite_num_passed

  ! ---------------------------------------------------------------------------
  ! fut_get_suite_ptr  (Fortran-only; not bind(C))
  !
  ! Returns a Fortran pointer to the test_suite_type stored at handle so that
  ! Fortran test subroutines can call the full native FUT API on a suite that
  ! was originally created via the C handle system.
  !
  ! Typical use in a Fortran test subroutine:
  !
  !   subroutine my_fortran_tests(handle) bind(C, name="my_fortran_tests")
  !     use iso_c_binding
  !     use unit_test
  !     use fut_c_api_mod, only: fut_get_suite_ptr
  !     integer(c_int), value :: handle
  !     type(test_suite_type), pointer :: suite
  !
  !     suite => fut_get_suite_ptr(int(handle))
  !     call test_case_create('my case', suite)
  !     call assert_equal(42, 42, __FILE__, __LINE__, suite=suite)
  !   end subroutine
  ! ---------------------------------------------------------------------------
  function fut_get_suite_ptr(handle) result(ptr)

    integer, intent(in) :: handle
    type(test_suite_type), pointer :: ptr

    ptr => suite_registry(handle)

  end function fut_get_suite_ptr

end module fut_c_api_mod
