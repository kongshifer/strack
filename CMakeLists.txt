cmake_minimum_required(VERSION 3.21)

project(strack LANGUAGES Fortran)

set(CMAKE_Fortran_STANDARD 2003)
set(CMAKE_Fortran_STANDARD_REQUIRED ON)
set(CMAKE_Fortran_EXTENSIONS OFF)

if(NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

option(STRACK_ENABLE_MPI "Enable MPI support when an MPI Fortran toolchain is available" ON)

find_package(Python3 COMPONENTS Interpreter REQUIRED)
file(TO_CMAKE_PATH "${Python3_EXECUTABLE}" STRACK_PYTHON_EXECUTABLE)
find_program(STRACK_MPIFORT_EXECUTABLE NAMES mpifort mpif90 mpiifort)

set(STRACK_HAVE_MPI OFF)
set(STRACK_PARALLEL_BACKEND "serial")
if(STRACK_ENABLE_MPI)
  if(STRACK_MPIFORT_EXECUTABLE)
    set(MPI_Fortran_COMPILER "${STRACK_MPIFORT_EXECUTABLE}")
    find_package(MPI COMPONENTS Fortran QUIET)
    if(MPI_Fortran_FOUND)
      set(STRACK_HAVE_MPI ON)
      set(STRACK_PARALLEL_BACKEND "mpi")
      message(STATUS "Building strack with MPI support")
    else()
      message(STATUS "MPI Fortran wrapper was found but CMake could not configure MPI; building serial strack")
    endif()
  else()
    message(STATUS "MPI Fortran wrapper was not found on PATH; building serial strack")
  endif()
else()
  message(STATUS "MPI support disabled; building serial strack")
endif()

if(WIN32)
  set(STRACK_WINDOWS_SHELL_VALUE ".true.")
else()
  set(STRACK_WINDOWS_SHELL_VALUE ".false.")
endif()

if(STRACK_HAVE_MPI)
  set(STRACK_MPI_ENABLED_VALUE ".true.")
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/strack_parallel_mpi.f90.in
    ${CMAKE_CURRENT_BINARY_DIR}/generated/strack_parallel.f90
    @ONLY
  )
else()
  set(STRACK_MPI_ENABLED_VALUE ".false.")
  configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake/strack_parallel_serial.f90.in
    ${CMAKE_CURRENT_BINARY_DIR}/generated/strack_parallel.f90
    @ONLY
  )
endif()

configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/cmake/strack_config.f90.in
  ${CMAKE_CURRENT_BINARY_DIR}/generated/strack_config.f90
  @ONLY
)

set(STRACK_SOURCES
  ${CMAKE_CURRENT_BINARY_DIR}/generated/strack_config.f90
  ${CMAKE_CURRENT_BINARY_DIR}/generated/strack_parallel.f90
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
if(STRACK_HAVE_MPI)
  target_link_libraries(strack PRIVATE MPI::MPI_Fortran)
endif()

enable_testing()
add_test(
  NAME validation
  COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tools/run_validation.py
          --exe $<TARGET_FILE:strack>
          --repo ${CMAKE_CURRENT_SOURCE_DIR}
)
