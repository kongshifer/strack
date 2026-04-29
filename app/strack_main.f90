program strack_main
  use strack_config, only: strack_source_dir
  use strack_input, only: load_model
  use strack_output, only: open_log, close_log, write_summary
  use strack_solver, only: solve_model
  use strack_string, only: lower_string, strip_extension
  use strack_types, only: model_t, results_t
  implicit none

  type(model_t) :: model
  type(results_t) :: results
  character(len=512) :: input_path, packed_path, extension, command
  integer :: arg_count, log_unit

  arg_count = command_argument_count()
  if (arg_count < 1) then
    print *, 'usage: strack <input.xml|input.stracki>'
    stop 1
  end if

  call get_command_argument(1, input_path)
  extension = lower_string(input_path(max(1, len_trim(input_path)-3):len_trim(input_path)))

  if (index(lower_string(trim(input_path)), '.xml') > 0) then
    packed_path = trim(strip_extension(trim(input_path)))//'.stracki'
    command = 'py "'//trim(strack_source_dir)//'/tools/pack_input.py" "'//trim(input_path)//'" "'//trim(packed_path)//'"'
    call execute_command_line(trim(command), wait=.true.)
  else
    packed_path = trim(input_path)
  end if

  call load_model(trim(packed_path), model)
  call open_log(trim(model%output_prefix), log_unit)
  write(*, '(A)') 'running strack on '//trim(model%case_name)
  write(log_unit, '(A)') 'running strack on '//trim(model%case_name)

  call solve_model(model, results, log_unit)
  call write_summary(model, results, log_unit)
  call close_log(log_unit)

  write(*, '(A,F12.6)') 'final keff = ', results%keff
end program strack_main
