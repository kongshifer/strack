module strack_input
  use strack_kinds, only: dp, str_len, path_len
  use strack_string, only: split_line, lower_string, basename_without_extension
  use strack_types
  implicit none
  private

  public :: load_model

contains

  subroutine load_model(packed_path, model)
    character(len=*), intent(in) :: packed_path
    type(model_t), intent(out) :: model
    integer :: unit_id, ios
    character(len=1024) :: line
    character(len=str_len), allocatable :: words(:)
    integer :: nwords

    model%packed_path = trim(packed_path)
    model%case_name = basename_without_extension(trim(packed_path))
    model%output_prefix = trim(packed_path)
    model%output_prefix = model%output_prefix(:len_trim(model%output_prefix)-8)

    open(newunit=unit_id, file=trim(packed_path), status='old', action='read', iostat=ios)
    if (ios /= 0) error stop 'failed to open packed input'

    call safe_read_line(unit_id, line)
    if (trim(line) /= 'STRACK_INPUT_V1') error stop 'invalid packed input header'

    do
      read(unit_id, '(A)', iostat=ios) line
      if (ios /= 0) exit
      if (len_trim(line) == 0) cycle
      call split_line(line, words, nwords)
      if (nwords == 0) cycle

      select case (trim(words(1)))
      case ('CASE')
        model%case_name = trim(words(2))
      case ('RUN_MODE')
        model%run_mode = lower_string(trim(words(2)))
      case ('GEOMETRY_SEARCH')
        model%geometry_search = lower_string(trim(words(2)))
      case ('SPATIAL_DIMENSION')
        read(words(2), *) model%spatial_dimension
      case ('ENERGY_GROUPS')
        read(words(2), *) model%ngroups
      case ('CYCLE')
        read(words(2), *) model%cycles
      case ('INACTIVE')
        read(words(2), *) model%inactive
      case ('PARTICLES')
        read(words(2), *) model%particles
      case ('DISTANCE_INACTIVE')
        read(words(2), *) model%distance_inactive
      case ('DISTANCE_ACTIVE')
        read(words(2), *) model%distance_active
      case ('SEED')
        read(words(2), *) model%seed
      case ('RAY_BOX')
        read(words(2), *) model%ray_lower_left(1)
        read(words(3), *) model%ray_lower_left(2)
        read(words(4), *) model%ray_lower_left(3)
        read(words(5), *) model%ray_upper_right(1)
        read(words(6), *) model%ray_upper_right(2)
        read(words(7), *) model%ray_upper_right(3)
      case ('MATERIAL_COUNT')
        call read_materials(unit_id, model, words)
      case ('XS_COUNT')
        call read_xs(unit_id, model, words)
      case ('SURFACE_COUNT')
        call read_surfaces(unit_id, model, words)
      case ('CELL_COUNT')
        call read_cells(unit_id, model, words)
      case ('FIXED_SOURCE_COUNT')
        call read_fixed_sources(unit_id, model, words)
      case ('END_INPUT')
        exit
      case default
        error stop 'unknown packed input section'
      end select
    end do

    close(unit_id)

    if (model%spatial_dimension /= 2 .and. model%spatial_dimension /= 3) then
      error stop 'spatial_dimension must be 2 or 3'
    end if
    call normalize_geometry_search(model)

    call resolve_materials(model)
    call build_geometry_maps(model)
    call build_source_regions(model)
  end subroutine load_model

  subroutine read_materials(unit_id, model, header_words)
    integer, intent(in) :: unit_id
    type(model_t), intent(inout) :: model
    character(len=str_len), intent(in) :: header_words(:)
    integer :: count, i
    character(len=1024) :: line
    character(len=str_len), allocatable :: words(:)
    integer :: nwords

    read(header_words(2), *) count
    allocate(model%materials(count))
    do i = 1, count
      call safe_read_line(unit_id, line)
      call split_line(line, words, nwords)
      if (trim(words(1)) /= 'MATERIAL') error stop 'expected MATERIAL'
      model%materials(i)%id = trim(words(2))
      model%materials(i)%xs_id = trim(words(3))
    end do
  end subroutine read_materials

  subroutine read_xs(unit_id, model, header_words)
    integer, intent(in) :: unit_id
    type(model_t), intent(inout) :: model
    character(len=str_len), intent(in) :: header_words(:)
    integer :: count, i, g, ng, nwords
    character(len=1024) :: line
    character(len=str_len), allocatable :: words(:)

    read(header_words(2), *) count
    ng = model%ngroups
    allocate(model%xs(count))

    do i = 1, count
      call safe_read_line(unit_id, line)
      call split_line(line, words, nwords)
      if (trim(words(1)) /= 'XS') error stop 'expected XS'
      model%xs(i)%id = trim(words(2))
      allocate(model%xs(i)%sigma_t(ng))
      allocate(model%xs(i)%nu_sigma_f(ng))
      allocate(model%xs(i)%chi(ng))
      allocate(model%xs(i)%scatter(ng, ng))

      call safe_read_line(unit_id, line)
      call split_line(line, words, nwords)
      if (trim(words(1)) /= 'TOTAL') error stop 'expected TOTAL'
      do g = 1, ng
        read(words(g+1), *) model%xs(i)%sigma_t(g)
      end do

      call safe_read_line(unit_id, line)
      call split_line(line, words, nwords)
      if (trim(words(1)) /= 'NU_SIGMA_F') error stop 'expected NU_SIGMA_F'
      do g = 1, ng
        read(words(g+1), *) model%xs(i)%nu_sigma_f(g)
      end do

      call safe_read_line(unit_id, line)
      call split_line(line, words, nwords)
      if (trim(words(1)) /= 'CHI') error stop 'expected CHI'
      do g = 1, ng
        read(words(g+1), *) model%xs(i)%chi(g)
      end do

      do g = 1, ng
        call safe_read_line(unit_id, line)
        call split_line(line, words, nwords)
        if (trim(words(1)) /= 'SCATTER_ROW') error stop 'expected SCATTER_ROW'
        do count = 1, ng
          read(words(count+2), *) model%xs(i)%scatter(g, count)
        end do
      end do

      call safe_read_line(unit_id, line)
      if (trim(line) /= 'END_XS') error stop 'expected END_XS'
    end do
  end subroutine read_xs

  subroutine read_surfaces(unit_id, model, header_words)
    integer, intent(in) :: unit_id
    type(model_t), intent(inout) :: model
    character(len=str_len), intent(in) :: header_words(:)
    integer :: count, i, j, ncoeff, nwords
    character(len=1024) :: line
    character(len=str_len), allocatable :: words(:)

    read(header_words(2), *) count
    allocate(model%surfaces(count))
    do i = 1, count
      call safe_read_line(unit_id, line)
      call split_line(line, words, nwords)
      if (trim(words(1)) /= 'SURFACE') error stop 'expected SURFACE'
      model%surfaces(i)%id = trim(words(2))
      model%surfaces(i)%surface_type = lower_string(trim(words(3)))
      model%surfaces(i)%boundary = lower_string(trim(words(4)))
      read(words(5), *) ncoeff
      allocate(model%surfaces(i)%coeffs(ncoeff))
      do j = 1, ncoeff
        read(words(5+j), *) model%surfaces(i)%coeffs(j)
      end do
    end do
  end subroutine read_surfaces

  subroutine read_cells(unit_id, model, header_words)
    integer, intent(in) :: unit_id
    type(model_t), intent(inout) :: model
    character(len=str_len), intent(in) :: header_words(:)
    integer :: count, i, nwords, ntokens, has_subdivision
    character(len=1024) :: line
    character(len=str_len), allocatable :: words(:)

    read(header_words(2), *) count
    allocate(model%cells(count))

    do i = 1, count
      call safe_read_line(unit_id, line)
      call split_line(line, words, nwords)
      if (trim(words(1)) /= 'CELL') error stop 'expected CELL'
      model%cells(i)%id = trim(words(2))
      model%cells(i)%material_id = trim(words(3))
      read(words(4), *) has_subdivision
      read(words(5), *) ntokens
      model%cells(i)%has_subdivision = has_subdivision == 1

      call safe_read_line(unit_id, line)
      call split_line(line, words, nwords)
      if (trim(words(1)) /= 'TOKENS') error stop 'expected TOKENS'
      call parse_zone_tokens(model, words, ntokens, model%cells(i)%token_type, model%cells(i)%token_value)

      if (model%cells(i)%has_subdivision) then
        call safe_read_line(unit_id, line)
        call split_line(line, words, nwords)
        if (trim(words(1)) /= 'SUBDIVISION') error stop 'expected SUBDIVISION'
        read(words(2), *) model%cells(i)%nx
        read(words(3), *) model%cells(i)%ny
        read(words(4), *) model%cells(i)%nz
        read(words(5), *) model%cells(i)%lower_left(1)
        read(words(6), *) model%cells(i)%lower_left(2)
        read(words(7), *) model%cells(i)%lower_left(3)
        read(words(8), *) model%cells(i)%upper_right(1)
        read(words(9), *) model%cells(i)%upper_right(2)
        read(words(10), *) model%cells(i)%upper_right(3)
      end if

      call safe_read_line(unit_id, line)
      if (trim(line) /= 'END_CELL') error stop 'expected END_CELL'
    end do
  end subroutine read_cells

  subroutine read_fixed_sources(unit_id, model, header_words)
    integer, intent(in) :: unit_id
    type(model_t), intent(inout) :: model
    character(len=str_len), intent(in) :: header_words(:)
    integer :: count, i, g, nwords
    character(len=1024) :: line
    character(len=str_len), allocatable :: words(:)

    read(header_words(2), *) count
    allocate(model%fixed_sources(count))
    do i = 1, count
      call safe_read_line(unit_id, line)
      call split_line(line, words, nwords)
      if (trim(words(1)) /= 'FIXED_SOURCE') error stop 'expected FIXED_SOURCE'
      read(words(2), *) model%fixed_sources(i)%cell_index
      read(words(3), *) model%fixed_sources(i)%strength
      allocate(model%fixed_sources(i)%spectrum(model%ngroups))
      do g = 1, model%ngroups
        read(words(3+g), *) model%fixed_sources(i)%spectrum(g)
      end do
    end do
  end subroutine read_fixed_sources

  subroutine parse_zone_tokens(model, words, ntokens, token_type, token_value)
    type(model_t), intent(in) :: model
    character(len=str_len), intent(in) :: words(:)
    integer, intent(in) :: ntokens
    integer, allocatable, intent(out) :: token_type(:)
    integer, allocatable, intent(out) :: token_value(:)
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
        if (index == 0) error stop 'unknown surface in zone expression'
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
      if (model%materials(i)%xs_index == 0) error stop 'material to xs mapping failed'
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
      if (model%cells(i)%xs_index == 0) error stop 'cell material mapping failed'
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
      error stop 'geometry_search must be global or surface-local'
    end select
  end subroutine normalize_geometry_search

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

  subroutine safe_read_line(unit_id, line)
    integer, intent(in) :: unit_id
    character(len=*), intent(out) :: line
    integer :: ios
    read(unit_id, '(A)', iostat=ios) line
    if (ios /= 0) error stop 'unexpected end of packed input'
  end subroutine safe_read_line

end module strack_input
