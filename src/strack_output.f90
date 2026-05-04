module strack_output
  use iso_fortran_env, only: int64
  use strack_config, only: strack_parallel_backend
  use strack_geometry, only: vacuum_surface_launch_available
  use strack_kinds, only: dp, tiny_value
  use strack_parallel, only: parallel_size
  use strack_runtime, only: runtime_clear_log_unit, runtime_log_message, runtime_set_log_unit, wall_time_seconds
  use strack_string, only: lower_string
  use strack_types
  implicit none
  private

  public :: open_log
  public :: close_log
  public :: write_input_echo
  public :: write_run_preamble
  public :: write_summary

contains

  subroutine open_log(prefix, unit_id, append)
    character(len=*), intent(in) :: prefix
    integer, intent(out) :: unit_id
    logical, intent(in), optional :: append
    logical :: do_append

    do_append = .false.
    if (present(append)) do_append = append

    if (do_append) then
      open(newunit=unit_id, file=trim(prefix)//'.out', status='unknown', position='append', action='write')
    else
      open(newunit=unit_id, file=trim(prefix)//'.out', status='replace', action='write')
    end if
    call runtime_set_log_unit(unit_id)
  end subroutine open_log

  subroutine close_log(unit_id)
    integer, intent(in) :: unit_id

    close(unit_id)
    call runtime_clear_log_unit()
  end subroutine close_log

  subroutine write_input_echo(input_path, log_unit)
    character(len=*), intent(in) :: input_path
    integer, intent(in) :: log_unit
    integer :: input_unit, ios
    character(len=1024) :: line
    logical :: first_line

    call emit_line('', .false.)
    call emit_line(section_header('INPUT ECHO'), .false.)
    call emit_line('input_path = '//trim(input_path), .false.)
    call emit_line('', .false.)

    open(newunit=input_unit, file=trim(input_path), status='old', action='read', iostat=ios)
    if (ios /= 0) then
      call emit_line('unable to echo input file contents', .true.)
      return
    end if

    first_line = .true.
    do
      read(input_unit, '(A)', iostat=ios) line
      if (ios /= 0) exit
      if (first_line) then
        call strip_utf8_bom(line)
        first_line = .false.
      end if
      write(log_unit, '(A)') trim(line)
    end do
    close(input_unit)
  end subroutine write_input_echo

  subroutine write_run_preamble(model, input_path, packed_path)
    type(model_t), intent(in) :: model
    character(len=*), intent(in) :: input_path, packed_path

    call emit_line('', .true.)
    call emit_line('running strack on '//trim(model%case_name), .true.)
    call emit_line(section_header('ITERATION HISTORY'), .true.)
    call emit_line('cycle progress will be printed below after each batch', .true.)
  end subroutine write_run_preamble

  subroutine write_summary(model, results, log_unit)
    type(model_t), intent(in) :: model
    type(results_t), intent(inout) :: results
    integer, intent(in) :: log_unit
    integer :: py_unit, i, nonvoid_count
    character(len=256) :: line
    real(dp) :: t_output_start, t_output_end

    t_output_start = wall_time_seconds()
    open(newunit=py_unit, file=trim(model%output_prefix)//'_results.py', status='replace', action='write')
    write(py_unit, '(A)') 'case_name = "'//trim(model%case_name)//'"'
    write(py_unit, '(A)') 'parallel_backend = "'//trim(strack_parallel_backend)//'"'
    write(py_unit, '(A,I0)') 'parallel_ranks = ', parallel_size()
    write(py_unit, '(A)') 'geometry_search = "'//trim(results%geometry_search)//'"'
    write(py_unit, '(A)') 'ray_launch_mode = "'//trim(model%ray_launch_mode)//'"'
    write(py_unit, '(A,ES18.10)') 'boundary_epsilon_shift = ', model%boundary_epsilon_shift
    write(py_unit, '(A,F18.10)') 'keff = ', results%keff
    write(py_unit, '(A,F18.10)') 'keff_mean = ', results%keff_mean
    write(py_unit, '(A,ES18.10)') 'keff_variance = ', results%keff_variance
    write(py_unit, '(A,ES18.10)') 'keff_stddev = ', results%keff_stddev
    write(py_unit, '(A,ES18.10)') 'keff_stderr = ', results%keff_stderr
    write(py_unit, '(A,I0)') 'n_active_cycles = ', results%n_active_cycles

    write(py_unit, '(A)', advance='no') 'keff_history = ['
    do i = 1, size(results%keff_history)
      if (i > 1) write(py_unit, '(A)', advance='no') ', '
      write(py_unit, '(ES18.10)', advance='no') results%keff_history(i)
    end do
    write(py_unit, '(A)') ']'

    write(py_unit, '(A)', advance='no') 'source_region_weights = ['
    do i = 1, size(results%source_weights)
      if (i > 1) write(py_unit, '(A)', advance='no') ', '
      write(py_unit, '(ES18.10)', advance='no') results%source_weights(i)
    end do
    write(py_unit, '(A)') ']'

    call write_matrix(py_unit, 'source_region_flux', results%flux)
    call write_matrix(py_unit, 'source_region_flux_mean', results%flux_mean)
    call write_matrix(py_unit, 'source_region_flux_variance', results%flux_variance)
    call write_matrix(py_unit, 'source_region_flux_stddev', results%flux_stddev)
    call write_matrix(py_unit, 'source_region_flux_stderr', results%flux_stderr)

    call write_cell_flux_dict(py_unit, model, results%cell_flux, 'cell_flux')
    call write_cell_flux_dict(py_unit, model, results%cell_flux_mean, 'cell_flux_mean')
    call write_cell_flux_dict(py_unit, model, results%cell_flux_variance, 'cell_flux_variance')
    call write_cell_flux_dict(py_unit, model, results%cell_flux_stddev, 'cell_flux_stddev')
    call write_cell_flux_dict(py_unit, model, results%cell_flux_stderr, 'cell_flux_stderr')

    write(py_unit, '(A)') 'simulation_statistics = {'
    write(py_unit, '(A,I0,A)') '  "total_iterations": ', model%cycles, ','
    write(py_unit, '(A,I0,A)') '  "inactive_iterations": ', model%inactive, ','
    write(py_unit, '(A,I0,A)') '  "active_iterations": ', results%n_active_cycles, ','
    write(py_unit, '(A,I0,A)') '  "number_of_rays_per_iteration": ', model%particles, ','
    write(py_unit, '(A,ES18.10,A)') '  "inactive_distance": ', model%distance_inactive, ','
    write(py_unit, '(A,ES18.10,A)') '  "active_distance": ', model%distance_active, ','
    write(py_unit, '(A,I0,A)') '  "source_regions": ', size(model%source_regions), ','
    write(py_unit, '(A,I0,A)') '  "source_regions_with_fixed_sources": ', count_fixed_source_regions(model), ','
    write(py_unit, '(A,I0,A)') '  "total_ray_histories": ', results%counters%total_histories, ','
    write(py_unit, '(A,I0,A)') '  "total_geometric_intersections": ', results%counters%total_surface_intersections, ','
    write(py_unit, '(A,I0,A)') '  "total_subdivision_crossings": ', results%counters%total_subdivision_crossings, ','
    write(py_unit, '(A,I0,A)') '  "total_integrations": ', results%counters%total_segment_integrations, ','
    write(py_unit, '(A)') '  "sample_method": "LCG pseudo-random",'
    write(py_unit, '(A)') '  "source_sampling_mode": "'//trim(source_sampling_mode(model))//'"'
    write(py_unit, '(A)') '}'
    t_output_end = wall_time_seconds()
    results%timing%output_write = max(t_output_end - t_output_start, 0.0_dp)

    write(py_unit, '(A)') 'timing_statistics = {'
    write(py_unit, '(A,ES18.10,A)') '  "initialization_total": ', results%timing%initialization_total, ','
    write(py_unit, '(A,ES18.10,A)') '  "xml_pack": ', results%timing%xml_pack, ','
    write(py_unit, '(A,ES18.10,A)') '  "load_model": ', results%timing%load_model, ','
    write(py_unit, '(A,ES18.10,A)') '  "input_echo": ', results%timing%input_echo, ','
    write(py_unit, '(A,ES18.10,A)') '  "simulation_total": ', results%timing%simulation_total, ','
    write(py_unit, '(A,ES18.10,A)') '  "transport_sweep": ', results%timing%transport_sweep, ','
    write(py_unit, '(A,ES18.10,A)') '  "source_update": ', results%timing%source_update, ','
    write(py_unit, '(A,ES18.10,A)') '  "tally_conversion": ', results%timing%tally_conversion, ','
    write(py_unit, '(A,ES18.10,A)') '  "mpi_source_reductions": ', results%timing%mpi_source_reductions, ','
    write(py_unit, '(A,ES18.10,A)') '  "other_iteration": ', results%timing%other_iteration, ','
    write(py_unit, '(A,ES18.10,A)') '  "inactive_cycles": ', results%timing%inactive_cycles, ','
    write(py_unit, '(A,ES18.10,A)') '  "active_cycles": ', results%timing%active_cycles, ','
    write(py_unit, '(A,ES18.10,A)') '  "output_write": ', results%timing%output_write, ','
    write(py_unit, '(A,ES18.10,A)') '  "finalization_total": ', results%timing%finalization_total
    write(py_unit, '(A)') '}'
    close(py_unit)

    call emit_line('', .true.)
    call emit_line(section_header('CALCULATION SETTINGS'), .true.)
    call emit_line('case_name = '//trim(model%case_name), .true.)
    call emit_line('input_file = '//trim(model%input_path), .true.)
    call emit_line('packed_input = '//trim(model%packed_path), .true.)
    call emit_line('parallel_backend = '//trim(strack_parallel_backend), .true.)
    write(line, '(A,I0)') 'parallel_ranks = ', parallel_size()
    call emit_line(trim(line), .true.)
    call emit_line('run_mode = '//trim(model%run_mode), .true.)
    call emit_line('geometry_search = '//trim(model%geometry_search), .true.)
    call emit_line('ray_launch_mode = '//trim(model%ray_launch_mode), .true.)
    write(line, '(A,I0)') 'spatial_dimension = ', model%spatial_dimension
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') 'energy_groups = ', model%ngroups
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') 'total_iterations = ', model%cycles
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') 'inactive_iterations = ', model%inactive
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') 'active_iterations = ', max(model%cycles - model%inactive, 0)
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') 'number_of_rays_per_iteration = ', model%particles
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6)') 'inactive_distance = ', model%distance_inactive
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6)') 'active_distance = ', model%distance_active
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6)') 'boundary_epsilon_shift = ', model%boundary_epsilon_shift
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') 'source_regions = ', size(model%source_regions)
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') 'nonvoid_cells = ', count_nonvoid_cells(model)
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') 'materials = ', size(model%materials)
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') 'fixed_source_cells = ', size(model%fixed_sources)
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') 'seed = ', model%seed
    call emit_line(trim(line), .true.)
    call emit_line('source_sampling_mode = '//trim(source_sampling_mode(model)), .true.)
    call emit_boundary_summary(model)
    call emit_ray_box(model)

    call emit_line('', .true.)
    call emit_line(section_header('SIMULATION STATISTICS'), .true.)
    write(line, '(A,I0)') ' total_iterations                  = ', model%cycles
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') ' number_of_rays_per_iteration      = ', model%particles
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') ' inactive_iterations               = ', model%inactive
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') ' active_iterations                 = ', results%n_active_cycles
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6)') ' inactive_distance                = ', model%distance_inactive
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6)') ' active_distance                  = ', model%distance_active
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') ' source_regions                    = ', size(model%source_regions)
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') ' source_regions_with_fixed_sources = ', count_fixed_source_regions(model)
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') ' total_ray_histories               = ', results%counters%total_histories
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') ' total_geometric_intersections     = ', results%counters%total_surface_intersections
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6)') '   avg_per_iteration              = ', average_per_iteration(results%counters%total_surface_intersections, model%cycles)
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6)') '   avg_per_iteration_per_sr       = ', average_per_iteration_per_sr(results%counters%total_surface_intersections, model%cycles, size(model%source_regions))
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') ' total_subdivision_crossings       = ', results%counters%total_subdivision_crossings
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') ' total_integrations                = ', results%counters%total_segment_integrations
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6)') '   avg_per_iteration              = ', average_per_iteration(results%counters%total_segment_integrations, model%cycles)
    call emit_line(trim(line), .true.)
    call emit_line(' sample_method                      = LCG pseudo-random', .true.)
    call emit_line(' source_sampling_mode               = '//trim(source_sampling_mode(model)), .true.)

    call emit_line('', .true.)
    call emit_line(section_header('TIMING STATISTICS'), .true.)
    write(line, '(A,ES14.6,A)') ' total_time_for_initialization     = ', results%timing%initialization_total, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') '   xml_pack_preprocessing          = ', results%timing%xml_pack, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') '   loading_packed_input            = ', results%timing%load_model, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') '   input_echo_only                 = ', results%timing%input_echo, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') '* total_simulation_time            = ', results%timing%simulation_total, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') '   transport_sweep_only            = ', results%timing%transport_sweep, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') '   source_update_only              = ', results%timing%source_update, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') '   tally_conversion_only           = ', results%timing%tally_conversion, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') '   mpi_source_reductions_only      = ', results%timing%mpi_source_reductions, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') '   other_iteration_routines        = ', results%timing%other_iteration, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') ' time_in_inactive_cycles           = ', results%timing%inactive_cycles, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') ' time_in_active_cycles             = ', results%timing%active_cycles, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') ' time_writing_outputs              = ', results%timing%output_write, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') ' total_time_for_finalization       = ', results%timing%finalization_total, ' seconds'
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6,A)') ' time_per_integration              = ', &
      safe_divide(results%timing%simulation_total, real(max(results%counters%total_segment_integrations, 1_int64), dp)), ' seconds'
    call emit_line(trim(line), .true.)

    call emit_line('', .true.)
    call emit_line(section_header('RESULTS'), .true.)
    write(line, '(A,F14.7,A,F12.7)') ' k-effective (active mean)         = ', results%keff_mean, ' +/- ', results%keff_stderr
    call emit_line(trim(line), .true.)
    write(line, '(A,F14.7)') ' final_iteration_keff              = ', results%keff
    call emit_line(trim(line), .true.)
    write(line, '(A,ES14.6)') ' keff_variance                     = ', results%keff_variance
    call emit_line(trim(line), .true.)
    write(line, '(A,I0)') ' active_cycles_used                = ', results%n_active_cycles
    call emit_line(trim(line), .true.)
    call emit_line(' detailed_flux_statistics            = see *_results.py', .true.)

    nonvoid_count = count_nonvoid_cells(model)
    if (nonvoid_count <= 16 .and. model%ngroups <= 8) then
      call emit_line('', .false.)
      call emit_line('cell_flux_mean_stddev =', .false.)
      do i = 1, size(model%cells)
        if (model%cells(i)%is_void) cycle
        call emit_cell_flux_line(model, results, i)
      end do
    end if

    write(log_unit, '(A)') ''
    write(log_unit, '(A,F14.7)') 'final_keff = ', results%keff
    write(log_unit, '(A,F14.7)') 'keff_mean = ', results%keff_mean
    write(log_unit, '(A,F14.7)') 'keff_stderr = ', results%keff_stderr
    write(log_unit, '(A,ES14.6)') 'keff_variance = ', results%keff_variance
    write(log_unit, '(A,I8)') 'source_regions = ', size(model%source_regions)
    write(log_unit, '(A,A)') 'geometry_search = ', trim(results%geometry_search)
    write(log_unit, '(A,A)') 'parallel_backend = ', trim(strack_parallel_backend)
    write(log_unit, '(A,I8)') 'parallel_ranks = ', parallel_size()
  end subroutine write_summary

  subroutine write_matrix(unit_id, name, values)
    integer, intent(in) :: unit_id
    character(len=*), intent(in) :: name
    real(dp), intent(in) :: values(:,:)
    integer :: i, g

    write(unit_id, '(A)') trim(name)//' = ['
    do i = 1, size(values, 1)
      write(unit_id, '(A)', advance='no') '  ['
      do g = 1, size(values, 2)
        if (g > 1) write(unit_id, '(A)', advance='no') ', '
        write(unit_id, '(ES18.10)', advance='no') values(i, g)
      end do
      if (i < size(values, 1)) then
        write(unit_id, '(A)') '],'
      else
        write(unit_id, '(A)') ']'
      end if
    end do
    write(unit_id, '(A)') ']'
  end subroutine write_matrix

  subroutine write_cell_flux_dict(unit_id, model, values, name)
    integer, intent(in) :: unit_id
    type(model_t), intent(in) :: model
    real(dp), intent(in) :: values(:,:)
    character(len=*), intent(in) :: name
    integer :: i, g

    write(unit_id, '(A)') trim(name)//' = {'
    do i = 1, size(model%cells)
      if (model%cells(i)%is_void) cycle
      write(unit_id, '(A)', advance='no') '  "'//trim(model%cells(i)%id)//'": ['
      do g = 1, model%ngroups
        if (g > 1) write(unit_id, '(A)', advance='no') ', '
        write(unit_id, '(ES18.10)', advance='no') values(i, g)
      end do
      write(unit_id, '(A)') '],'
    end do
    write(unit_id, '(A)') '}'
  end subroutine write_cell_flux_dict

  subroutine emit_boundary_summary(model)
    type(model_t), intent(in) :: model
    integer :: n_reflect, n_vacuum, n_transmission, i
    character(len=256) :: line

    n_reflect = 0
    n_vacuum = 0
    n_transmission = 0
    do i = 1, size(model%surfaces)
      select case (trim(lower_string(model%surfaces(i)%boundary)))
      case ('reflect', 'reflective')
        n_reflect = n_reflect + 1
      case ('vacuum', 'out')
        n_vacuum = n_vacuum + 1
      case default
        n_transmission = n_transmission + 1
      end select
    end do

    write(line, '(A,I0,A,I0,A,I0)') 'boundary_counts = reflect:', n_reflect, ' vacuum:', n_vacuum, ' transmission:', n_transmission
    call emit_line(trim(line), .true.)
  end subroutine emit_boundary_summary

  subroutine emit_ray_box(model)
    type(model_t), intent(in) :: model
    character(len=256) :: line

    write(line, '(A,3(1X,ES14.6))') 'ray_box_lower_left =', model%ray_lower_left
    call emit_line(trim(line), .true.)
    write(line, '(A,3(1X,ES14.6))') 'ray_box_upper_right =', model%ray_upper_right
    call emit_line(trim(line), .true.)
  end subroutine emit_ray_box

  subroutine emit_cell_flux_line(model, results, cell_index)
    type(model_t), intent(in) :: model
    type(results_t), intent(in) :: results
    integer, intent(in) :: cell_index
    character(len=512) :: line, piece
    integer :: g

    line = '  '//trim(model%cells(cell_index)%id)//' :'
    do g = 1, model%ngroups
      write(piece, '(A,I0,A,ES11.4,A,ES11.4)') ' g', g, '=', results%cell_flux_mean(cell_index, g), ' +/- ', results%cell_flux_stddev(cell_index, g)
      line = trim(line)//trim(piece)
    end do
    call emit_line(trim(line), .false.)
  end subroutine emit_cell_flux_line

  integer function count_nonvoid_cells(model)
    type(model_t), intent(in) :: model
    integer :: i

    count_nonvoid_cells = 0
    do i = 1, size(model%cells)
      if (.not. model%cells(i)%is_void) count_nonvoid_cells = count_nonvoid_cells + 1
    end do
  end function count_nonvoid_cells

  integer function count_fixed_source_regions(model)
    type(model_t), intent(in) :: model
    integer :: i

    count_fixed_source_regions = 0
    do i = 1, size(model%fixed_sources)
      if (model%fixed_sources(i)%cell_index > 0) count_fixed_source_regions = count_fixed_source_regions + model%cells(model%fixed_sources(i)%cell_index)%source_count
    end do
  end function count_fixed_source_regions

  character(len=64) function source_sampling_mode(model)
    type(model_t), intent(in) :: model

    select case (trim(model%ray_launch_mode))
    case ('volume')
      source_sampling_mode = 'volume uniform isotropic (forced)'
    case ('vacuum-surface')
      if (vacuum_surface_launch_available(model)) then
        source_sampling_mode = 'vacuum-surface cosine (forced)'
      else
        source_sampling_mode = 'vacuum-surface unavailable'
      end if
    case default
      if (vacuum_surface_launch_available(model)) then
        source_sampling_mode = 'vacuum-surface cosine (auto)'
      else
        source_sampling_mode = 'volume uniform isotropic (auto)'
      end if
    end select
  end function source_sampling_mode

  character(len=86) function section_header(title)
    character(len=*), intent(in) :: title
    section_header = '======================>     '//trim(title)//'     <======================'
  end function section_header

  real(dp) function average_per_iteration(count_value, ncycle)
    use iso_fortran_env, only: int64
    integer(int64), intent(in) :: count_value
    integer, intent(in) :: ncycle

    if (ncycle <= 0) then
      average_per_iteration = 0.0_dp
    else
      average_per_iteration = real(count_value, dp) / real(ncycle, dp)
    end if
  end function average_per_iteration

  real(dp) function average_per_iteration_per_sr(count_value, ncycle, nsr)
    use iso_fortran_env, only: int64
    integer(int64), intent(in) :: count_value
    integer, intent(in) :: ncycle, nsr

    if (ncycle <= 0 .or. nsr <= 0) then
      average_per_iteration_per_sr = 0.0_dp
    else
      average_per_iteration_per_sr = real(count_value, dp) / real(ncycle * nsr, dp)
    end if
  end function average_per_iteration_per_sr

  real(dp) function safe_divide(numerator, denominator)
    real(dp), intent(in) :: numerator, denominator

    if (abs(denominator) <= tiny_value) then
      safe_divide = 0.0_dp
    else
      safe_divide = numerator / denominator
    end if
  end function safe_divide

  subroutine emit_line(text, echo_stdout)
    character(len=*), intent(in) :: text
    logical, intent(in) :: echo_stdout

    call runtime_log_message(trim(text), echo_stdout)
  end subroutine emit_line

  subroutine strip_utf8_bom(line)
    character(len=*), intent(inout) :: line
    integer :: n

    n = len_trim(line)
    if (n < 3) return
    if (iachar(line(1:1)) == 239 .and. iachar(line(2:2)) == 187 .and. iachar(line(3:3)) == 191) then
      line = line(4:)
    end if
  end subroutine strip_utf8_bom

end module strack_output
