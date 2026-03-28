! physics_tests.F90 — Fortran test registry + test subroutines for
! simple_physics, written using the native FUT API.
!
! Design:
!   • All test logic stays in Fortran (assert_approximate, assert_true, …).
!   • A small registry maps integer indices to (name, procedure) pairs.
!   • Three bind(C) helpers let C++ query the registry without knowing
!     anything about individual tests:
!       physics_register_tests()          — idempotent initialisation
!       physics_num_tests()  → int        — count of registered test suites
!       physics_get_test_name(idx, …)     — name of test i (0-based)
!       physics_run_test(idx, handle)     — run test i into FUT suite handle
!
! Adding a new test = write a private subroutine + one call add_test(...).
! The C++ driver never needs to change.

module physics_test_registry
  use iso_c_binding
  use unit_test
  use fut_c_api_mod, only: fut_get_suite_ptr
  use simple_physics
  implicit none
  private

  public :: physics_register_tests
  public :: physics_num_tests
  public :: physics_get_test_name
  public :: physics_run_test

  ! Abstract interface for a test subroutine callable via C handle
  abstract interface
    subroutine test_proc_t(handle)
      import :: c_int
      integer(c_int), value :: handle
    end subroutine
  end interface

  type :: test_entry_t
    character(len=64) :: name = ''
    procedure(test_proc_t), pointer, nopass :: run => null()
  end type

  integer, parameter :: MAX_TESTS = 32
  type(test_entry_t), save :: registry(MAX_TESTS)
  integer,            save :: n_registered = 0

contains

  ! ── Registry C API ─────────────────────────────────────────────────────────

  ! Populate the registry.  Safe to call multiple times — idempotent.
  ! To add a test: write a private subroutine below, then add one
  !   call add_test("Suite Name", your_subroutine)
  ! here.  The C++ driver needs no changes.
  subroutine physics_register_tests() bind(C, name="physics_register_tests")
    if (n_registered > 0) return   ! already initialised
    call add_test("Kinetic Energy",    test_kinetic_energy)
    call add_test("Momentum",          test_momentum)
    call add_test("Elastic Collision", test_elastic_collision)
    call add_test("Potential Energy",  test_potential_energy)
  end subroutine physics_register_tests

  function physics_num_tests() result(n) bind(C, name="physics_num_tests")
    integer(c_int) :: n
    n = int(n_registered, c_int)
  end function physics_num_tests

  subroutine physics_get_test_name(idx, buf, buf_len) &
      bind(C, name="physics_get_test_name")
    integer(c_int),          value,  intent(in)  :: idx      ! 0-based
    character(kind=c_char),          intent(out) :: buf(*)
    integer(c_int),                  intent(out) :: buf_len
    character(len=64) :: name
    integer :: i, n
    name = registry(int(idx) + 1)%name
    n    = len_trim(name)
    do i = 1, n
      buf(i) = name(i:i)
    end do
    buf(n + 1) = c_null_char
    buf_len    = int(n, c_int)
  end subroutine physics_get_test_name

  subroutine physics_run_test(idx, handle) bind(C, name="physics_run_test")
    integer(c_int), value, intent(in) :: idx, handle   ! both 0-based/handle
    call registry(int(idx) + 1)%run(handle)
  end subroutine physics_run_test

  ! ── Private helper ─────────────────────────────────────────────────────────

  subroutine add_test(name, proc)
    character(len=*),    intent(in) :: name
    procedure(test_proc_t)          :: proc
    n_registered = n_registered + 1
    registry(n_registered)%name =  trim(name)
    registry(n_registered)%run  => proc
  end subroutine add_test

  ! ── Test subroutines ───────────────────────────────────────────────────────
  ! Each accepts a C integer handle, resolves it to a FUT suite pointer, then
  ! uses the native FUT API (test_case_create / assert_*) exclusively.

  subroutine test_kinetic_energy(handle)
    integer(c_int), value :: handle
    type(test_suite_type), pointer :: s
    real(c_double) :: ke_pos, ke_neg
    real(c_double), parameter :: tol = 1.0d-10
    s => fut_get_suite_ptr(int(handle))

    call test_case_create('KE = 0.5 * m * v^2', s)
    ! 0.5 * 2 * 3^2 = 9.0
    call assert_approximate(kinetic_energy(2.0d0, 3.0d0), 9.0d0, &
        __FILE__, __LINE__, tol, s)
    ! 0.5 * 1 * 4^2 = 8.0
    call assert_approximate(kinetic_energy(1.0d0, 4.0d0), 8.0d0, &
        __FILE__, __LINE__, tol, s)
    ! 0.5 * 4 * 0.5^2 = 0.5
    call assert_approximate(kinetic_energy(4.0d0, 0.5d0), 0.5d0, &
        __FILE__, __LINE__, tol, s)

    call test_case_create('zero velocity gives zero KE', s)
    call assert_approximate(kinetic_energy(5.0d0, 0.0d0), 0.0d0, &
        __FILE__, __LINE__, tol, s)
    call assert_approximate(kinetic_energy(0.0d0, 3.0d0), 0.0d0, &
        __FILE__, __LINE__, tol, s)

    call test_case_create('KE is non-negative', s)
    ke_pos = kinetic_energy(2.0d0,  3.0d0)
    ke_neg = kinetic_energy(2.0d0, -3.0d0)   ! v^2 removes the sign
    call assert_true(ke_pos >= 0.0d0, __FILE__, __LINE__, s)
    call assert_true(ke_neg >= 0.0d0, __FILE__, __LINE__, s)
    call assert_approximate(ke_pos, ke_neg, __FILE__, __LINE__, tol, s)
  end subroutine test_kinetic_energy

  subroutine test_momentum(handle)
    integer(c_int), value :: handle
    type(test_suite_type), pointer :: s
    real(c_double), parameter :: tol = 1.0d-10
    s => fut_get_suite_ptr(int(handle))

    call test_case_create('p = m * v', s)
    call assert_approximate(momentum(2.0d0,  3.0d0),  6.0d0, &
        __FILE__, __LINE__, tol, s)
    call assert_approximate(momentum(5.0d0,  0.0d0),  0.0d0, &
        __FILE__, __LINE__, tol, s)
    call assert_approximate(momentum(1.0d0, -4.0d0), -4.0d0, &
        __FILE__, __LINE__, tol, s)

    call test_case_create('momentum is additive', s)
    call assert_approximate( &
        momentum(3.0d0, 2.0d0) + momentum(1.0d0, -1.0d0), 5.0d0, &
        __FILE__, __LINE__, tol, s)
  end subroutine test_momentum

  subroutine test_elastic_collision(handle)
    integer(c_int), value :: handle
    type(test_suite_type), pointer :: s
    real(c_double) :: m1, u1, m2, u2, v1, v2
    real(c_double) :: p_before, p_after, ke_before, ke_after
    real(c_double), parameter :: tol = 1.0d-10
    s => fut_get_suite_ptr(int(handle))

    call test_case_create('equal masses exchange velocities', s)
    v1 = elastic_v1(1.0d0, 4.0d0, 1.0d0, 0.0d0)   ! expect 0
    v2 = elastic_v2(1.0d0, 4.0d0, 1.0d0, 0.0d0)   ! expect 4
    call assert_approximate(v1, 0.0d0, __FILE__, __LINE__, tol, s)
    call assert_approximate(v2, 4.0d0, __FILE__, __LINE__, tol, s)

    call test_case_create('momentum is conserved', s)
    m1 = 3.0d0; u1 =  2.0d0
    m2 = 1.0d0; u2 = -1.0d0
    v1 = elastic_v1(m1, u1, m2, u2)
    v2 = elastic_v2(m1, u1, m2, u2)
    p_before = momentum(m1, u1) + momentum(m2, u2)
    p_after  = momentum(m1, v1) + momentum(m2, v2)
    call assert_approximate(p_before, p_after, __FILE__, __LINE__, tol, s)

    call test_case_create('kinetic energy is conserved', s)
    m1 = 2.0d0; u1 = 3.0d0
    m2 = 4.0d0; u2 = 0.0d0
    v1 = elastic_v1(m1, u1, m2, u2)
    v2 = elastic_v2(m1, u1, m2, u2)
    ke_before = kinetic_energy(m1, u1) + kinetic_energy(m2, u2)
    ke_after  = kinetic_energy(m1, v1) + kinetic_energy(m2, v2)
    call assert_approximate(ke_before, ke_after, __FILE__, __LINE__, tol, s)

    call test_case_create('heavy hits light: v2 approx 2*u1', s)
    v1 = elastic_v1(1000.0d0, 1.0d0, 1.0d0, 0.0d0)
    v2 = elastic_v2(1000.0d0, 1.0d0, 1.0d0, 0.0d0)
    call assert_true(v1 > 0.0d0, __FILE__, __LINE__, s)
    call assert_true(v2 > v1,    __FILE__, __LINE__, s)
    call assert_approximate(v2, 2.0d0, __FILE__, __LINE__, 0.01d0, s)
  end subroutine test_elastic_collision

  subroutine test_potential_energy(handle)
    integer(c_int), value :: handle
    type(test_suite_type), pointer :: s
    real(c_double), parameter :: tol = 1.0d-10, g = 9.81d0
    real(c_double) :: pe1, pe2, pe_top, ke_bottom, v_ground
    s => fut_get_suite_ptr(int(handle))

    call test_case_create('PE = m * g * h', s)
    ! 2 kg at 5 m: 2 * 9.81 * 5 = 98.1
    call assert_approximate(potential_energy(2.0d0, 5.0d0), 98.1d0, &
        __FILE__, __LINE__, tol, s)
    call assert_approximate(potential_energy(10.0d0, 0.0d0), 0.0d0, &
        __FILE__, __LINE__, tol, s)

    call test_case_create('PE is linear in height', s)
    pe1 = potential_energy(1.0d0, 1.0d0)   ! 9.81
    pe2 = potential_energy(1.0d0, 2.0d0)   ! 19.62
    call assert_approximate(pe2, 2.0d0 * pe1, __FILE__, __LINE__, tol, s)

    call test_case_create('KE at bottom = PE at top', s)
    v_ground  = sqrt(2.0d0 * g * 10.0d0)
    pe_top    = potential_energy(3.0d0, 10.0d0)
    ke_bottom = kinetic_energy(3.0d0, v_ground)
    call assert_approximate(pe_top, ke_bottom, __FILE__, __LINE__, tol, s)
  end subroutine test_potential_energy

end module physics_test_registry
