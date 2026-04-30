program strack_main
  use strack_config, only: strack_source_dir, strack_python_executable, strack_parallel_backend, strack_windows_shell
  use strack_input, only: load_model
  use strack_output, only: open_log, close_log, write_summary
  use strack_parallel, only: parallel_initialize, parallel_finalize, parallel_is_root, parallel_barrier, parallel_abort, parallel_size
  use strack_solver, only: solve_model
  use strack_string, only: lower_string, strip_extension
  use strack_types, only: model_t, results_t
  implicit none

  type(model_t) :: model
  type(results_t) :: results
  character(len=512) :: input_path, packed_path, extension, command
  integer :: arg_count, log_unit, command_status, exit_status
  logical :: is_root

  call parallel_initialize()
  is_root = parallel_is_root()

  arg_count = command_argument_count()
  if (arg_count < 1) then
    if (is_root) print *, 'usage: strack <input.xml|input.stracki>'
    call parallel_finalize()
    stop 1
  end if

  call get_command_argument(1, input_path)
  extension = lower_string(input_path(max(1, len_trim(input_path)-3):len_trim(input_path)))

  if (index(lower_string(trim(input_path)), '.xml') > 0) then
    packed_path = trim(strip_extension(trim(input_path)))//'.stracki'
    if (is_root) then
      if (strack_windows_shell) then
        command = '""'//trim(strack_python_executable)//'" "'//trim(strack_source_dir)//'/tools/pack_input.py" "'// &
          trim(input_path)//'" "'//trim(packed_path)//'""'
      else
        command = '"'//trim(strack_python_executable)//'" "'//trim(strack_source_dir)//'/tools/pack_input.py" "'// &
          trim(input_path)//'" "'//trim(packed_path)//'"'
      end if
      call execute_command_line(trim(command), wait=.true., exitstat=exit_status, cmdstat=command_status)
      if (command_status /= 0 .or. exit_status /= 0) then
        call parallel_abort('failed to pack XML input into .stracki', 2)
      end if
    end if
    call parallel_barrier()
  else
    packed_path = trim(input_path)
  end if

  call load_model(trim(packed_path), model)
  log_unit = -1
  if (is_root) then
    call open_log(trim(model%output_prefix), log_unit)
    write(*, '(A)') 'running strack on '//trim(model%case_name)
    write(*, '(A,A,A,I0)') 'parallel backend = ', trim(strack_parallel_backend), ', ranks = ', parallel_size()
    write(log_unit, '(A)') 'running strack on '//trim(model%case_name)
    write(log_unit, '(A,A)') 'parallel_backend = ', trim(strack_parallel_backend)
    write(log_unit, '(A,I0)') 'parallel_ranks = ', parallel_size()
  end if

  call solve_model(model, results, log_unit)
  if (is_root) then
    call write_summary(model, results, log_unit)
    call close_log(log_unit)
  end if

  if (is_root) write(*, '(A,F12.6)') 'final keff = ', results%keff
  call parallel_finalize()
end program strack_main
