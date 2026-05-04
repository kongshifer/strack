program strack_main
  use strack_config, only: strack_source_dir, strack_python_executable, strack_windows_shell
  use strack_input, only: load_model
  use strack_kinds, only: dp
  use strack_output, only: open_log, close_log, write_input_echo, write_run_preamble, write_summary
  use strack_parallel, only: parallel_initialize, parallel_finalize, parallel_is_root, parallel_barrier, parallel_abort
  use strack_runtime, only: wall_time_seconds
  use strack_solver, only: solve_model
  use strack_string, only: lower_string, strip_extension
  use strack_types, only: model_t, results_t
  implicit none

  type(model_t) :: model
  type(results_t) :: results
  character(len=512) :: input_path, packed_path, output_prefix, out_path, command
  integer :: arg_count, log_unit, command_status, exit_status, prep_unit
  logical :: is_root, input_is_xml
  real(dp) :: t_program_start, t_pack_start, t_pack_end, t_load_start, t_load_end
  real(dp) :: t_echo_start, t_echo_end, t_solve_start, t_solve_end, t_finalize_start, t_finalize_end

  call parallel_initialize()
  t_program_start = wall_time_seconds()
  is_root = parallel_is_root()

  arg_count = command_argument_count()
  if (arg_count < 1) then
    if (is_root) print *, 'usage: strack <input.xml|input.stracki>'
    call parallel_finalize()
    stop 1
  end if

  call get_command_argument(1, input_path)
  input_is_xml = index(lower_string(trim(input_path)), '.xml') > 0
  output_prefix = trim(strip_extension(trim(input_path)))
  out_path = trim(output_prefix)//'.out'

  if (input_is_xml) then
    packed_path = trim(output_prefix)//'.stracki'
    if (is_root) then
      open(newunit=prep_unit, file=trim(out_path), status='replace', action='write')
      close(prep_unit)
      t_pack_start = wall_time_seconds()
      if (strack_windows_shell) then
        command = '""'//trim(strack_python_executable)//'" "'//trim(strack_source_dir)//'/tools/pack_input.py" "'// &
          trim(input_path)//'" "'//trim(packed_path)//'" "'//trim(out_path)//'""'
      else
        command = '"'//trim(strack_python_executable)//'" "'//trim(strack_source_dir)//'/tools/pack_input.py" "'// &
          trim(input_path)//'" "'//trim(packed_path)//'" "'//trim(out_path)//'"'
      end if
      call execute_command_line(trim(command), wait=.true., exitstat=exit_status, cmdstat=command_status)
      t_pack_end = wall_time_seconds()
      if (command_status /= 0 .or. exit_status /= 0) then
        call parallel_abort('failed to pack XML input into .stracki; see '//trim(out_path), 2)
      end if
    end if
    call parallel_barrier()
  else
    packed_path = trim(input_path)
    if (is_root) then
      open(newunit=prep_unit, file=trim(out_path), status='replace', action='write')
      close(prep_unit)
      t_pack_start = t_program_start
      t_pack_end = t_program_start
    end if
  end if

  log_unit = -1
  if (is_root) then
    call open_log(trim(output_prefix), log_unit, append=input_is_xml)
  end if

  t_echo_start = wall_time_seconds()
  if (is_root) call write_input_echo(trim(input_path), log_unit)
  t_echo_end = wall_time_seconds()

  t_load_start = wall_time_seconds()
  call load_model(trim(packed_path), model)
  t_load_end = wall_time_seconds()

  model%input_path = trim(input_path)
  results%timing%xml_pack = max(t_pack_end - t_pack_start, 0.0_dp)
  results%timing%input_echo = max(t_echo_end - t_echo_start, 0.0_dp)
  results%timing%load_model = max(t_load_end - t_load_start, 0.0_dp)

  if (is_root) call write_run_preamble(model, trim(input_path), trim(packed_path))

  t_solve_start = wall_time_seconds()
  results%timing%initialization_total = max(t_solve_start - t_program_start, 0.0_dp)
  call solve_model(model, results, log_unit)
  t_solve_end = wall_time_seconds()
  if (results%timing%simulation_total <= 0.0_dp) results%timing%simulation_total = max(t_solve_end - t_solve_start, 0.0_dp)

  t_finalize_start = wall_time_seconds()
  call parallel_finalize()
  t_finalize_end = wall_time_seconds()
  results%timing%finalization_total = max(t_finalize_end - t_finalize_start, 0.0_dp)

  if (is_root) then
    call write_summary(model, results, log_unit)
    call close_log(log_unit)
  end if
end program strack_main
