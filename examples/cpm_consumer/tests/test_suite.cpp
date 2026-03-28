/**
 * test_suite.cpp — single-binary test suite for the simple_physics Fortran
 * library, driven by Catch2 and FUT's C++ bridge.
 *
 * Build & run:
 *   cmake -S .. -B build && cmake --build build
 *   ctest --test-dir build -V          # Option A: one test entry
 *   ctest --test-dir build -V -R "Physics::"  # Option B: per-test entries
 *
 * Each TEST_CASE creates a FutSuiteGuard (which owns a FUT suite), then one
 * or more SECTIONs, each with its own FutCaseGuard.  FUT_CHECK_ALL_PASSED
 * maps pass/fail counts into Catch2 CHECK calls so failures appear in the
 * normal Catch2 output with file and line info.
 *
 * The Fortran functions are called via their bind(C) names declared below.
 */

#include "fut_catch2.hpp"   // FutSuiteGuard, FutCaseGuard, FUT_CHECK_* macros
                            // transitively includes fut_c_api.h + catch2 headers
#include <cmath>

// ---------------------------------------------------------------------------
// Forward declarations for the bind(C) Fortran functions in simple_physics.F90
// ---------------------------------------------------------------------------
extern "C" {
    double phys_kinetic_energy(double mass, double velocity);
    double phys_momentum(double mass, double velocity);
    double phys_elastic_v1(double m1, double u1, double m2, double u2);
    double phys_elastic_v2(double m1, double u1, double m2, double u2);
    double phys_potential_energy(double mass, double height);
}

static constexpr double EPS = 1e-10;

// ---------------------------------------------------------------------------
// TEST_CASE 1 — Kinetic energy formula
// ---------------------------------------------------------------------------
TEST_CASE("Kinetic energy", "[physics][energy]") {

    FutSuiteGuard suite("Kinetic Energy Tests");

    SECTION("basic: KE = 0.5 * m * v^2") {
        FutCaseGuard cas(suite, "basic formula");

        // 0.5 * 2.0 * 3.0^2 = 9.0
        FUT_ASSERT_APPROX_EPS(suite.handle(), phys_kinetic_energy(2.0, 3.0), 9.0,  EPS);
        // 0.5 * 1.0 * 4.0^2 = 8.0
        FUT_ASSERT_APPROX_EPS(suite.handle(), phys_kinetic_energy(1.0, 4.0), 8.0,  EPS);
        // 0.5 * 4.0 * 0.5^2 = 0.5
        FUT_ASSERT_APPROX_EPS(suite.handle(), phys_kinetic_energy(4.0, 0.5), 0.5,  EPS);

        FUT_CHECK_ALL_PASSED(suite);
    }

    SECTION("zero velocity gives zero KE") {
        FutCaseGuard cas(suite, "zero velocity");

        FUT_ASSERT_APPROX_EPS(suite.handle(), phys_kinetic_energy(5.0, 0.0), 0.0,  EPS);
        FUT_ASSERT_APPROX_EPS(suite.handle(), phys_kinetic_energy(0.0, 3.0), 0.0,  EPS);

        FUT_CHECK_ALL_PASSED(suite);
    }

    SECTION("KE is non-negative") {
        FutCaseGuard cas(suite, "non-negative");

        double ke_pos = phys_kinetic_energy(2.0,  3.0);
        double ke_neg = phys_kinetic_energy(2.0, -3.0); // v^2 makes sign irrelevant

        FUT_ASSERT_TRUE(suite.handle(), ke_pos >= 0.0);
        FUT_ASSERT_TRUE(suite.handle(), ke_neg >= 0.0);
        FUT_ASSERT_APPROX_EPS(suite.handle(), ke_pos, ke_neg, EPS); // same magnitude

        FUT_CHECK_ALL_PASSED(suite);
    }
}

// ---------------------------------------------------------------------------
// TEST_CASE 2 — Momentum
// ---------------------------------------------------------------------------
TEST_CASE("Momentum", "[physics][momentum]") {

    FutSuiteGuard suite("Momentum Tests");

    SECTION("basic: p = m * v") {
        FutCaseGuard cas(suite, "basic formula");

        FUT_ASSERT_APPROX_EPS(suite.handle(), phys_momentum(2.0, 3.0),  6.0, EPS);
        FUT_ASSERT_APPROX_EPS(suite.handle(), phys_momentum(5.0, 0.0),  0.0, EPS);
        FUT_ASSERT_APPROX_EPS(suite.handle(), phys_momentum(1.0, -4.0), -4.0, EPS);

        FUT_CHECK_ALL_PASSED(suite);
    }
}

// ---------------------------------------------------------------------------
// TEST_CASE 3 — 1-D elastic collision: conservation laws
// ---------------------------------------------------------------------------
TEST_CASE("Elastic collision", "[physics][collision]") {

    FutSuiteGuard suite("Elastic Collision Tests");

    SECTION("equal masses exchange velocities") {
        FutCaseGuard cas(suite, "equal mass exchange");

        // Ball 1 (m=1, u=4) hits stationary ball 2 (m=1, u=0)
        double v1 = phys_elastic_v1(1.0, 4.0, 1.0, 0.0);  // expect 0
        double v2 = phys_elastic_v2(1.0, 4.0, 1.0, 0.0);  // expect 4

        FUT_ASSERT_APPROX_EPS(suite.handle(), v1, 0.0, EPS);
        FUT_ASSERT_APPROX_EPS(suite.handle(), v2, 4.0, EPS);

        FUT_CHECK_ALL_PASSED(suite);
    }

    SECTION("momentum is conserved") {
        FutCaseGuard cas(suite, "momentum conservation");

        double m1 = 3.0, u1 =  2.0;
        double m2 = 1.0, u2 = -1.0;

        double v1 = phys_elastic_v1(m1, u1, m2, u2);
        double v2 = phys_elastic_v2(m1, u1, m2, u2);

        double p_before = phys_momentum(m1, u1) + phys_momentum(m2, u2);
        double p_after  = phys_momentum(m1, v1) + phys_momentum(m2, v2);

        FUT_ASSERT_APPROX_EPS(suite.handle(), p_before, p_after, EPS);

        FUT_CHECK_ALL_PASSED(suite);
    }

    SECTION("kinetic energy is conserved") {
        FutCaseGuard cas(suite, "energy conservation");

        double m1 = 2.0, u1 = 3.0;
        double m2 = 4.0, u2 = 0.0;

        double v1 = phys_elastic_v1(m1, u1, m2, u2);
        double v2 = phys_elastic_v2(m1, u1, m2, u2);

        double ke_before = phys_kinetic_energy(m1, u1) + phys_kinetic_energy(m2, u2);
        double ke_after  = phys_kinetic_energy(m1, v1) + phys_kinetic_energy(m2, v2);

        FUT_ASSERT_APPROX_EPS(suite.handle(), ke_before, ke_after, EPS);

        FUT_CHECK_ALL_PASSED(suite);
    }

    SECTION("heavy object hits light stationary object") {
        FutCaseGuard cas(suite, "heavy hits light");

        // Very heavy object barely slows; light object flies forward at ~2x speed
        double m1 = 1000.0, u1 = 1.0;
        double m2 = 1.0,    u2 = 0.0;

        double v1 = phys_elastic_v1(m1, u1, m2, u2);
        double v2 = phys_elastic_v2(m1, u1, m2, u2);

        // v1 ≈ u1 for m1 >> m2, v2 ≈ 2*u1
        FUT_ASSERT_TRUE(suite.handle(), v1 > 0.0);     // still moving forward
        FUT_ASSERT_TRUE(suite.handle(), v2 > v1);      // light object faster
        FUT_ASSERT_APPROX_EPS(suite.handle(), v2, 2.0 * u1, 0.01); // ≈ 2*u1

        FUT_CHECK_ALL_PASSED(suite);
    }
}

// ---------------------------------------------------------------------------
// TEST_CASE 4 — Gravitational potential energy
// ---------------------------------------------------------------------------
TEST_CASE("Gravitational potential energy", "[physics][energy]") {

    FutSuiteGuard suite("Potential Energy Tests");

    SECTION("basic: PE = m * g * h  (g = 9.81)") {
        FutCaseGuard cas(suite, "basic formula");

        // 2 kg at 5 m: 2 * 9.81 * 5 = 98.1
        FUT_ASSERT_APPROX_EPS(suite.handle(), phys_potential_energy(2.0, 5.0), 98.1, EPS);
        // 0 height → 0 PE
        FUT_ASSERT_APPROX_EPS(suite.handle(), phys_potential_energy(10.0, 0.0), 0.0, EPS);

        FUT_CHECK_ALL_PASSED(suite);
    }

    SECTION("energy-height relationship is linear") {
        FutCaseGuard cas(suite, "linearity in h");

        double pe1 = phys_potential_energy(1.0, 1.0);  // 9.81
        double pe2 = phys_potential_energy(1.0, 2.0);  // 19.62

        // doubling height doubles PE
        FUT_ASSERT_APPROX_EPS(suite.handle(), pe2, 2.0 * pe1, EPS);

        FUT_CHECK_ALL_PASSED(suite);
    }

    SECTION("KE at bottom equals PE at top (energy conservation)") {
        FutCaseGuard cas(suite, "KE = PE at bottom");

        // Object dropped from height h, velocity at ground: v = sqrt(2*g*h)
        const double g = 9.81;
        const double m = 3.0, h = 10.0;
        double v_ground = std::sqrt(2.0 * g * h);

        double pe_top    = phys_potential_energy(m, h);
        double ke_bottom = phys_kinetic_energy(m, v_ground);

        FUT_ASSERT_APPROX_EPS(suite.handle(), pe_top, ke_bottom, EPS);

        FUT_CHECK_ALL_PASSED(suite);
    }
}
