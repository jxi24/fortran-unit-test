! physics_tests.F90 — Fortran test suites for simple_physics.
!
! All test logic is written here using the native FUT API (assert_approximate,
! assert_true, …).  The library's built-in registry handles discovery;
! no custom registry boilerplate is needed in this file.
!
! To add a test:
!   1. Write a private subroutine with signature:
!        subroutine my_test(handle) ; integer(c_int), value :: handle ; end
!   2. Add one line to register_physics_tests():
!        call fut_register_test("Suite Name", my_test)
!
! The C++ driver (test_suite.cpp) never needs to change.

module physics_tests
  use iso_c_binding
  use unit_test                          ! assert_*, test_case_create, fut_register_test, …
  use fut_c_api_mod, only: fut_get_suite_ptr
  use simple_physics
  implicit none
  private

  public :: register_physics_tests

contains

  ! ---------------------------------------------------------------------------
  ! Registration entry point — called once from the C++ driver.
  ! Add one call add_test(...) line here for every new test suite.
  ! ---------------------------------------------------------------------------
  subroutine register_physics_tests() bind(C, name="register_physics_tests")
    call fut_register_test("Kinetic Energy",    test_kinetic_energy)
    call fut_register_test("Momentum",          test_momentum)
    call fut_register_test("Elastic Collision", test_elastic_collision)
    call fut_register_test("Potential Energy",  test_potential_energy)
  end subroutine register_physics_tests

  ! ---------------------------------------------------------------------------
  ! Test subroutines — purely Fortran, no C++ knowledge required.
  ! ---------------------------------------------------------------------------

  subroutine test_kinetic_energy(handle)
    integer(c_int), value :: handle
    type(test_suite_type), pointer :: s
    real(c_double) :: ke_pos, ke_neg
    real(c_double), parameter :: tol = 1.0d-10
    s => fut_get_suite_ptr(int(handle))

    call test_case_create('KE = 0.5 * m * v^2', s)
    call assert_approximate(kinetic_energy(2.0d0, 3.0d0), 9.0d0, &
        __FILE__, __LINE__, tol, s)
    call assert_approximate(kinetic_energy(1.0d0, 4.0d0), 8.0d0, &
        __FILE__, __LINE__, tol, s)
    call assert_approximate(kinetic_energy(4.0d0, 0.5d0), 0.5d0, &
        __FILE__, __LINE__, tol, s)

    call test_case_create('zero velocity gives zero KE', s)
    call assert_approximate(kinetic_energy(5.0d0, 0.0d0), 0.0d0, &
        __FILE__, __LINE__, tol, s)
    call assert_approximate(kinetic_energy(0.0d0, 3.0d0), 0.0d0, &
        __FILE__, __LINE__, tol, s)

    call test_case_create('KE is non-negative', s)
    ke_pos = kinetic_energy(2.0d0,  3.0d0)
    ke_neg = kinetic_energy(2.0d0, -3.0d0)
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
    v1 = elastic_v1(1.0d0, 4.0d0, 1.0d0, 0.0d0)
    v2 = elastic_v2(1.0d0, 4.0d0, 1.0d0, 0.0d0)
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
    call assert_approximate(potential_energy(2.0d0, 5.0d0), 98.1d0, &
        __FILE__, __LINE__, tol, s)
    call assert_approximate(potential_energy(10.0d0, 0.0d0), 0.0d0, &
        __FILE__, __LINE__, tol, s)

    call test_case_create('PE is linear in height', s)
    pe1 = potential_energy(1.0d0, 1.0d0)
    pe2 = potential_energy(1.0d0, 2.0d0)
    call assert_approximate(pe2, 2.0d0 * pe1, __FILE__, __LINE__, tol, s)

    call test_case_create('KE at bottom = PE at top', s)
    v_ground  = sqrt(2.0d0 * g * 10.0d0)
    pe_top    = potential_energy(3.0d0, 10.0d0)
    ke_bottom = kinetic_energy(3.0d0, v_ground)
    call assert_approximate(pe_top, ke_bottom, __FILE__, __LINE__, tol, s)
  end subroutine test_potential_energy

end module physics_tests
