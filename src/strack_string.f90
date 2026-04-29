module strack_string
  use strack_kinds, only: str_len, path_len
  implicit none
  private

  public :: lower_string
  public :: split_line
  public :: starts_with
  public :: trim_quotes
  public :: strip_extension
  public :: basename_without_extension

contains

  pure function lower_string(text) result(lowered)
    character(len=*), intent(in) :: text
    character(len=len(text)) :: lowered
    integer :: i, code

    lowered = text
    do i = 1, len(text)
      code = iachar(text(i:i))
      if (code >= iachar('A') .and. code <= iachar('Z')) then
        lowered(i:i) = achar(code + 32)
      end if
    end do
  end function lower_string

  subroutine split_line(line, words, nwords)
    character(len=*), intent(in) :: line
    character(len=str_len), allocatable, intent(out) :: words(:)
    integer, intent(out) :: nwords
    integer :: i, start_pos, line_len

    line_len = len_trim(line)
    nwords = 0
    i = 1
    do while (i <= line_len)
      do while (i <= line_len .and. (line(i:i) == ' ' .or. line(i:i) == char(9)))
        i = i + 1
      end do
      if (i > line_len) exit
      nwords = nwords + 1
      do while (i <= line_len .and. line(i:i) /= ' ' .and. line(i:i) /= char(9))
        i = i + 1
      end do
    end do

    allocate(words(max(nwords, 1)))
    words = ''
    if (nwords == 0) return

    i = 1
    nwords = 0
    do while (i <= line_len)
      do while (i <= line_len .and. (line(i:i) == ' ' .or. line(i:i) == char(9)))
        i = i + 1
      end do
      if (i > line_len) exit
      start_pos = i
      do while (i <= line_len .and. line(i:i) /= ' ' .and. line(i:i) /= char(9))
        i = i + 1
      end do
      nwords = nwords + 1
      words(nwords) = adjustl(line(start_pos:i-1))
    end do
  end subroutine split_line

  pure logical function starts_with(text, prefix)
    character(len=*), intent(in) :: text
    character(len=*), intent(in) :: prefix
    integer :: prefix_len

    prefix_len = len_trim(prefix)
    if (len_trim(text) < prefix_len) then
      starts_with = .false.
    else
      starts_with = text(1:prefix_len) == prefix(1:prefix_len)
    end if
  end function starts_with

  pure function trim_quotes(text) result(clean)
    character(len=*), intent(in) :: text
    character(len=len_trim(text)) :: clean
    integer :: n

    clean = trim(text)
    n = len_trim(clean)
    if (n >= 2) then
      if ((clean(1:1) == '"' .and. clean(n:n) == '"') .or. &
          (clean(1:1) == "'" .and. clean(n:n) == "'")) then
        clean = clean(2:n-1)
      end if
    end if
  end function trim_quotes

  pure function strip_extension(text) result(clean)
    character(len=*), intent(in) :: text
    character(len=len_trim(text)) :: clean
    integer :: i

    clean = trim(text)
    do i = len_trim(clean), 1, -1
      if (clean(i:i) == '.') then
        clean = clean(:i-1)
        return
      end if
      if (clean(i:i) == '\' .or. clean(i:i) == '/') exit
    end do
  end function strip_extension

  pure function basename_without_extension(text) result(name)
    character(len=*), intent(in) :: text
    character(len=path_len) :: name
    integer :: i, start_pos

    name = trim(text)
    start_pos = 1
    do i = len_trim(text), 1, -1
      if (text(i:i) == '\' .or. text(i:i) == '/') then
        start_pos = i + 1
        exit
      end if
    end do
    name = strip_extension(text(start_pos:len_trim(text)))
  end function basename_without_extension

end module strack_string
