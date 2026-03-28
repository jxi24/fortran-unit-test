#include "fut_catch2.hpp"
extern "C" { void register_physics_tests(void); }
FUT_AUTO_DISCOVER_TESTS(register_physics_tests)
