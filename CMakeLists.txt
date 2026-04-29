cmake_minimum_required(VERSION 3.21)

project(strack LANGUAGES Fortran)

set(CMAKE_Fortran_STANDARD 2003)
set(CMAKE_Fortran_STANDARD_REQUIRED ON)
set(CMAKE_Fortran_EXTENSIONS OFF)

configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/cmake/strack_config.f90.in
  ${CMAKE_CURRENT_BINARY_DIR}/generated/strack_config.f90
  @ONLY
)

set(STRACK_SOURCES
  ${CMAKE_CURRENT_BINARY_DIR}/generated/strack_config.f90
  src/strack_kinds.f90
  src/strack_string.f90
  src/strack_types.f90
  src/strack_input.f90
  src/strack_geometry.f90
  src/strack_solver.f90
  src/strack_output.f90
  app/strack_main.f90
)

add_executable(strack ${STRACK_SOURCES})
target_include_directories(strack PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/generated)

enable_testing()
add_test(
  NAME validation
  COMMAND py ${CMAKE_CURRENT_SOURCE_DIR}/tools/run_validation.py
          --exe $<TARGET_FILE:strack>
          --repo ${CMAKE_CURRENT_SOURCE_DIR}
)
