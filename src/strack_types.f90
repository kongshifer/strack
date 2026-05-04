module strack_types
  use iso_fortran_env, only: int64
  use strack_kinds, only: dp, str_len, path_len
  implicit none
  private

  integer, parameter, public :: zone_operand = 1
  integer, parameter, public :: zone_and = 2
  integer, parameter, public :: zone_or = 3
  integer, parameter, public :: zone_not = 4

  type, public :: surface_t
    character(len=str_len) :: id = ''
    character(len=str_len) :: surface_type = ''
    character(len=str_len) :: boundary = 'transmission'
    real(dp), allocatable :: coeffs(:)
    integer, allocatable :: candidate_cells(:)
  end type surface_t

  type, public :: xs_t
    character(len=str_len) :: id = ''
    real(dp), allocatable :: sigma_t(:)
    real(dp), allocatable :: nu_sigma_f(:)
    real(dp), allocatable :: chi(:)
    real(dp), allocatable :: scatter(:,:)
  end type xs_t

  type, public :: material_t
    character(len=str_len) :: id = ''
    character(len=str_len) :: xs_id = ''
    integer :: xs_index = 0
  end type material_t

  type, public :: cell_t
    character(len=str_len) :: id = ''
    character(len=str_len) :: material_id = ''
    integer :: material_index = 0
    integer :: xs_index = 0
    logical :: is_void = .false.
    integer, allocatable :: token_type(:)
    integer, allocatable :: token_value(:)
    logical :: has_subdivision = .false.
    integer :: nx = 1
    integer :: ny = 1
    integer :: nz = 1
    real(dp) :: lower_left(3) = 0.0_dp
    real(dp) :: upper_right(3) = 0.0_dp
    integer :: source_start = 0
    integer :: source_count = 0
    integer, allocatable :: surface_indices(:)
  end type cell_t

  type, public :: source_region_t
    integer :: cell_index = 0
    integer :: xs_index = 0
    integer :: ix = 1
    integer :: iy = 1
    integer :: iz = 1
    real(dp) :: lower_left(3) = 0.0_dp
    real(dp) :: upper_right(3) = 0.0_dp
  end type source_region_t

  type, public :: fixed_source_t
    integer :: cell_index = 0
    real(dp) :: strength = 0.0_dp
    real(dp), allocatable :: spectrum(:)
  end type fixed_source_t

  type, public :: model_t
    character(len=path_len) :: input_path = ''
    character(len=path_len) :: packed_path = ''
    character(len=path_len) :: output_prefix = ''
    character(len=path_len) :: case_name = ''
    character(len=str_len) :: run_mode = 'criticality'
    character(len=str_len) :: geometry_search = 'global'
    character(len=str_len) :: ray_launch_mode = 'auto'
    integer :: spatial_dimension = 3
    integer :: ngroups = 0
    integer :: cycles = 0
    integer :: inactive = 0
    integer :: particles = 0
    integer :: seed = 1
    real(dp) :: distance_inactive = 0.0_dp
    real(dp) :: distance_active = 0.0_dp
    real(dp) :: boundary_epsilon_shift = 1.0e-8_dp
    real(dp) :: ray_lower_left(3) = 0.0_dp
    real(dp) :: ray_upper_right(3) = 0.0_dp
    type(material_t), allocatable :: materials(:)
    type(xs_t), allocatable :: xs(:)
    type(surface_t), allocatable :: surfaces(:)
    type(cell_t), allocatable :: cells(:)
    type(source_region_t), allocatable :: source_regions(:)
    type(fixed_source_t), allocatable :: fixed_sources(:)
  end type model_t

  type, public :: timing_t
    real(dp) :: initialization_total = 0.0_dp
    real(dp) :: xml_pack = 0.0_dp
    real(dp) :: load_model = 0.0_dp
    real(dp) :: input_echo = 0.0_dp
    real(dp) :: simulation_total = 0.0_dp
    real(dp) :: transport_sweep = 0.0_dp
    real(dp) :: source_update = 0.0_dp
    real(dp) :: tally_conversion = 0.0_dp
    real(dp) :: mpi_source_reductions = 0.0_dp
    real(dp) :: other_iteration = 0.0_dp
    real(dp) :: inactive_cycles = 0.0_dp
    real(dp) :: active_cycles = 0.0_dp
    real(dp) :: output_write = 0.0_dp
    real(dp) :: finalization_total = 0.0_dp
  end type timing_t

  type, public :: counters_t
    integer(int64) :: total_histories = 0_int64
    integer(int64) :: total_segment_integrations = 0_int64
    integer(int64) :: total_surface_intersections = 0_int64
    integer(int64) :: total_subdivision_crossings = 0_int64
  end type counters_t

  type, public :: results_t
    real(dp) :: keff = 1.0_dp
    real(dp) :: keff_mean = 1.0_dp
    real(dp) :: keff_variance = 0.0_dp
    real(dp) :: keff_stddev = 0.0_dp
    real(dp) :: keff_stderr = 0.0_dp
    integer :: n_active_cycles = 0
    real(dp), allocatable :: keff_history(:)
    real(dp), allocatable :: flux(:,:)
    real(dp), allocatable :: flux_mean(:,:)
    real(dp), allocatable :: flux_variance(:,:)
    real(dp), allocatable :: flux_stddev(:,:)
    real(dp), allocatable :: flux_stderr(:,:)
    real(dp), allocatable :: source_weights(:)
    real(dp), allocatable :: cell_flux(:,:)
    real(dp), allocatable :: cell_flux_mean(:,:)
    real(dp), allocatable :: cell_flux_variance(:,:)
    real(dp), allocatable :: cell_flux_stddev(:,:)
    real(dp), allocatable :: cell_flux_stderr(:,:)
    integer :: converged_cycle = 0
    character(len=str_len) :: geometry_search = 'global'
    type(timing_t) :: timing
    type(counters_t) :: counters
  end type results_t

end module strack_types
