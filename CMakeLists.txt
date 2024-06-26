cmake_minimum_required(VERSION 2.8)

set(CMAKE_MACOSX_RPATH ON)

project(FortranUnitTest LANGUAGES Fortran)

set(version 0.0.1)
 
if (CMAKE_Fortran_COMPILER_ID STREQUAL "GNU")
  set(CMAKE_Fortran_FLAGS "-ffree-line-length-none")
elseif (CMAKE_Fortran_COMPILER_ID STREQUAL "PGI")
endif ()
set(CMAKE_Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR})

set(sources
  src/assert_mod.F90
  src/test_common_mod.F90
  src/test_case_mod.F90
  src/test_suite_mod.F90
  src/unit_test.F90
)

get_directory_property(has_parent PARENT_DIRECTORY)

if (has_parent)
  include_directories(${CMAKE_BINARY_DIR})
endif ()

add_library(fortran_unit_test SHARED ${sources})
set_property(TARGET fortran_unit_test PROPERTY VERSION ${version})
set_property(TARGET fortran_unit_test PROPERTY SOVERSION 1)
set_property(TARGET fortran_unit_test PROPERTY Fortran_MODULE_DIRECTORY
    "${CMAKE_CURRENT_BINARY_DIR}/modules")
target_include_directories(fortran_unit_test
    PUBLIC
       $<INSTALL_INTERFACE:include>
       $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>)

if (NOT has_parent)
  add_executable(assert_test.exe src/assert_test.F90)
  target_link_libraries(assert_test.exe fortran_unit_test)
endif ()

install(TARGETS fortran_unit_test EXPORT FortranUnitTestTargets
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
)

install(DIRECTORY "${CMAKE_BINARY_DIR}/fortran_unit_test" DESTINATION include)

include(CMakePackageConfigHelpers)
write_basic_package_version_file (
  "${CMAKE_CURRENT_BINARY_DIR}/FortranUnitTest/FortranUnitTestConfigVersion.cmake"
  VERSION ${version}
  COMPATIBILITY AnyNewerVersion
)

export(EXPORT FortranUnitTestTargets
  FILE "${CMAKE_CURRENT_BINARY_DIR}/FortranUnitTest/FortranUnitTestTargets.cmake"
)
configure_file(cmake/FortranUnitTestConfig.cmake.in
  "${CMAKE_CURRENT_BINARY_DIR}/FortranUnitTest/FortranUnitTestConfig.cmake"
)

set(ConfigPackageLocation lib/cmake/FortranUnitTest)
install(EXPORT FortranUnitTestTargets
  FILE FortranUnitTestTargets.cmake
  DESTINATION ${ConfigPackageLocation}
)
install(
  FILES
    "${CMAKE_CURRENT_BINARY_DIR}/FortranUnitTest/FortranUnitTestConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/FortranUnitTest/FortranUnitTestConfigVersion.cmake"
  DESTINATION
    ${ConfigPackageLocation}
)
