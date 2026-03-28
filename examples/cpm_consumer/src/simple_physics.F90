! simple_physics.F90 — tiny physics library used as the "code under test"
! in the CPM consumer example.
!
! All procedures use bind(C) so they are callable directly from C++
! without a separate wrapper layer.

module simple_physics

  use iso_c_binding
  implicit none

contains

  ! kinetic energy: KE = 0.5 * m * v^2
  function kinetic_energy(mass, velocity) result(ke) &
      bind(C, name="phys_kinetic_energy")
    real(c_double), value, intent(in) :: mass, velocity
    real(c_double) :: ke
    ke = 0.5d0 * mass * velocity**2
  end function kinetic_energy

  ! linear momentum: p = m * v
  function momentum(mass, velocity) result(p) &
      bind(C, name="phys_momentum")
    real(c_double), value, intent(in) :: mass, velocity
    real(c_double) :: p
    p = mass * velocity
  end function momentum

  ! post-collision velocity for object 1 in a 1-D elastic collision:
  !   v1 = ((m1 - m2)*u1 + 2*m2*u2) / (m1 + m2)
  function elastic_v1(m1, u1, m2, u2) result(v1) &
      bind(C, name="phys_elastic_v1")
    real(c_double), value, intent(in) :: m1, u1, m2, u2
    real(c_double) :: v1
    v1 = ((m1 - m2) * u1 + 2.0d0 * m2 * u2) / (m1 + m2)
  end function elastic_v1

  ! post-collision velocity for object 2 in a 1-D elastic collision:
  !   v2 = ((m2 - m1)*u2 + 2*m1*u1) / (m1 + m2)
  function elastic_v2(m1, u1, m2, u2) result(v2) &
      bind(C, name="phys_elastic_v2")
    real(c_double), value, intent(in) :: m1, u1, m2, u2
    real(c_double) :: v2
    v2 = ((m2 - m1) * u2 + 2.0d0 * m1 * u1) / (m1 + m2)
  end function elastic_v2

  ! gravitational potential energy: PE = m * g * h  (g = 9.81 m/s^2)
  function potential_energy(mass, height) result(pe) &
      bind(C, name="phys_potential_energy")
    real(c_double), value, intent(in) :: mass, height
    real(c_double) :: pe
    real(c_double), parameter :: g = 9.81d0
    pe = mass * g * height
  end function potential_energy

end module simple_physics
