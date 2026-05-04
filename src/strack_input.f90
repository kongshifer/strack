module strack_input
  use strack_kinds, only: dp, str_len, path_len
  use strack_runtime, only: runtime_fail
  use strack_string, only: split_line, lower_string, basename_without_extension
  use strack_types
  implicit none
  private

  public :: load_model

contains

  subroutine load_model(packed_path, model)
    character(len=*), intent(in) :: packed_path
    type(model_t), intent(out) :: model
    integer :: unit_id, ios, line_no
    character(len=1024) :: line
    character(len=str_len), allocatable :: words(:)
    integer :: nwords

    model%packed_path = trim(packed_path)
    model%case_name = basename_without_extension(trim(packed_path))
    model%output_prefix = trim(packed_path)
    model%output_prefix = model%output_prefix(:len_trim(model%output_prefix)-8)

    line_no = 0
    open(newunit=unit_id, file=trim(packed_path), status='old', action='read', iostat=ios)
    if (ios /= 0) call runtime_fail("failed to open packed input '"//trim(packed_path)//"'", 2)

    call safe_read_line(unit_id, line, packed_path, line_no)
    if (trim(line) /= 'STRACK_INPUT_V1') call runtime_fail("invalid packed input header in '"//trim(packed_path)//"'", 2)

    do
      read(unit_id, '(A)', iostat=ios) line
      if (ios /= 0) exit
      line_no = line_no + 1
      if (len_trim(line) == 0) cycle
      call split_line(line, words, nwords)
      if (nwords == 0) cycle

      select case (trim(words(1)))
      case ('CASE')
        call require_min_words(nwords, 2, packed_path, line_no, 'CASE')
        model%case_name = trim(words(2))
      case ('RUN_MODE')
        call require_min_words(nwords, 2, packed_path, line_no, 'RUN_MODE')
        model%run_mode = lower_string(trim(words(2)))
      case ('GEOMETRY_SEARCH')
        call require_min_words(nwords, 2, packed_path, line_no, 'GEOMETRY_SEARCH')
        model%geometry_search = lower_string(trim(words(2)))
      case ('RAY_LAUNCH_MODE')
        call require_min_words(nwords, 2, packed_path, line_no, 'RAY_LAUNCH_MODE')
        model%ray_launch_mode = lower_string(trim(words(2)))
      case ('SPATIAL_DIMENSION')
        call require_min_words(nwords, 2, packed_path, line_no, 'SPATIAL_DIMENSION')
        call read_int_token(words(2), model%spatial_dimension, packed_path, line_no, 'spatial_dimension')
      case ('ENERGY_GROUPS')
        call require_min_words(nwords, 2, packed_path, line_no, 'ENERGY_GROUPS')
        call read_int_token(words(2), model%ngroups, packed_path, line_no, 'energy_groups')
      case ('CYCLE')
        call require_min_words(nwords, 2, packed_path, line_no, 'CYCLE')
        call read_int_token(words(2), model%cycles, packed_path, line_no, 'cycle')
      case ('INACTIVE')
        call require_min_words(nwords, 2, packed_path, line_no, 'INACTIVE')
        call read_int_token(words(2), model%inactive, packed_path, line_no, 'inactive')
      case ('PARTICLES')
        call require_min_words(nwords, 2, packed_path, line_no, 'PARTICLES')
        call read_int_token(words(2), model%particles, packed_path, line_no, 'particles')
      case ('DISTANCE_INACTIVE')
        call require_min_words(nwords, 2, packed_path, line_no, 'DISTANCE_INACTIVE')
        call read_real_token(words(2), model%distance_inactive, packed_path, line_no, 'distance_inactive')
      case ('DISTANCE_ACTIVE')
        call require_min_words(nwords, 2, packed_path, line_no, 'DISTANCE_ACTIVE')
        call read_real_token(words(2), model%distance_active, packed_path, line_no, 'distance_active')
      case ('BOUNDARY_EPSILON_SHIFT')
        call require_min_words(nwords, 2, packed_path, line_no, 'BOUNDARY_EPSILON_SHIFT')
        call read_real_token(words(2), model%boundary_epsilon_shift, packed_path, line_no, 'boundary_epsilon_shift')
      case ('SEED')
        call require_min_words(nwords, 2, packed_path, line_no, 'SEED')
        call read_int_token(words(2), model%seed, packed_path, line_no, 'seed')
      case ('RAY_BOX')
        call require_min_words(nwords, 7, packed_path, line_no, 'RAY_BOX')
        call read_real_token(words(2), model%ray_lower_left(1), packed_path, line_no, 'ray_box lower_left x')
        call read_real_token(words(3), model%ray_lower_left(2), packed_path, line_no, 'ray_box lower_left y')
        call read_real_token(words(4), model%ray_lower_left(3), packed_path, line_no, 'ray_box lower_left z')
        call read_real_token(words(5), model%ray_upper_right(1), packed_path, line_no, 'ray_box upper_right x')
        call read_real_token(words(6), model%ray_upper_right(2), packed_path, line_no, 'ray_box upper_right y')
        call read_real_token(words(7), model%ray_upper_right(3), packed_path, line_no, 'ray_box upper_right z')
      case ('MATERIAL_COUNT')
        call read_materials(unit_id, model, words, packed_path, line_no)
      case ('XS_COUNT')
        call read_xs(unit_id, model, words, packed_path, line_no)
      case ('SURFACE_COUNT')
        call read_surfaces(unit_id, model, words, packed_path, line_no)
      case ('CELL_COUNT')
        call read_cells(unit_id, model, words, packed_path, line_no)
      case ('FIXED_SOURCE_COUNT')
        call read_fixed_sources(unit_id, model, words, packed_path, line_no)
      case ('END_INPUT')
        exit
      case default
        call runtime_fail("unknown packed input section '"//trim(words(1))//"' in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
      end select
    end do

    close(unit_id)

    if (model%spatial_dimension /= 2 .and. model%spatial_dimension /= 3) then
      call runtime_fail("spatial_dimension must be 2 or 3 in '"//trim(packed_path)//"'", 2)
    end if
    call normalize_geometry_search(model)
    call normalize_ray_launch_mode(model)
    call validate_model_options(model)

    call resolve_materials(model)
    call build_geometry_maps(model)
    call build_source_regions(model)
  end subroutine load_model

  subroutine read_materials(unit_id, model, header_words, packed_path, line_no)
    integer, intent(in) :: unit_id
    type(model_t), intent(inout) :: model
    character(len=str_len), intent(in) :: header_words(:)
    character(len=*), intent(in) :: packed_path
    integer, intent(inout) :: line_no
    integer :: count, i
    character(len=1024) :: line
    character(len=str_len), allocatable :: words(:)
    integer :: nwords

    call require_min_words(size(header_words), 2, packed_path, line_no, 'MATERIAL_COUNT')
    call read_int_token(header_words(2), count, packed_path, line_no, 'material_count')
    allocate(model%materials(count))
    do i = 1, count
      call safe_read_line(unit_id, line, packed_path, line_no)
      call split_line(line, words, nwords)
      call require_min_words(nwords, 3, packed_path, line_no, 'MATERIAL')
      if (trim(words(1)) /= 'MATERIAL') call runtime_fail("expected MATERIAL record in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
      model%materials(i)%id = trim(words(2))
      model%materials(i)%xs_id = trim(words(3))
    end do
  end subroutine read_materials

  subroutine read_xs(unit_id, model, header_words, packed_path, line_no)
    integer, intent(in) :: unit_id
    type(model_t), intent(inout) :: model
    character(len=str_len), intent(in) :: header_words(:)
    character(len=*), intent(in) :: packed_path
    integer, intent(inout) :: line_no
    integer :: count, i, g, ng, nwords
    character(len=1024) :: line
    character(len=str_len), allocatable :: words(:)

    call require_min_words(size(header_words), 2, packed_path, line_no, 'XS_COUNT')
    call read_int_token(header_words(2), count, packed_path, line_no, 'xs_count')
    ng = model%ngroups
    allocate(model%xs(count))

    do i = 1, count
      call safe_read_line(unit_id, line, packed_path, line_no)
      call split_line(line, words, nwords)
      call require_min_words(nwords, 2, packed_path, line_no, 'XS')
      if (trim(words(1)) /= 'XS') call runtime_fail("expected XS block in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
      model%xs(i)%id = trim(words(2))
      allocate(model%xs(i)%sigma_t(ng))
      allocate(model%xs(i)%nu_sigma_f(ng))
      allocate(model%xs(i)%chi(ng))
      allocate(model%xs(i)%scatter(ng, ng))

      call safe_read_line(unit_id, line, packed_path, line_no)
      call split_line(line, words, nwords)
      call require_min_words(nwords, ng + 1, packed_path, line_no, 'TOTAL')
      if (trim(words(1)) /= 'TOTAL') call runtime_fail("expected TOTAL row in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
      do g = 1, ng
        call read_real_token(words(g+1), model%xs(i)%sigma_t(g), packed_path, line_no, 'TOTAL')
      end do

      call safe_read_line(unit_id, line, packed_path, line_no)
      call split_line(line, words, nwords)
      call require_min_words(nwords, ng + 1, packed_path, line_no, 'NU_SIGMA_F')
      if (trim(words(1)) /= 'NU_SIGMA_F') call runtime_fail("expected NU_SIGMA_F row in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
      do g = 1, ng
        call read_real_token(words(g+1), model%xs(i)%nu_sigma_f(g), packed_path, line_no, 'NU_SIGMA_F')
      end do

      call safe_read_line(unit_id, line, packed_path, line_no)
      call split_line(line, words, nwords)
      call require_min_words(nwords, ng + 1, packed_path, line_no, 'CHI')
      if (trim(words(1)) /= 'CHI') call runtime_fail("expected CHI row in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
      do g = 1, ng
        call read_real_token(words(g+1), model%xs(i)%chi(g), packed_path, line_no, 'CHI')
      end do

      do g = 1, ng
        call safe_read_line(unit_id, line, packed_path, line_no)
        call split_line(line, words, nwords)
        call require_min_words(nwords, ng + 2, packed_path, line_no, 'SCATTER_ROW')
        if (trim(words(1)) /= 'SCATTER_ROW') call runtime_fail("expected SCATTER_ROW in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
        do count = 1, ng
          call read_real_token(words(count+2), model%xs(i)%scatter(g, count), packed_path, line_no, 'SCATTER_ROW')
        end do
      end do

      call safe_read_line(unit_id, line, packed_path, line_no)
      if (trim(line) /= 'END_XS') call runtime_fail("expected END_XS in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
    end do
  end subroutine read_xs

  subroutine read_surfaces(unit_id, model, header_words, packed_path, line_no)
    integer, intent(in) :: unit_id
    type(model_t), intent(inout) :: model
    character(len=str_len), intent(in) :: header_words(:)
    character(len=*), intent(in) :: packed_path
    integer, intent(inout) :: line_no
    integer :: count, i, j, ncoeff, nwords
    character(len=1024) :: line
    character(len=str_len), allocatable :: words(:)

    call require_min_words(size(header_words), 2, packed_path, line_no, 'SURFACE_COUNT')
    call read_int_token(header_words(2), count, packed_path, line_no, 'surface_count')
    allocate(model%surfaces(count))
    do i = 1, count
      call safe_read_line(unit_id, line, packed_path, line_no)
      call split_line(line, words, nwords)
      call require_min_words(nwords, 5, packed_path, line_no, 'SURFACE')
      if (trim(words(1)) /= 'SURFACE') call runtime_fail("expected SURFACE record in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
      model%surfaces(i)%id = trim(words(2))
      model%surfaces(i)%surface_type = lower_string(trim(words(3)))
      model%surfaces(i)%boundary = lower_string(trim(words(4)))
      call read_int_token(words(5), ncoeff, packed_path, line_no, 'surface coefficient count')
      call require_min_words(nwords, 5 + ncoeff, packed_path, line_no, 'SURFACE')
      allocate(model%surfaces(i)%coeffs(ncoeff))
      do j = 1, ncoeff
        call read_real_token(words(5+j), model%surfaces(i)%coeffs(j), packed_path, line_no, 'surface coefficient')
      end do
    end do
  end subroutine read_surfaces

  subroutine read_cells(unit_id, model, header_words, packed_path, line_no)
    integer, intent(in) :: unit_id
    type(model_t), intent(inout) :: model
    character(len=str_len), intent(in) :: header_words(:)
    character(len=*), intent(in) :: packed_path
    integer, intent(inout) :: line_no
    integer :: count, i, nwords, ntokens, has_subdivision
    character(len=1024) :: line
    character(len=str_len), allocatable :: words(:)

    call require_min_words(size(header_words), 2, packed_path, line_no, 'CELL_COUNT')
    call read_int_token(header_words(2), count, packed_path, line_no, 'cell_count')
    allocate(model%cells(count))

    do i = 1, count
      call safe_read_line(unit_id, line, packed_path, line_no)
      call split_line(line, words, nwords)
      call require_min_words(nwords, 5, packed_path, line_no, 'CELL')
      if (trim(words(1)) /= 'CELL') call runtime_fail("expected CELL record in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
      model%cells(i)%id = trim(words(2))
      model%cells(i)%material_id = trim(words(3))
      call read_int_token(words(4), has_subdivision, packed_path, line_no, 'cell subdivision flag')
      call read_int_token(words(5), ntokens, packed_path, line_no, 'cell token count')
      model%cells(i)%has_subdivision = has_subdivision == 1

      call safe_read_line(unit_id, line, packed_path, line_no)
      call split_line(line, words, nwords)
      call require_min_words(nwords, ntokens + 1, packed_path, line_no, 'TOKENS')
      if (trim(words(1)) /= 'TOKENS') call runtime_fail("expected TOKENS record in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
      call parse_zone_tokens(model, words, ntokens, model%cells(i)%token_type, model%cells(i)%token_value, packed_path, line_no)

      if (model%cells(i)%has_subdivision) then
        call safe_read_line(unit_id, line, packed_path, line_no)
        call split_line(line, words, nwords)
        call require_min_words(nwords, 10, packed_path, line_no, 'SUBDIVISION')
        if (trim(words(1)) /= 'SUBDIVISION') call runtime_fail("expected SUBDIVISION record in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
        call read_int_token(words(2), model%cells(i)%nx, packed_path, line_no, 'subdivision nx')
        call read_int_token(words(3), model%cells(i)%ny, packed_path, line_no, 'subdivision ny')
        call read_int_token(words(4), model%cells(i)%nz, packed_path, line_no, 'subdivision nz')
        call read_real_token(words(5), model%cells(i)%lower_left(1), packed_path, line_no, 'subdivision lower_left x')
        call read_real_token(words(6), model%cells(i)%lower_left(2), packed_path, line_no, 'subdivision lower_left y')
        call read_real_token(words(7), model%cells(i)%lower_left(3), packed_path, line_no, 'subdivision lower_left z')
        call read_real_token(words(8), model%cells(i)%upper_right(1), packed_path, line_no, 'subdivision upper_right x')
        call read_real_token(words(9), model%cells(i)%upper_right(2), packed_path, line_no, 'subdivision upper_right y')
        call read_real_token(words(10), model%cells(i)%upper_right(3), packed_path, line_no, 'subdivision upper_right z')
      end if

      call safe_read_line(unit_id, line, packed_path, line_no)
      if (trim(line) /= 'END_CELL') call runtime_fail("expected END_CELL in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
    end do
  end subroutine read_cells

  subroutine read_fixed_sources(unit_id, model, header_words, packed_path, line_no)
    integer, intent(in) :: unit_id
    type(model_t), intent(inout) :: model
    character(len=str_len), intent(in) :: header_words(:)
    character(len=*), intent(in) :: packed_path
    integer, intent(inout) :: line_no
    integer :: count, i, g, nwords
    character(len=1024) :: line
    character(len=str_len), allocatable :: words(:)

    call require_min_words(size(header_words), 2, packed_path, line_no, 'FIXED_SOURCE_COUNT')
    call read_int_token(header_words(2), count, packed_path, line_no, 'fixed_source_count')
    allocate(model%fixed_sources(count))
    do i = 1, count
      call safe_read_line(unit_id, line, packed_path, line_no)
      call split_line(line, words, nwords)
      call require_min_words(nwords, model%ngroups + 3, packed_path, line_no, 'FIXED_SOURCE')
      if (trim(words(1)) /= 'FIXED_SOURCE') call runtime_fail("expected FIXED_SOURCE record in '"//trim(packed_path)//"' at line "//trim(to_string(line_no)), 2)
      call read_int_token(words(2), model%fixed_sources(i)%cell_index, packed_path, line_no, 'fixed_source cell index')
      call read_real_token(words(3), model%fixed_sources(i)%strength, packed_path, line_no, 'fixed_source strength')
      allocate(model%fixed_sources(i)%spectrum(model%ngroups))
      do g = 1, model%ngroups
        call read_real_token(words(3+g), model%fixed_sources(i)%spectrum(g), packed_path, line_no, 'fixed_source spectrum')
      end do
    end do
  end subroutine read_fixed_sources

  subroutine parse_zone_tokens(model, words, ntokens, token_type, token_value, packed_path, line_no)
    type(model_t), intent(in) :: model
    character(len=str_len), intent(in) :: words(:)
    integer, intent(in) :: ntokens
    integer, allocatable, intent(out) :: token_type(:)
    integer, allocatable, intent(out) :: token_value(:)
    character(len=*), intent(in) :: packed_path
    integer, intent(in) :: line_no
    integer :: i, index
    character(len=str_len) :: token

    allocate(token_type(ntokens))
    allocate(token_value(ntokens))
    do i = 1, ntokens
      token = trim(words(i+1))
      select case (trim(token))
      case ('AND')
        token_type(i) = zone_and
        token_value(i) = 0
      case ('OR')
        token_type(i) = zone_or
        token_value(i) = 0
      case ('NOT')
        token_type(i) = zone_not
        token_value(i) = 0
      case default
        token_type(i) = zone_operand
        index = find_surface(trim(token(2:)))
        if (index == 0) call runtime_fail("unknown surface in zone expression in '"//trim(packed_path)//"' at line "//trim(to_string(line_no))//": "//trim(token), 2)
        if (token(1:1) == '-') then
          token_value(i) = -index
        else
          token_value(i) = index
        end if
      end select
    end do

  contains

    integer function find_surface(surface_id)
      character(len=*), intent(in) :: surface_id
      integer :: j
      find_surface = 0
      do j = 1, size(model%surfaces)
        if (trim(model%surfaces(j)%id) == trim(surface_id)) then
          find_surface = j
          return
        end if
      end do
    end function find_surface

  end subroutine parse_zone_tokens

  subroutine resolve_materials(model)
    type(model_t), intent(inout) :: model
    integer :: i, j

    do i = 1, size(model%materials)
      model%materials(i)%xs_index = 0
      do j = 1, size(model%xs)
        if (trim(model%materials(i)%xs_id) == trim(model%xs(j)%id)) then
          model%materials(i)%xs_index = j
          exit
        end if
      end do
      if (model%materials(i)%xs_index == 0) call runtime_fail("material '"//trim(model%materials(i)%id)//"' maps to an unknown XS id", 2)
    end do

    do i = 1, size(model%cells)
      if (lower_string(trim(model%cells(i)%material_id)) == 'void') then
        model%cells(i)%is_void = .true.
        cycle
      end if
      do j = 1, size(model%materials)
        if (trim(model%cells(i)%material_id) == trim(model%materials(j)%id)) then
          model%cells(i)%material_index = j
          model%cells(i)%xs_index = model%materials(j)%xs_index
          exit
        end if
      end do
      if (model%cells(i)%xs_index == 0) call runtime_fail("cell '"//trim(model%cells(i)%id)//"' maps to an unknown material id '"//trim(model%cells(i)%material_id)//"'", 2)
    end do
  end subroutine resolve_materials

  subroutine normalize_geometry_search(model)
    type(model_t), intent(inout) :: model

    select case (trim(model%geometry_search))
    case ('global')
      continue
    case ('surface-local', 'surface_local', 'surface', 'local')
      model%geometry_search = 'surface-local'
    case default
      call runtime_fail("geometry_search must be global or surface-local", 2)
    end select
  end subroutine normalize_geometry_search

  subroutine normalize_ray_launch_mode(model)
    type(model_t), intent(inout) :: model

    select case (trim(model%ray_launch_mode))
    case ('auto')
      continue
    case ('volume', 'internal', 'body', 'body-internal', 'body_internal')
      model%ray_launch_mode = 'volume'
    case ('vacuum-surface', 'vacuum_surface', 'vacuumsurface', 'surface', 'vacuum-face', 'vacuum_face')
      model%ray_launch_mode = 'vacuum-surface'
    case default
      call runtime_fail("ray_launch_mode must be auto, volume, or vacuum-surface", 2)
    end select
  end subroutine normalize_ray_launch_mode

  subroutine build_geometry_maps(model)
    type(model_t), intent(inout) :: model
    logical, allocatable :: seen(:)
    integer, allocatable :: counts(:), temp(:)
    integer :: i, j, n, surf_index, pos

    if (.not. allocated(model%surfaces)) return
    if (.not. allocated(model%cells)) return

    allocate(seen(size(model%surfaces)))
    allocate(counts(size(model%surfaces)))
    counts = 0

    do i = 1, size(model%cells)
      seen = .false.
      allocate(temp(size(model%cells(i)%token_value)))
      n = 0
      do j = 1, size(model%cells(i)%token_type)
        if (model%cells(i)%token_type(j) /= zone_operand) cycle
        surf_index = abs(model%cells(i)%token_value(j))
        if (seen(surf_index)) cycle
        seen(surf_index) = .true.
        n = n + 1
        temp(n) = surf_index
        counts(surf_index) = counts(surf_index) + 1
      end do
      allocate(model%cells(i)%surface_indices(n))
      if (n > 0) model%cells(i)%surface_indices = temp(:n)
      deallocate(temp)
    end do

    do i = 1, size(model%surfaces)
      allocate(model%surfaces(i)%candidate_cells(counts(i)))
    end do

    counts = 0
    do i = 1, size(model%cells)
      do j = 1, size(model%cells(i)%surface_indices)
        surf_index = model%cells(i)%surface_indices(j)
        counts(surf_index) = counts(surf_index) + 1
        pos = counts(surf_index)
        model%surfaces(surf_index)%candidate_cells(pos) = i
      end do
    end do
  end subroutine build_geometry_maps

  subroutine build_source_regions(model)
    type(model_t), intent(inout) :: model
    integer :: i, count, ix, iy, iz, index
    real(dp) :: dx, dy, dz

    count = 0
    do i = 1, size(model%cells)
      if (model%cells(i)%is_void) cycle
      if (model%cells(i)%has_subdivision) then
        count = count + model%cells(i)%nx * model%cells(i)%ny * model%cells(i)%nz
      else
        count = count + 1
      end if
    end do

    allocate(model%source_regions(count))
    index = 0
    do i = 1, size(model%cells)
      if (model%cells(i)%is_void) cycle
      model%cells(i)%source_start = index + 1
      if (model%cells(i)%has_subdivision) then
        dx = (model%cells(i)%upper_right(1) - model%cells(i)%lower_left(1)) / real(model%cells(i)%nx, dp)
        dy = (model%cells(i)%upper_right(2) - model%cells(i)%lower_left(2)) / real(model%cells(i)%ny, dp)
        dz = (model%cells(i)%upper_right(3) - model%cells(i)%lower_left(3)) / real(model%cells(i)%nz, dp)
        do iz = 1, model%cells(i)%nz
          do iy = 1, model%cells(i)%ny
            do ix = 1, model%cells(i)%nx
              index = index + 1
              model%source_regions(index)%cell_index = i
              model%source_regions(index)%xs_index = model%cells(i)%xs_index
              model%source_regions(index)%ix = ix
              model%source_regions(index)%iy = iy
              model%source_regions(index)%iz = iz
              model%source_regions(index)%lower_left = [ &
                model%cells(i)%lower_left(1) + real(ix-1, dp) * dx, &
                model%cells(i)%lower_left(2) + real(iy-1, dp) * dy, &
                model%cells(i)%lower_left(3) + real(iz-1, dp) * dz ]
              model%source_regions(index)%upper_right = [ &
                model%cells(i)%lower_left(1) + real(ix, dp) * dx, &
                model%cells(i)%lower_left(2) + real(iy, dp) * dy, &
                model%cells(i)%lower_left(3) + real(iz, dp) * dz ]
            end do
          end do
        end do
        model%cells(i)%source_count = model%cells(i)%nx * model%cells(i)%ny * model%cells(i)%nz
      else
        index = index + 1
        model%source_regions(index)%cell_index = i
        model%source_regions(index)%xs_index = model%cells(i)%xs_index
        model%cells(i)%source_count = 1
      end if
    end do
  end subroutine build_source_regions

  subroutine validate_model_options(model)
    type(model_t), intent(in) :: model

    if (trim(model%run_mode) /= 'criticality' .and. trim(model%run_mode) /= 'fixed-source') then
      call runtime_fail("run_mode must be 'criticality' or 'fixed-source'", 2)
    end if
    if (model%ngroups <= 0) call runtime_fail('energy_groups must be positive', 2)
    if (model%cycles <= 0) call runtime_fail('cycle must be positive', 2)
    if (model%inactive < 0 .or. model%inactive >= model%cycles) then
      call runtime_fail('inactive must satisfy 0 <= inactive < cycle', 2)
    end if
    if (model%particles <= 0) call runtime_fail('particles must be positive', 2)
    if (model%distance_inactive < 0.0_dp .or. model%distance_active < 0.0_dp) then
      call runtime_fail('distance_inactive and distance_active must be non-negative', 2)
    end if
    if (model%boundary_epsilon_shift < 0.0_dp) then
      call runtime_fail('boundary_epsilon_shift must be non-negative', 2)
    end if
    if (any(model%ray_upper_right <= model%ray_lower_left)) then
      call runtime_fail('ray_source upper_right must be greater than lower_left in every coordinate', 2)
    end if
  end subroutine validate_model_options

  subroutine safe_read_line(unit_id, line, packed_path, line_no)
    integer, intent(in) :: unit_id
    character(len=*), intent(out) :: line
    character(len=*), intent(in) :: packed_path
    integer, intent(inout) :: line_no
    integer :: ios

    read(unit_id, '(A)', iostat=ios) line
    if (ios /= 0) call runtime_fail("unexpected end of packed input in '"//trim(packed_path)//"'", 2)
    line_no = line_no + 1
  end subroutine safe_read_line

  subroutine require_min_words(nwords, min_words, packed_path, line_no, record_name)
    integer, intent(in) :: nwords, min_words, line_no
    character(len=*), intent(in) :: packed_path, record_name

    if (nwords < min_words) then
      call runtime_fail("record '"//trim(record_name)//"' in '"//trim(packed_path)//"' at line "//trim(to_string(line_no))// &
        " has too few fields", 2)
    end if
  end subroutine require_min_words

  subroutine read_int_token(token, value, packed_path, line_no, field_name)
    character(len=*), intent(in) :: token, packed_path, field_name
    integer, intent(out) :: value
    integer, intent(in) :: line_no
    integer :: ios

    read(token, *, iostat=ios) value
    if (ios /= 0) then
      call runtime_fail("invalid integer for "//trim(field_name)//" in '"//trim(packed_path)//"' at line "// &
        trim(to_string(line_no))//": '"//trim(token)//"'", 2)
    end if
  end subroutine read_int_token

  subroutine read_real_token(token, value, packed_path, line_no, field_name)
    character(len=*), intent(in) :: token, packed_path, field_name
    real(dp), intent(out) :: value
    integer, intent(in) :: line_no
    integer :: ios

    read(token, *, iostat=ios) value
    if (ios /= 0) then
      call runtime_fail("invalid real value for "//trim(field_name)//" in '"//trim(packed_path)//"' at line "// &
        trim(to_string(line_no))//": '"//trim(token)//"'", 2)
    end if
  end subroutine read_real_token

  character(len=32) function to_string(value)
    integer, intent(in) :: value

    write(to_string, '(I0)') value
  end function to_string

end module strack_input
