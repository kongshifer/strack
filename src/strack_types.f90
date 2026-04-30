module strack_types
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
    integer :: spatial_dimension = 3
    integer :: ngroups = 0
    integer :: cycles = 0
    integer :: inactive = 0
    integer :: particles = 0
    integer :: seed = 1
    real(dp) :: distance_inactive = 0.0_dp
    real(dp) :: distance_active = 0.0_dp
    real(dp) :: ray_lower_left(3) = 0.0_dp
    real(dp) :: ray_upper_right(3) = 0.0_dp
    type(material_t), allocatable :: materials(:)
    type(xs_t), allocatable :: xs(:)
    type(surface_t), allocatable :: surfaces(:)
    type(cell_t), allocatable :: cells(:)
    type(source_region_t), allocatable :: source_regions(:)
    type(fixed_source_t), allocatable :: fixed_sources(:)
  end type model_t

  type, public :: results_t
    real(dp) :: keff = 1.0_dp
    real(dp), allocatable :: keff_history(:)
    real(dp), allocatable :: flux(:,:)
    real(dp), allocatable :: source_weights(:)
    real(dp), allocatable :: cell_flux(:,:)
    integer :: converged_cycle = 0
  end type results_t

end module strack_types
