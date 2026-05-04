module strack_runtime
  use strack_kinds, only: dp
  use strack_parallel, only: parallel_abort, parallel_is_root
  implicit none
  private

  public :: runtime_set_log_unit
  public :: runtime_clear_log_unit
  public :: runtime_log_message
  public :: runtime_fail
  public :: wall_time_seconds

  integer, parameter :: runtime_no_log_unit = huge(0)
  integer :: runtime_log_unit = runtime_no_log_unit

contains

  subroutine runtime_set_log_unit(unit_id)
    integer, intent(in) :: unit_id

    runtime_log_unit = unit_id
  end subroutine runtime_set_log_unit

  subroutine runtime_clear_log_unit()
    runtime_log_unit = runtime_no_log_unit
  end subroutine runtime_clear_log_unit

  subroutine runtime_log_message(message, echo_stdout)
    character(len=*), intent(in) :: message
    logical, intent(in), optional :: echo_stdout
    logical :: do_echo

    do_echo = .false.
    if (present(echo_stdout)) do_echo = echo_stdout

    if (do_echo .and. parallel_is_root()) write(*, '(A)') trim(message)
    if (runtime_log_unit /= runtime_no_log_unit) write(runtime_log_unit, '(A)') trim(message)
  end subroutine runtime_log_message

  subroutine runtime_fail(message, code)
    character(len=*), intent(in) :: message
    integer, intent(in), optional :: code

    if (runtime_log_unit /= runtime_no_log_unit) write(runtime_log_unit, '(A)') 'ERROR: '//trim(message)
    call parallel_abort('ERROR: '//trim(message), code)
  end subroutine runtime_fail

  real(dp) function wall_time_seconds()
    integer :: count, count_rate, count_max

    call system_clock(count, count_rate, count_max)
    if (count_rate > 0) then
      wall_time_seconds = real(count, dp) / real(count_rate, dp)
    else
      wall_time_seconds = 0.0_dp
    end if
  end function wall_time_seconds

end module strack_runtime
