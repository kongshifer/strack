module strack_solver
  use strack_kinds, only: dp, tiny_value
  use strack_geometry
  use strack_types
  implicit none
  private

  public :: solve_model

contains

  subroutine solve_model(model, results, log_unit)
    type(model_t), intent(in) :: model
    type(results_t), intent(out) :: results
    integer, intent(in) :: log_unit
    integer :: nsr, ng, cycle, seed, i, g, ray
    real(dp), allocatable :: flux_old(:,:), flux_new(:,:), source(:,:), delta(:,:), track(:), track_acc(:)
    real(dp), allocatable :: fixed_external(:,:), fiss_old(:), fiss_new(:)
    real(dp) :: keff, new_keff, flux_change, f_old, f_new

    nsr = size(model%source_regions)
    ng = model%ngroups
    seed = model%seed

    allocate(flux_old(nsr, ng), flux_new(nsr, ng), source(nsr, ng), delta(nsr, ng), track(nsr), track_acc(nsr))
    allocate(fixed_external(nsr, ng), fiss_old(nsr), fiss_new(nsr))
    allocate(results%keff_history(model%cycles))
    allocate(results%flux(nsr, ng))
    allocate(results%source_weights(nsr))
    allocate(results%cell_flux(size(model%cells), ng))

    flux_old = 1.0_dp
    flux_new = 1.0_dp
    track_acc = 0.0_dp
    fixed_external = 0.0_dp
    keff = 1.0_dp
    call build_fixed_external(model, fixed_external)

    do cycle = 1, model%cycles
      call build_source(model, flux_old, fixed_external, keff, source)
      delta = 0.0_dp
      track = 0.0_dp

      do ray = 1, model%particles
        call sweep_random_ray(model, source, delta, track, seed)
      end do

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

      if (cycle > model%inactive) track_acc = track_acc + track

      if (trim(model%run_mode) == 'criticality' .and. f_old > tiny_value .and. f_new > tiny_value) then
        new_keff = keff * f_new / f_old
      else
        new_keff = 1.0_dp
      end if

      flux_change = maxval(abs(flux_new - flux_old) / max(abs(flux_old), 1.0e-10_dp))
      results%keff_history(cycle) = new_keff
      write(log_unit, '(A,I5,2(A,F14.7))') 'cycle ', cycle, '  keff=', new_keff, '  max_dphi=', flux_change

      flux_old = flux_new
      keff = new_keff
    end do

    results%keff = keff
    results%flux = flux_old
    results%source_weights = track_acc
    results%converged_cycle = model%cycles
    call collapse_cell_flux(model, results)
  end subroutine solve_model

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

  subroutine sweep_random_ray(model, source, delta_acc, track_acc, seed)
    type(model_t), intent(in) :: model
    real(dp), intent(in) :: source(:,:)
    real(dp), intent(inout) :: delta_acc(:,:), track_acc(:)
    integer, intent(inout) :: seed
    real(dp) :: point(3), direction(3), psi(model%ngroups)
    real(dp) :: remaining, segment_length, phys_distance, sub_distance
    real(dp) :: delta, src_over_sig
    integer :: cell_index, source_region_index, surface_index, g
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
    call advance_ray(model, source, point, direction, cell_index, source_region_index, psi, remaining, tallying, alive, delta_acc, track_acc)

    if (alive) then
      remaining = model%distance_active
      tallying = .true.
      call advance_ray(model, source, point, direction, cell_index, source_region_index, psi, remaining, tallying, alive, delta_acc, track_acc)
    end if
  end subroutine sweep_random_ray

  subroutine advance_ray(model, source, point, direction, cell_index, source_region_index, psi, remaining, tallying, alive, delta_acc, track_acc)
    type(model_t), intent(in) :: model
    real(dp), intent(in) :: source(:,:)
    real(dp), intent(inout) :: point(3), direction(3)
    integer, intent(inout) :: cell_index, source_region_index
    real(dp), intent(inout) :: psi(:)
    real(dp), intent(inout) :: remaining
    logical, intent(in) :: tallying
    logical, intent(inout) :: alive
    real(dp), intent(inout) :: delta_acc(:,:), track_acc(:)
    real(dp) :: phys_distance, sub_distance, step, moved_point(3), epsilon_shift
    integer :: surface_index, g, xs_index
    logical :: hit_surface, hit_subdivision
    real(dp) :: sigma_t, delta, src_over_sig

    epsilon_shift = 1.0e-8_dp
    do while (alive .and. remaining > 1.0e-10_dp)
      call nearest_surface_distance(model, point, direction, phys_distance, surface_index)
      sub_distance = subdivision_distance(model%cells(cell_index), model%source_regions(source_region_index), point, direction)
      step = min(remaining, min(phys_distance, sub_distance))
      hit_surface = phys_distance <= sub_distance .and. phys_distance <= remaining
      hit_subdivision = sub_distance < phys_distance .and. sub_distance <= remaining

      if (step >= huge(1.0_dp) / 10.0_dp) step = remaining
      if (step <= 1.0e-12_dp) then
        alive = .false.
        exit
      end if

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
          cell_index = locate_cell(model, point)
          if (cell_index == 0 .or. model%cells(cell_index)%is_void) alive = .false.
          if (alive) source_region_index = locate_source_region(model, cell_index, point)
        else
          point = moved_point + direction * epsilon_shift
          cell_index = locate_cell(model, point)
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
    integer :: cell_index, sr, g, start_idx, end_idx
    real(dp) :: weight_sum

    results%cell_flux = 0.0_dp
    do cell_index = 1, size(model%cells)
      if (model%cells(cell_index)%is_void) cycle
      start_idx = model%cells(cell_index)%source_start
      end_idx = start_idx + model%cells(cell_index)%source_count - 1
      weight_sum = sum(results%source_weights(start_idx:end_idx))
      if (weight_sum <= tiny_value) weight_sum = real(model%cells(cell_index)%source_count, dp)
      do sr = start_idx, end_idx
        do g = 1, model%ngroups
          results%cell_flux(cell_index, g) = results%cell_flux(cell_index, g) + &
            max(results%source_weights(sr), 1.0_dp) * results%flux(sr, g)
        end do
      end do
      results%cell_flux(cell_index, :) = results%cell_flux(cell_index, :) / max(weight_sum, tiny_value)
    end do
  end subroutine collapse_cell_flux

end module strack_solver
