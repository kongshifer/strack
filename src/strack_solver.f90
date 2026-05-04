module strack_solver
  use iso_fortran_env, only: int64
  use strack_kinds, only: dp, tiny_value
  use strack_geometry
  use strack_parallel, only: parallel_distribute_count, parallel_is_root, parallel_size, parallel_sum_int64_vector, &
    parallel_sum_real_matrix, parallel_sum_real_vector
  use strack_runtime, only: runtime_log_message, wall_time_seconds
  use strack_types
  implicit none
  private

  public :: solve_model

contains

  subroutine solve_model(model, results, log_unit)
    type(model_t), intent(in) :: model
    type(results_t), intent(inout) :: results
    integer, intent(in) :: log_unit
    integer :: nsr, ng, cycle, serial_seed, ray_seed, i, g, ray, ncell
    integer :: local_begin, local_end, local_count, active_count
    real(dp), allocatable :: flux_old(:,:), flux_new(:,:), source(:,:), delta(:,:), track(:), track_acc(:)
    real(dp), allocatable :: fixed_external(:,:), fiss_old(:), fiss_new(:)
    real(dp), allocatable :: flux_sum(:,:), flux_sumsq(:,:), cell_flux_cycle(:,:), cell_flux_sum(:,:), cell_flux_sumsq(:,:)
    real(dp) :: keff, new_keff, flux_change, f_old, f_new
    real(dp) :: keff_sum, keff_sumsq, t_solve_start, t_cycle_start, t_cycle_end, t_phase_start
    real(dp) :: tracked_time, sample_mean
    integer(int64) :: local_counters(4), cycle_counters(3)

    nsr = size(model%source_regions)
    ng = model%ngroups
    ncell = size(model%cells)
    serial_seed = model%seed

    allocate(flux_old(nsr, ng), flux_new(nsr, ng), source(nsr, ng), delta(nsr, ng), track(nsr), track_acc(nsr))
    allocate(fixed_external(nsr, ng), fiss_old(nsr), fiss_new(nsr))
    allocate(flux_sum(nsr, ng), flux_sumsq(nsr, ng))
    allocate(cell_flux_cycle(ncell, ng), cell_flux_sum(ncell, ng), cell_flux_sumsq(ncell, ng))
    allocate(results%keff_history(model%cycles))
    allocate(results%flux(nsr, ng), results%flux_mean(nsr, ng), results%flux_variance(nsr, ng), results%flux_stddev(nsr, ng), &
      results%flux_stderr(nsr, ng))
    allocate(results%source_weights(nsr))
    allocate(results%cell_flux(ncell, ng), results%cell_flux_mean(ncell, ng), results%cell_flux_variance(ncell, ng), &
      results%cell_flux_stddev(ncell, ng), results%cell_flux_stderr(ncell, ng))

    flux_old = 1.0_dp
    flux_new = 1.0_dp
    track_acc = 0.0_dp
    fixed_external = 0.0_dp
    flux_sum = 0.0_dp
    flux_sumsq = 0.0_dp
    cell_flux_sum = 0.0_dp
    cell_flux_sumsq = 0.0_dp
    results%keff_history = 0.0_dp
    results%flux = 0.0_dp
    results%flux_mean = 0.0_dp
    results%flux_variance = 0.0_dp
    results%flux_stddev = 0.0_dp
    results%flux_stderr = 0.0_dp
    results%source_weights = 0.0_dp
    results%cell_flux = 0.0_dp
    results%cell_flux_mean = 0.0_dp
    results%cell_flux_variance = 0.0_dp
    results%cell_flux_stddev = 0.0_dp
    results%cell_flux_stderr = 0.0_dp
    results%timing%simulation_total = 0.0_dp
    results%timing%transport_sweep = 0.0_dp
    results%timing%source_update = 0.0_dp
    results%timing%tally_conversion = 0.0_dp
    results%timing%mpi_source_reductions = 0.0_dp
    results%timing%other_iteration = 0.0_dp
    results%timing%inactive_cycles = 0.0_dp
    results%timing%active_cycles = 0.0_dp
    results%counters = counters_t()
    keff = 1.0_dp
    keff_sum = 0.0_dp
    keff_sumsq = 0.0_dp
    active_count = 0
    local_counters = 0_int64
    call build_fixed_external(model, fixed_external)

    t_solve_start = wall_time_seconds()
    do cycle = 1, model%cycles
      t_cycle_start = wall_time_seconds()

      t_phase_start = wall_time_seconds()
      call build_source(model, flux_old, fixed_external, keff, source)
      results%timing%source_update = results%timing%source_update + max(wall_time_seconds() - t_phase_start, 0.0_dp)

      delta = 0.0_dp
      track = 0.0_dp
      cycle_counters = 0_int64
      call parallel_distribute_count(model%particles, local_begin, local_end, local_count)
      local_counters(1) = local_counters(1) + int(local_count, int64)

      t_phase_start = wall_time_seconds()
      do ray = local_begin, local_end
        if (parallel_size() > 1) then
          ray_seed = history_seed(model%seed, cycle, ray)
        else
          ray_seed = serial_seed
        end if
        call sweep_random_ray(model, source, delta, track, ray_seed, cycle_counters)
        if (parallel_size() == 1) serial_seed = ray_seed
      end do
      results%timing%transport_sweep = results%timing%transport_sweep + max(wall_time_seconds() - t_phase_start, 0.0_dp)
      local_counters(2:4) = local_counters(2:4) + cycle_counters

      t_phase_start = wall_time_seconds()
      call parallel_sum_real_matrix(delta)
      call parallel_sum_real_vector(track)
      results%timing%mpi_source_reductions = results%timing%mpi_source_reductions + max(wall_time_seconds() - t_phase_start, 0.0_dp)

      t_phase_start = wall_time_seconds()
      do i = 1, nsr
        do g = 1, ng
          if (track(i) > tiny_value) then
            flux_new(i, g) = source(i, g) / max(model%xs(model%source_regions(i)%xs_index)%sigma_t(g), tiny_value) + &
              delta(i, g) / max(model%xs(model%source_regions(i)%xs_index)%sigma_t(g) * track(i), tiny_value)
          else
            flux_new(i, g) = flux_old(i, g)
          end if
        end do
      end do

      f_old = 0.0_dp
      f_new = 0.0_dp
      do i = 1, nsr
        fiss_old(i) = 0.0_dp
        fiss_new(i) = 0.0_dp
        do g = 1, ng
          fiss_old(i) = fiss_old(i) + model%xs(model%source_regions(i)%xs_index)%nu_sigma_f(g) * flux_old(i, g)
          fiss_new(i) = fiss_new(i) + model%xs(model%source_regions(i)%xs_index)%nu_sigma_f(g) * flux_new(i, g)
        end do
        f_old = f_old + max(track(i), 1.0_dp) * fiss_old(i)
        f_new = f_new + max(track(i), 1.0_dp) * fiss_new(i)
      end do

      if (trim(model%run_mode) == 'criticality' .and. f_old > tiny_value .and. f_new > tiny_value) then
        new_keff = keff * f_new / f_old
      else
        new_keff = 1.0_dp
      end if

      if (cycle > model%inactive) then
        active_count = active_count + 1
        track_acc = track_acc + track
        keff_sum = keff_sum + new_keff
        keff_sumsq = keff_sumsq + new_keff * new_keff
        flux_sum = flux_sum + flux_new
        flux_sumsq = flux_sumsq + flux_new * flux_new
        call collapse_cell_flux_from_state(model, flux_new, track, cell_flux_cycle)
        cell_flux_sum = cell_flux_sum + cell_flux_cycle
        cell_flux_sumsq = cell_flux_sumsq + cell_flux_cycle * cell_flux_cycle
      end if
      results%timing%tally_conversion = results%timing%tally_conversion + max(wall_time_seconds() - t_phase_start, 0.0_dp)

      flux_change = maxval(abs(flux_new - flux_old) / max(abs(flux_old), 1.0e-10_dp))
      results%keff_history(cycle) = new_keff
      if (parallel_is_root()) then
        call emit_cycle_progress(cycle, model, new_keff, flux_change, active_count, keff_sum, keff_sumsq)
      end if

      flux_old = flux_new
      keff = new_keff
      t_cycle_end = wall_time_seconds()
      if (cycle > model%inactive) then
        results%timing%active_cycles = results%timing%active_cycles + max(t_cycle_end - t_cycle_start, 0.0_dp)
      else
        results%timing%inactive_cycles = results%timing%inactive_cycles + max(t_cycle_end - t_cycle_start, 0.0_dp)
      end if
    end do

    t_phase_start = wall_time_seconds()
    call parallel_sum_int64_vector(local_counters)
    results%timing%mpi_source_reductions = results%timing%mpi_source_reductions + max(wall_time_seconds() - t_phase_start, 0.0_dp)

    results%timing%simulation_total = max(wall_time_seconds() - t_solve_start, 0.0_dp)
    tracked_time = results%timing%source_update + results%timing%transport_sweep + results%timing%tally_conversion + &
      results%timing%mpi_source_reductions
    results%timing%other_iteration = max(results%timing%simulation_total - tracked_time, 0.0_dp)

    results%keff = keff
    results%n_active_cycles = active_count
    results%flux = flux_old
    results%source_weights = track_acc
    results%converged_cycle = model%cycles
    results%geometry_search = model%geometry_search
    results%counters%total_histories = local_counters(1)
    results%counters%total_segment_integrations = local_counters(2)
    results%counters%total_surface_intersections = local_counters(3)
    results%counters%total_subdivision_crossings = local_counters(4)

    call collapse_cell_flux(model, results)

    if (active_count > 0) then
      results%keff_mean = keff_sum / real(active_count, dp)
      sample_mean = results%keff_mean
      if (active_count > 1) then
        results%keff_variance = max((keff_sumsq - real(active_count, dp) * sample_mean * sample_mean) / &
          real(active_count - 1, dp), 0.0_dp)
      else
        results%keff_variance = 0.0_dp
      end if
      results%keff_stddev = sqrt(results%keff_variance)
      results%keff_stderr = results%keff_stddev / sqrt(real(active_count, dp))

      results%flux_mean = flux_sum / real(active_count, dp)
      results%flux_variance = 0.0_dp
      if (active_count > 1) then
        results%flux_variance = max((flux_sumsq - real(active_count, dp) * results%flux_mean * results%flux_mean) / &
          real(active_count - 1, dp), 0.0_dp)
      end if
      results%flux_stddev = sqrt(results%flux_variance)
      results%flux_stderr = results%flux_stddev / sqrt(real(active_count, dp))

      results%cell_flux_mean = cell_flux_sum / real(active_count, dp)
      results%cell_flux_variance = 0.0_dp
      if (active_count > 1) then
        results%cell_flux_variance = max((cell_flux_sumsq - real(active_count, dp) * results%cell_flux_mean * results%cell_flux_mean) / &
          real(active_count - 1, dp), 0.0_dp)
      end if
      results%cell_flux_stddev = sqrt(results%cell_flux_variance)
      results%cell_flux_stderr = results%cell_flux_stddev / sqrt(real(active_count, dp))
    else
      results%keff_mean = results%keff
      results%keff_variance = 0.0_dp
      results%keff_stddev = 0.0_dp
      results%keff_stderr = 0.0_dp
      results%flux_mean = results%flux
      results%flux_variance = 0.0_dp
      results%flux_stddev = 0.0_dp
      results%flux_stderr = 0.0_dp
      results%cell_flux_mean = results%cell_flux
      results%cell_flux_variance = 0.0_dp
      results%cell_flux_stddev = 0.0_dp
      results%cell_flux_stderr = 0.0_dp
    end if
  end subroutine solve_model

  subroutine emit_cycle_progress(cycle, model, keff_value, flux_change, active_count, keff_sum, keff_sumsq)
    integer, intent(in) :: cycle, active_count
    type(model_t), intent(in) :: model
    real(dp), intent(in) :: keff_value, flux_change, keff_sum, keff_sumsq
    character(len=256) :: line
    character(len=32) :: cycle_text, stage_text, keff_text, mean_text, stderr_text, dphi_text, active_text
    real(dp) :: running_variance, running_mean, running_stderr

    write(cycle_text, '(I0,A,I0)') cycle, '/', model%cycles
    write(keff_text, '(F8.5)') keff_value
    write(dphi_text, '(ES10.2)') flux_change

    if (cycle <= model%inactive) then
      stage_text = '[inactive]'
      line = trim(cycle_text)//' '//trim(stage_text)//' keff='//trim(adjustl(keff_text))// &
        ' max_dphi='//trim(adjustl(dphi_text))
    else
      running_mean = keff_sum / real(max(active_count, 1), dp)
      if (active_count > 1) then
        running_variance = max((keff_sumsq - real(active_count, dp) * running_mean * running_mean) / &
          real(active_count - 1, dp), 0.0_dp)
      else
        running_variance = 0.0_dp
      end if
      running_stderr = sqrt(running_variance / real(max(active_count, 1), dp))
      write(active_text, '(I0)') active_count
      write(mean_text, '(F8.5)') running_mean
      write(stderr_text, '(ES10.2)') running_stderr
      stage_text = '[active '//trim(active_text)//']'
      line = trim(cycle_text)//' '//trim(stage_text)//' keff='//trim(adjustl(keff_text))// &
        ' mean='//trim(adjustl(mean_text))//' stderr='//trim(adjustl(stderr_text))// &
        ' max_dphi='//trim(adjustl(dphi_text))
    end if
    call runtime_log_message(trim(line), .true.)
  end subroutine emit_cycle_progress

  integer function history_seed(base_seed, cycle, ray)
    integer, intent(in) :: base_seed, cycle, ray
    integer(int64), parameter :: modulus = 2147483647_int64
    integer(int64), parameter :: multiplier = 48271_int64
    integer(int64), parameter :: cycle_mix = 104729_int64
    integer(int64), parameter :: ray_mix = 1299709_int64
    integer(int64) :: mixed

    mixed = int(base_seed, int64)
    mixed = mod(mixed + cycle_mix * int(cycle, int64) + ray_mix * int(ray, int64), modulus)
    mixed = mod(multiplier * mixed + 1_int64, modulus)
    if (mixed <= 0_int64) mixed = mixed + modulus - 1_int64
    history_seed = int(mixed)
  end function history_seed

  subroutine build_fixed_external(model, fixed_external)
    type(model_t), intent(in) :: model
    real(dp), intent(out) :: fixed_external(:,:)
    integer :: i, j, sr, start_idx, end_idx

    fixed_external = 0.0_dp
    do i = 1, size(model%fixed_sources)
      start_idx = model%cells(model%fixed_sources(i)%cell_index)%source_start
      end_idx = start_idx + model%cells(model%fixed_sources(i)%cell_index)%source_count - 1
      do sr = start_idx, end_idx
        do j = 1, model%ngroups
          fixed_external(sr, j) = fixed_external(sr, j) + model%fixed_sources(i)%strength * model%fixed_sources(i)%spectrum(j)
        end do
      end do
    end do
  end subroutine build_fixed_external

  subroutine build_source(model, flux, fixed_external, keff, source)
    type(model_t), intent(in) :: model
    real(dp), intent(in) :: flux(:,:), fixed_external(:,:), keff
    real(dp), intent(out) :: source(:,:)
    integer :: sr, g, gp, xs_index
    real(dp) :: fiss

    source = fixed_external
    do sr = 1, size(model%source_regions)
      xs_index = model%source_regions(sr)%xs_index
      fiss = 0.0_dp
      do gp = 1, model%ngroups
        fiss = fiss + model%xs(xs_index)%nu_sigma_f(gp) * flux(sr, gp)
      end do
      do g = 1, model%ngroups
        do gp = 1, model%ngroups
          source(sr, g) = source(sr, g) + model%xs(xs_index)%scatter(gp, g) * flux(sr, gp)
        end do
        if (trim(model%run_mode) == 'criticality') then
          source(sr, g) = source(sr, g) + model%xs(xs_index)%chi(g) * fiss / max(keff, tiny_value)
        end if
      end do
    end do
  end subroutine build_source

  subroutine sweep_random_ray(model, source, delta_acc, track_acc, seed, counters)
    type(model_t), intent(in) :: model
    real(dp), intent(in) :: source(:,:)
    real(dp), intent(inout) :: delta_acc(:,:), track_acc(:)
    integer, intent(inout) :: seed
    integer(int64), intent(inout) :: counters(3)
    real(dp) :: point(3), direction(3), psi(model%ngroups)
    integer :: source_region_index, cell_index, g
    real(dp) :: remaining
    logical :: alive, tallying, launched_from_vacuum

    call sample_ray_start(model, seed, point, direction, cell_index, source_region_index, launched_from_vacuum)
    if (launched_from_vacuum) then
      psi = 0.0_dp
    else
      do g = 1, model%ngroups
        psi(g) = source(source_region_index, g) / max(model%xs(model%source_regions(source_region_index)%xs_index)%sigma_t(g), tiny_value)
      end do
    end if

    remaining = model%distance_inactive
    tallying = .false.
    alive = .true.
    call advance_ray(model, source, point, direction, cell_index, source_region_index, psi, remaining, tallying, alive, delta_acc, track_acc, counters)

    if (alive) then
      remaining = model%distance_active
      tallying = .true.
      call advance_ray(model, source, point, direction, cell_index, source_region_index, psi, remaining, tallying, alive, delta_acc, track_acc, counters)
      if (alive .and. launched_from_vacuum) then
        remaining = huge(1.0_dp) / 100.0_dp
        call advance_ray(model, source, point, direction, cell_index, source_region_index, psi, remaining, tallying, alive, delta_acc, track_acc, counters)
      end if
    end if
  end subroutine sweep_random_ray

  subroutine advance_ray(model, source, point, direction, cell_index, source_region_index, psi, remaining, tallying, alive, delta_acc, track_acc, counters)
    type(model_t), intent(in) :: model
    real(dp), intent(in) :: source(:,:)
    real(dp), intent(inout) :: point(3), direction(3)
    integer, intent(inout) :: cell_index, source_region_index
    real(dp), intent(inout) :: psi(:)
    real(dp), intent(inout) :: remaining
    logical, intent(in) :: tallying
    logical, intent(inout) :: alive
    real(dp), intent(inout) :: delta_acc(:,:), track_acc(:)
    integer(int64), intent(inout) :: counters(3)
    real(dp) :: phys_distance, sub_distance, step, moved_point(3), epsilon_shift
    integer :: surface_index, g, xs_index
    logical :: hit_surface, hit_subdivision
    real(dp) :: sigma_t, delta, src_over_sig

    epsilon_shift = model%boundary_epsilon_shift
    do while (alive .and. remaining > 1.0e-10_dp)
      call nearest_surface_distance(model, cell_index, point, direction, phys_distance, surface_index)
      sub_distance = subdivision_distance(model%cells(cell_index), model%source_regions(source_region_index), point, direction)
      step = min(remaining, min(phys_distance, sub_distance))
      hit_surface = phys_distance <= sub_distance .and. phys_distance <= remaining
      hit_subdivision = sub_distance < phys_distance .and. sub_distance <= remaining

      if (step >= huge(1.0_dp) / 10.0_dp) step = remaining
      if (step <= 1.0e-12_dp) then
        alive = .false.
        exit
      end if

      counters(1) = counters(1) + 1_int64
      if (hit_surface) counters(2) = counters(2) + 1_int64
      if (hit_subdivision) counters(3) = counters(3) + 1_int64

      xs_index = model%source_regions(source_region_index)%xs_index
      do g = 1, model%ngroups
        sigma_t = model%xs(xs_index)%sigma_t(g)
        src_over_sig = source(source_region_index, g) / max(sigma_t, tiny_value)
        delta = (psi(g) - src_over_sig) * (1.0_dp - exp(-sigma_t * step))
        if (tallying) delta_acc(source_region_index, g) = delta_acc(source_region_index, g) + delta
        psi(g) = psi(g) - delta
      end do
      if (tallying) track_acc(source_region_index) = track_acc(source_region_index) + step

      moved_point = point + direction * step
      remaining = remaining - step

      if (hit_subdivision) then
        point = moved_point + direction * epsilon_shift
        source_region_index = locate_source_region(model, cell_index, point)
      else if (hit_surface) then
        if (trim(model%surfaces(surface_index)%boundary) == 'reflect' .or. &
            trim(model%surfaces(surface_index)%boundary) == 'reflective') then
          point = moved_point
          call reflect_direction(model%surfaces(surface_index), point, direction)
          point = point + direction * epsilon_shift
          cell_index = locate_cell(model, point, surface_index)
          if (cell_index == 0 .or. model%cells(cell_index)%is_void) alive = .false.
          if (alive) source_region_index = locate_source_region(model, cell_index, point)
        else
          point = moved_point + direction * epsilon_shift
          cell_index = locate_cell(model, point, surface_index)
          if (cell_index == 0 .or. model%cells(cell_index)%is_void) then
            alive = .false.
          else
            source_region_index = locate_source_region(model, cell_index, point)
          end if
        end if
      else
        point = moved_point
      end if
    end do
  end subroutine advance_ray

  subroutine collapse_cell_flux(model, results)
    type(model_t), intent(in) :: model
    type(results_t), intent(inout) :: results

    call collapse_cell_flux_from_state(model, results%flux, results%source_weights, results%cell_flux)
  end subroutine collapse_cell_flux

  subroutine collapse_cell_flux_from_state(model, flux, weights, cell_flux)
    type(model_t), intent(in) :: model
    real(dp), intent(in) :: flux(:,:), weights(:)
    real(dp), intent(out) :: cell_flux(:,:)
    integer :: cell_index, sr, g, start_idx, end_idx
    real(dp) :: weight_sum

    cell_flux = 0.0_dp
    do cell_index = 1, size(model%cells)
      if (model%cells(cell_index)%is_void) cycle
      start_idx = model%cells(cell_index)%source_start
      end_idx = start_idx + model%cells(cell_index)%source_count - 1
      weight_sum = sum(weights(start_idx:end_idx))
      if (weight_sum <= tiny_value) weight_sum = real(model%cells(cell_index)%source_count, dp)
      do sr = start_idx, end_idx
        do g = 1, model%ngroups
          cell_flux(cell_index, g) = cell_flux(cell_index, g) + max(weights(sr), 1.0_dp) * flux(sr, g)
        end do
      end do
      cell_flux(cell_index, :) = cell_flux(cell_index, :) / max(weight_sum, tiny_value)
    end do
  end subroutine collapse_cell_flux_from_state

end module strack_solver
