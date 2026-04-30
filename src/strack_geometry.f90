module strack_geometry
  use strack_kinds, only: dp, pi, tiny_value, str_len
  use strack_string, only: lower_string
  use strack_types
  implicit none
  private

  public :: locate_cell
  public :: locate_source_region
  public :: random_point_in_geometry
  public :: sample_ray_start
  public :: nearest_surface_distance
  public :: subdivision_distance
  public :: reflect_direction
  public :: point_in_cell

contains

  integer function locate_cell(model, point)
    type(model_t), intent(in) :: model
    real(dp), intent(in) :: point(3)
    integer :: i

    locate_cell = 0
    do i = 1, size(model%cells)
      if (point_in_cell(model, model%cells(i), point)) then
        locate_cell = i
        return
      end if
    end do
  end function locate_cell

  logical function point_in_cell(model, cell, point)
    type(model_t), intent(in) :: model
    type(cell_t), intent(in) :: cell
    real(dp), intent(in) :: point(3)
    logical, allocatable :: stack(:)
    integer :: top, i, surf_index
    real(dp) :: value

    allocate(stack(max(size(cell%token_type), 1)))
    top = 0
    do i = 1, size(cell%token_type)
      select case (cell%token_type(i))
      case (zone_operand)
        surf_index = abs(cell%token_value(i))
        value = surface_value(model%surfaces(surf_index), point)
        top = top + 1
        if (cell%token_value(i) > 0) then
          stack(top) = value >= -1.0e-10_dp
        else
          stack(top) = value <= 1.0e-10_dp
        end if
      case (zone_and)
        stack(top-1) = stack(top-1) .and. stack(top)
        top = top - 1
      case (zone_or)
        stack(top-1) = stack(top-1) .or. stack(top)
        top = top - 1
      case (zone_not)
        stack(top) = .not. stack(top)
      end select
    end do
    point_in_cell = stack(1)
  end function point_in_cell

  integer function locate_source_region(model, cell_index, point)
    type(model_t), intent(in) :: model
    integer, intent(in) :: cell_index
    real(dp), intent(in) :: point(3)
    type(cell_t) :: cell
    integer :: ix, iy, iz
    real(dp) :: dx, dy, dz

    cell = model%cells(cell_index)
    if (.not. cell%has_subdivision) then
      locate_source_region = cell%source_start
      return
    end if

    dx = (cell%upper_right(1) - cell%lower_left(1)) / real(cell%nx, dp)
    dy = (cell%upper_right(2) - cell%lower_left(2)) / real(cell%ny, dp)
    dz = (cell%upper_right(3) - cell%lower_left(3)) / real(cell%nz, dp)

    ix = min(cell%nx, max(1, int((point(1) - cell%lower_left(1)) / max(dx, tiny_value)) + 1))
    iy = min(cell%ny, max(1, int((point(2) - cell%lower_left(2)) / max(dy, tiny_value)) + 1))
    iz = min(cell%nz, max(1, int((point(3) - cell%lower_left(3)) / max(dz, tiny_value)) + 1))

    if (point(1) >= cell%upper_right(1)) ix = cell%nx
    if (point(2) >= cell%upper_right(2)) iy = cell%ny
    if (point(3) >= cell%upper_right(3)) iz = cell%nz

    locate_source_region = cell%source_start + (iz-1) * cell%nx * cell%ny + (iy-1) * cell%nx + ix - 1
  end function locate_source_region

  subroutine random_point_in_geometry(model, seed, point, cell_index, source_region_index)
    type(model_t), intent(in) :: model
    integer, intent(inout) :: seed
    real(dp), intent(out) :: point(3)
    integer, intent(out) :: cell_index
    integer, intent(out) :: source_region_index
    integer :: trial
    real(dp) :: midplane_z

    midplane_z = 0.5_dp * (model%ray_lower_left(3) + model%ray_upper_right(3))

    do trial = 1, 200000
      point(1) = uniform(seed, model%ray_lower_left(1), model%ray_upper_right(1))
      point(2) = uniform(seed, model%ray_lower_left(2), model%ray_upper_right(2))
      if (model%spatial_dimension == 2) then
        point(3) = midplane_z
      else
        point(3) = uniform(seed, model%ray_lower_left(3), model%ray_upper_right(3))
      end if
      cell_index = locate_cell(model, point)
      if (cell_index == 0) cycle
      if (model%cells(cell_index)%is_void) cycle
      source_region_index = locate_source_region(model, cell_index, point)
      return
    end do
    error stop 'failed to sample a point in geometry'
  end subroutine random_point_in_geometry

  subroutine sample_direction(model, seed, direction)
    type(model_t), intent(in) :: model
    integer, intent(inout) :: seed
    real(dp), intent(out) :: direction(3)
    real(dp) :: mu, phi_angle, radial

    if (model%spatial_dimension == 2) then
      phi_angle = uniform(seed, 0.0_dp, 2.0_dp * pi)
      direction = [cos(phi_angle), sin(phi_angle), 0.0_dp]
    else
      mu = uniform(seed, -1.0_dp, 1.0_dp)
      phi_angle = uniform(seed, 0.0_dp, 2.0_dp * pi)
      radial = sqrt(max(0.0_dp, 1.0_dp - mu * mu))
      direction = [radial * cos(phi_angle), radial * sin(phi_angle), mu]
    end if
  end subroutine sample_direction

  subroutine sample_ray_start(model, seed, point, direction, cell_index, source_region_index, launched_from_vacuum)
    type(model_t), intent(in) :: model
    integer, intent(inout) :: seed
    real(dp), intent(out) :: point(3)
    real(dp), intent(out) :: direction(3)
    integer, intent(out) :: cell_index
    integer, intent(out) :: source_region_index
    logical, intent(out) :: launched_from_vacuum
    logical :: has_vacuum_faces

    has_vacuum_faces = launch_from_vacuum_face(model, seed, point, direction, cell_index, source_region_index)
    launched_from_vacuum = has_vacuum_faces
    if (.not. has_vacuum_faces) then
      call random_point_in_geometry(model, seed, point, cell_index, source_region_index)
      call sample_direction(model, seed, direction)
    end if
  end subroutine sample_ray_start

  subroutine nearest_surface_distance(model, point, direction, distance, surface_index)
    type(model_t), intent(in) :: model
    real(dp), intent(in) :: point(3)
    real(dp), intent(in) :: direction(3)
    real(dp), intent(out) :: distance
    integer, intent(out) :: surface_index
    integer :: i
    real(dp) :: trial

    distance = huge(1.0_dp)
    surface_index = 0
    do i = 1, size(model%surfaces)
      trial = surface_distance(model%surfaces(i), point, direction)
      if (trial > 1.0e-10_dp .and. trial < distance) then
        distance = trial
        surface_index = i
      end if
    end do
  end subroutine nearest_surface_distance

  real(dp) function subdivision_distance(cell, source_region, point, direction)
    type(cell_t), intent(in) :: cell
    type(source_region_t), intent(in) :: source_region
    real(dp), intent(in) :: point(3)
    real(dp), intent(in) :: direction(3)
    real(dp) :: dx, dy, dz, trial

    subdivision_distance = huge(1.0_dp)
    if (.not. cell%has_subdivision) return

    dx = (cell%upper_right(1) - cell%lower_left(1)) / real(cell%nx, dp)
    dy = (cell%upper_right(2) - cell%lower_left(2)) / real(cell%ny, dp)
    dz = (cell%upper_right(3) - cell%lower_left(3)) / real(cell%nz, dp)

    call plane_distance(point(1), direction(1), source_region%ix, cell%nx, cell%lower_left(1), dx, trial)
    subdivision_distance = min(subdivision_distance, trial)
    call plane_distance(point(2), direction(2), source_region%iy, cell%ny, cell%lower_left(2), dy, trial)
    subdivision_distance = min(subdivision_distance, trial)
    call plane_distance(point(3), direction(3), source_region%iz, cell%nz, cell%lower_left(3), dz, trial)
    subdivision_distance = min(subdivision_distance, trial)
  end function subdivision_distance

  subroutine reflect_direction(surface, point, direction)
    type(surface_t), intent(in) :: surface
    real(dp), intent(in) :: point(3)
    real(dp), intent(inout) :: direction(3)
    real(dp) :: normal(3), norm_value, projection

    normal = surface_normal(surface, point)
    norm_value = sqrt(sum(normal * normal))
    if (norm_value <= tiny_value) return
    normal = normal / norm_value
    projection = sum(direction * normal)
    direction = direction - 2.0_dp * projection * normal
  end subroutine reflect_direction

  real(dp) function surface_value(surface, point)
    type(surface_t), intent(in) :: surface
    real(dp), intent(in) :: point(3)
    character(len=str_len) :: stype

    stype = lower_string(trim(surface%surface_type))
    select case (trim(stype))
    case ('x-plane', 'plane-x')
      surface_value = point(1) - surface%coeffs(1)
    case ('y-plane', 'plane-y')
      surface_value = point(2) - surface%coeffs(1)
    case ('z-plane', 'plane-z')
      surface_value = point(3) - surface%coeffs(1)
    case ('z-cylinder', 'cylinder-z')
      surface_value = (point(1) - surface%coeffs(1))**2 + (point(2) - surface%coeffs(2))**2 - surface%coeffs(3)**2
    case ('x-cylinder', 'cylinder-x')
      surface_value = (point(2) - surface%coeffs(1))**2 + (point(3) - surface%coeffs(2))**2 - surface%coeffs(3)**2
    case ('y-cylinder', 'cylinder-y')
      surface_value = (point(1) - surface%coeffs(1))**2 + (point(3) - surface%coeffs(2))**2 - surface%coeffs(3)**2
    case ('sphere')
      surface_value = (point(1) - surface%coeffs(1))**2 + (point(2) - surface%coeffs(2))**2 + &
        (point(3) - surface%coeffs(3))**2 - surface%coeffs(4)**2
    case default
      error stop 'unsupported surface type'
    end select
  end function surface_value

  real(dp) function surface_distance(surface, point, direction)
    type(surface_t), intent(in) :: surface
    real(dp), intent(in) :: point(3), direction(3)
    character(len=str_len) :: stype
    real(dp) :: a, b, c, disc, root1, root2

    stype = lower_string(trim(surface%surface_type))
    surface_distance = huge(1.0_dp)
    select case (trim(stype))
    case ('x-plane', 'plane-x')
      if (abs(direction(1)) > tiny_value) surface_distance = (surface%coeffs(1) - point(1)) / direction(1)
    case ('y-plane', 'plane-y')
      if (abs(direction(2)) > tiny_value) surface_distance = (surface%coeffs(1) - point(2)) / direction(2)
    case ('z-plane', 'plane-z')
      if (abs(direction(3)) > tiny_value) surface_distance = (surface%coeffs(1) - point(3)) / direction(3)
    case ('z-cylinder', 'cylinder-z')
      a = direction(1)**2 + direction(2)**2
      b = 2.0_dp * ((point(1) - surface%coeffs(1)) * direction(1) + (point(2) - surface%coeffs(2)) * direction(2))
      c = (point(1) - surface%coeffs(1))**2 + (point(2) - surface%coeffs(2))**2 - surface%coeffs(3)**2
      surface_distance = smallest_positive_root(a, b, c)
    case ('x-cylinder', 'cylinder-x')
      a = direction(2)**2 + direction(3)**2
      b = 2.0_dp * ((point(2) - surface%coeffs(1)) * direction(2) + (point(3) - surface%coeffs(2)) * direction(3))
      c = (point(2) - surface%coeffs(1))**2 + (point(3) - surface%coeffs(2))**2 - surface%coeffs(3)**2
      surface_distance = smallest_positive_root(a, b, c)
    case ('y-cylinder', 'cylinder-y')
      a = direction(1)**2 + direction(3)**2
      b = 2.0_dp * ((point(1) - surface%coeffs(1)) * direction(1) + (point(3) - surface%coeffs(2)) * direction(3))
      c = (point(1) - surface%coeffs(1))**2 + (point(3) - surface%coeffs(2))**2 - surface%coeffs(3)**2
      surface_distance = smallest_positive_root(a, b, c)
    case ('sphere')
      a = sum(direction * direction)
      b = 2.0_dp * ((point(1) - surface%coeffs(1)) * direction(1) + (point(2) - surface%coeffs(2)) * direction(2) + &
                    (point(3) - surface%coeffs(3)) * direction(3))
      c = (point(1) - surface%coeffs(1))**2 + (point(2) - surface%coeffs(2))**2 + &
          (point(3) - surface%coeffs(3))**2 - surface%coeffs(4)**2
      surface_distance = smallest_positive_root(a, b, c)
    case default
      error stop 'unsupported surface type'
    end select

    if (surface_distance <= 1.0e-10_dp) surface_distance = huge(1.0_dp)
  end function surface_distance

  function surface_normal(surface, point) result(normal)
    type(surface_t), intent(in) :: surface
    real(dp), intent(in) :: point(3)
    real(dp) :: normal(3)
    character(len=str_len) :: stype

    stype = lower_string(trim(surface%surface_type))
    select case (trim(stype))
    case ('x-plane', 'plane-x')
      normal = [1.0_dp, 0.0_dp, 0.0_dp]
    case ('y-plane', 'plane-y')
      normal = [0.0_dp, 1.0_dp, 0.0_dp]
    case ('z-plane', 'plane-z')
      normal = [0.0_dp, 0.0_dp, 1.0_dp]
    case ('z-cylinder', 'cylinder-z')
      normal = [point(1) - surface%coeffs(1), point(2) - surface%coeffs(2), 0.0_dp]
    case ('x-cylinder', 'cylinder-x')
      normal = [0.0_dp, point(2) - surface%coeffs(1), point(3) - surface%coeffs(2)]
    case ('y-cylinder', 'cylinder-y')
      normal = [point(1) - surface%coeffs(1), 0.0_dp, point(3) - surface%coeffs(2)]
    case ('sphere')
      normal = [point(1) - surface%coeffs(1), point(2) - surface%coeffs(2), point(3) - surface%coeffs(3)]
    case default
      error stop 'unsupported surface type'
    end select
  end function surface_normal

  subroutine plane_distance(position, direction, index, ndiv, min_pos, delta, trial)
    real(dp), intent(in) :: position, direction, min_pos, delta
    integer, intent(in) :: index, ndiv
    real(dp), intent(out) :: trial
    real(dp) :: plane_value

    trial = huge(1.0_dp)
    if (abs(direction) <= tiny_value) return

    if (direction > 0.0_dp .and. index < ndiv) then
      plane_value = min_pos + real(index, dp) * delta
      trial = (plane_value - position) / direction
    else if (direction < 0.0_dp .and. index > 1) then
      plane_value = min_pos + real(index - 1, dp) * delta
      trial = (plane_value - position) / direction
    end if

    if (trial <= 1.0e-10_dp) trial = huge(1.0_dp)
  end subroutine plane_distance

  real(dp) function smallest_positive_root(a, b, c)
    real(dp), intent(in) :: a, b, c
    real(dp) :: disc, root1, root2

    smallest_positive_root = huge(1.0_dp)
    if (abs(a) <= tiny_value) then
      if (abs(b) > tiny_value) then
        root1 = -c / b
        if (root1 > 1.0e-10_dp) smallest_positive_root = root1
      end if
      return
    end if

    disc = b * b - 4.0_dp * a * c
    if (disc < 0.0_dp) return

    root1 = (-b - sqrt(disc)) / (2.0_dp * a)
    root2 = (-b + sqrt(disc)) / (2.0_dp * a)

    if (root1 > 1.0e-10_dp) smallest_positive_root = root1
    if (root2 > 1.0e-10_dp) smallest_positive_root = min(smallest_positive_root, root2)
  end function smallest_positive_root

  real(dp) function uniform(seed, low, high)
    integer, intent(inout) :: seed
    real(dp), intent(in) :: low, high
    integer, parameter :: modulus = 2147483647, multiplier = 48271

    seed = mod(multiplier * seed, modulus)
    if (seed <= 0) seed = seed + modulus
    uniform = low + (high - low) * real(seed, dp) / real(modulus, dp)
  end function uniform

  logical function launch_from_vacuum_face(model, seed, point, direction, cell_index, source_region_index)
    type(model_t), intent(in) :: model
    integer, intent(inout) :: seed
    real(dp), intent(out) :: point(3)
    real(dp), intent(out) :: direction(3)
    integer, intent(out) :: cell_index
    integer, intent(out) :: source_region_index
    logical :: active_face(6)
    real(dp) :: face_measure(6), total_area, pick, running
    integer :: face, trial, i
    real(dp) :: mu, phi_angle, radial, eta, midplane_z
    real(dp) :: normal(3), tangent1(3), tangent2(3), eps

    launch_from_vacuum_face = .false.
    active_face = .false.
    face_measure = 0.0_dp
    eps = 1.0e-8_dp
    midplane_z = 0.5_dp * (model%ray_lower_left(3) + model%ray_upper_right(3))

    do i = 1, size(model%surfaces)
      call flag_vacuum_face(model, model%surfaces(i), active_face)
    end do

    if (model%spatial_dimension == 2) then
      active_face(5:6) = .false.
      if (active_face(1)) face_measure(1) = model%ray_upper_right(2) - model%ray_lower_left(2)
      if (active_face(2)) face_measure(2) = face_measure(1)
      if (active_face(3)) face_measure(3) = model%ray_upper_right(1) - model%ray_lower_left(1)
      if (active_face(4)) face_measure(4) = face_measure(3)
    else
      if (active_face(1)) face_measure(1) = (model%ray_upper_right(2) - model%ray_lower_left(2)) * &
                                            (model%ray_upper_right(3) - model%ray_lower_left(3))
      if (active_face(2)) face_measure(2) = face_measure(1)
      if (active_face(3)) face_measure(3) = (model%ray_upper_right(1) - model%ray_lower_left(1)) * &
                                            (model%ray_upper_right(3) - model%ray_lower_left(3))
      if (active_face(4)) face_measure(4) = face_measure(3)
      if (active_face(5)) face_measure(5) = (model%ray_upper_right(1) - model%ray_lower_left(1)) * &
                                            (model%ray_upper_right(2) - model%ray_lower_left(2))
      if (active_face(6)) face_measure(6) = face_measure(5)
    end if

    total_area = sum(face_measure)
    if (total_area <= tiny_value) return

    do trial = 1, 2000
      pick = uniform(seed, 0.0_dp, total_area)
      running = 0.0_dp
      face = 0
      do i = 1, 6
        running = running + face_measure(i)
        if (pick <= running .and. face_measure(i) > 0.0_dp) then
          face = i
          exit
        end if
      end do
      if (face == 0) cycle

      call sample_face_point(model, seed, face, point)
      if (model%spatial_dimension == 2) point(3) = midplane_z
      call face_basis(face, normal, tangent1, tangent2)
      if (model%spatial_dimension == 2) then
        eta = uniform(seed, -1.0_dp, 1.0_dp)
        mu = sqrt(max(0.0_dp, 1.0_dp - eta * eta))
        direction = mu * normal + eta * tangent1
      else
        mu = sqrt(uniform(seed, 0.0_dp, 1.0_dp))
        phi_angle = uniform(seed, 0.0_dp, 2.0_dp * pi)
        radial = sqrt(max(0.0_dp, 1.0_dp - mu * mu))
        direction = mu * normal + radial * cos(phi_angle) * tangent1 + radial * sin(phi_angle) * tangent2
      end if
      point = point + eps * normal

      cell_index = locate_cell(model, point)
      if (cell_index == 0) cycle
      if (model%cells(cell_index)%is_void) cycle
      source_region_index = locate_source_region(model, cell_index, point)
      launch_from_vacuum_face = .true.
      return
    end do
  end function launch_from_vacuum_face

  subroutine flag_vacuum_face(model, surface, active_face)
    type(model_t), intent(in) :: model
    type(surface_t), intent(in) :: surface
    logical, intent(inout) :: active_face(6)
    character(len=str_len) :: stype, boundary
    real(dp) :: coeff

    stype = lower_string(trim(surface%surface_type))
    boundary = lower_string(trim(surface%boundary))
    if (boundary /= 'vacuum' .and. boundary /= 'out') return

    coeff = surface%coeffs(1)
    select case (trim(stype))
    case ('x-plane', 'plane-x')
      if (abs(coeff - model%ray_lower_left(1)) <= 1.0e-10_dp) active_face(1) = .true.
      if (abs(coeff - model%ray_upper_right(1)) <= 1.0e-10_dp) active_face(2) = .true.
    case ('y-plane', 'plane-y')
      if (abs(coeff - model%ray_lower_left(2)) <= 1.0e-10_dp) active_face(3) = .true.
      if (abs(coeff - model%ray_upper_right(2)) <= 1.0e-10_dp) active_face(4) = .true.
    case ('z-plane', 'plane-z')
      if (abs(coeff - model%ray_lower_left(3)) <= 1.0e-10_dp) active_face(5) = .true.
      if (abs(coeff - model%ray_upper_right(3)) <= 1.0e-10_dp) active_face(6) = .true.
    end select
  end subroutine flag_vacuum_face

  subroutine sample_face_point(model, seed, face, point)
    type(model_t), intent(in) :: model
    integer, intent(inout) :: seed
    integer, intent(in) :: face
    real(dp), intent(out) :: point(3)

    select case (face)
    case (1)
      point(1) = model%ray_lower_left(1)
      point(2) = uniform(seed, model%ray_lower_left(2), model%ray_upper_right(2))
      point(3) = uniform(seed, model%ray_lower_left(3), model%ray_upper_right(3))
    case (2)
      point(1) = model%ray_upper_right(1)
      point(2) = uniform(seed, model%ray_lower_left(2), model%ray_upper_right(2))
      point(3) = uniform(seed, model%ray_lower_left(3), model%ray_upper_right(3))
    case (3)
      point(1) = uniform(seed, model%ray_lower_left(1), model%ray_upper_right(1))
      point(2) = model%ray_lower_left(2)
      point(3) = uniform(seed, model%ray_lower_left(3), model%ray_upper_right(3))
    case (4)
      point(1) = uniform(seed, model%ray_lower_left(1), model%ray_upper_right(1))
      point(2) = model%ray_upper_right(2)
      point(3) = uniform(seed, model%ray_lower_left(3), model%ray_upper_right(3))
    case (5)
      point(1) = uniform(seed, model%ray_lower_left(1), model%ray_upper_right(1))
      point(2) = uniform(seed, model%ray_lower_left(2), model%ray_upper_right(2))
      point(3) = model%ray_lower_left(3)
    case (6)
      point(1) = uniform(seed, model%ray_lower_left(1), model%ray_upper_right(1))
      point(2) = uniform(seed, model%ray_lower_left(2), model%ray_upper_right(2))
      point(3) = model%ray_upper_right(3)
    end select
  end subroutine sample_face_point

  subroutine face_basis(face, normal, tangent1, tangent2)
    integer, intent(in) :: face
    real(dp), intent(out) :: normal(3), tangent1(3), tangent2(3)

    select case (face)
    case (1)
      normal = [1.0_dp, 0.0_dp, 0.0_dp]
      tangent1 = [0.0_dp, 1.0_dp, 0.0_dp]
      tangent2 = [0.0_dp, 0.0_dp, 1.0_dp]
    case (2)
      normal = [-1.0_dp, 0.0_dp, 0.0_dp]
      tangent1 = [0.0_dp, 1.0_dp, 0.0_dp]
      tangent2 = [0.0_dp, 0.0_dp, 1.0_dp]
    case (3)
      normal = [0.0_dp, 1.0_dp, 0.0_dp]
      tangent1 = [1.0_dp, 0.0_dp, 0.0_dp]
      tangent2 = [0.0_dp, 0.0_dp, 1.0_dp]
    case (4)
      normal = [0.0_dp, -1.0_dp, 0.0_dp]
      tangent1 = [1.0_dp, 0.0_dp, 0.0_dp]
      tangent2 = [0.0_dp, 0.0_dp, 1.0_dp]
    case (5)
      normal = [0.0_dp, 0.0_dp, 1.0_dp]
      tangent1 = [1.0_dp, 0.0_dp, 0.0_dp]
      tangent2 = [0.0_dp, 1.0_dp, 0.0_dp]
    case default
      normal = [0.0_dp, 0.0_dp, -1.0_dp]
      tangent1 = [1.0_dp, 0.0_dp, 0.0_dp]
      tangent2 = [0.0_dp, 1.0_dp, 0.0_dp]
    end select
  end subroutine face_basis

end module strack_geometry
