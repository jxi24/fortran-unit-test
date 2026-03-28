! fut_test_registry_mod.F90 — global registry of named Fortran test suites.
!
! Purpose:
!   Provides a lightweight registry so users can write all test logic in
!   Fortran and let the C++/Catch2 driver discover and run them automatically,
!   without knowing their names at compile time.
!
! Fortran-side API (use unit_test):
!   call fut_register_test("Suite Name", my_test_subroutine)
!
!   The registered subroutine must match fut_test_proc_t:
!     subroutine my_test_subroutine(handle)
!       use iso_c_binding
!       integer(c_int), value :: handle
!       ...
!     end subroutine
!
! C-side API (declared in fut_c_api.h):
!   int  fut_num_registered_tests()
!   void fut_get_registered_test_name(int idx, char* buf, int* len)  ! 0-based
!   void fut_run_registered_test(int idx, int handle)                ! 0-based
!   void fut_clear_registered_tests()

module fut_test_registry_mod
  use iso_c_binding
  implicit none
  private

  ! Public Fortran API
  public :: fut_register_test
  public :: fut_test_proc_t   ! re-exported so user modules can import it

  ! Public C API (bind(C) subroutines/functions are implicitly public via
  ! their bind(C) names, but we list them here for documentation)
  public :: fut_num_registered_tests
  public :: fut_get_registered_test_name
  public :: fut_run_registered_test
  public :: fut_clear_registered_tests

  ! Abstract interface that every registered test subroutine must satisfy.
  abstract interface
    subroutine fut_test_proc_t(handle)
      import :: c_int
      integer(c_int), value :: handle
    end subroutine fut_test_proc_t
  end interface

  type :: fut_test_entry_t
    character(len=128) :: name = ''
    procedure(fut_test_proc_t), pointer, nopass :: run => null()
  end type fut_test_entry_t

  integer, parameter :: FUT_MAX_REGISTERED_TESTS = 128
  type(fut_test_entry_t), save :: registry(FUT_MAX_REGISTERED_TESTS)
  integer,                save :: n_registered = 0

contains

  !> Register a test subroutine under the given suite name.
  !> The subroutine must have the signature:
  !>   subroutine proc(handle) ; integer(c_int), value :: handle ; end subroutine
  subroutine fut_register_test(name, proc)
    character(len=*),    intent(in) :: name
    procedure(fut_test_proc_t)      :: proc
    if (n_registered >= FUT_MAX_REGISTERED_TESTS) return
    n_registered = n_registered + 1
    registry(n_registered)%name =  trim(name)
    registry(n_registered)%run  => proc
  end subroutine fut_register_test

  !> Reset the registry (useful between independent test runs).
  subroutine fut_clear_registered_tests() bind(C, name="fut_clear_registered_tests")
    n_registered = 0
  end subroutine fut_clear_registered_tests

  !> Return the number of registered test suites.
  function fut_num_registered_tests() result(n) &
      bind(C, name="fut_num_registered_tests")
    integer(c_int) :: n
    n = int(n_registered, c_int)
  end function fut_num_registered_tests

  !> Copy the name of the idx-th registered test (0-based) into buf.
  !> buf_len receives the number of characters written (not counting NUL).
  subroutine fut_get_registered_test_name(idx, buf, buf_len) &
      bind(C, name="fut_get_registered_test_name")
    integer(c_int),          value,  intent(in)  :: idx
    character(kind=c_char),          intent(out) :: buf(*)
    integer(c_int),                  intent(out) :: buf_len
    character(len=128) :: name
    integer :: i, n
    name = registry(int(idx) + 1)%name   ! C is 0-based, Fortran is 1-based
    n    = len_trim(name)
    do i = 1, n
      buf(i) = name(i:i)
    end do
    buf(n + 1) = c_null_char
    buf_len    = int(n, c_int)
  end subroutine fut_get_registered_test_name

  !> Run the idx-th registered test (0-based) into the FUT suite handle.
  subroutine fut_run_registered_test(idx, handle) &
      bind(C, name="fut_run_registered_test")
    integer(c_int), value, intent(in) :: idx, handle
    call registry(int(idx) + 1)%run(handle)
  end subroutine fut_run_registered_test

end module fut_test_registry_mod
