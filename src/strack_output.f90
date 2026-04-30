module strack_output
  use strack_config, only: strack_parallel_backend
  use strack_kinds, only: dp
  use strack_parallel, only: parallel_size
  use strack_types
  implicit none
  private

  public :: open_log
  public :: close_log
  public :: write_summary

contains

  subroutine open_log(prefix, unit_id)
    character(len=*), intent(in) :: prefix
    integer, intent(out) :: unit_id
    open(newunit=unit_id, file=trim(prefix)//'.out', status='replace', action='write')
  end subroutine open_log

  subroutine close_log(unit_id)
    integer, intent(in) :: unit_id
    close(unit_id)
  end subroutine close_log

  subroutine write_summary(model, results, log_unit)
    type(model_t), intent(in) :: model
    type(results_t), intent(in) :: results
    integer, intent(in) :: log_unit
    integer :: py_unit, i, g

    write(log_unit, '(A)') ''
    write(log_unit, '(A,F14.7)') 'final_keff = ', results%keff
    write(log_unit, '(A,I8)') 'source_regions = ', size(model%source_regions)
    write(log_unit, '(A,A)') 'parallel_backend = ', trim(strack_parallel_backend)
    write(log_unit, '(A,I8)') 'parallel_ranks = ', parallel_size()

    open(newunit=py_unit, file=trim(model%output_prefix)//'_results.py', status='replace', action='write')
    write(py_unit, '(A)') 'case_name = "'//trim(model%case_name)//'"'
    write(py_unit, '(A)') 'parallel_backend = "'//trim(strack_parallel_backend)//'"'
    write(py_unit, '(A,I0)') 'parallel_ranks = ', parallel_size()
    write(py_unit, '(A,F18.10)') 'keff = ', results%keff

    write(py_unit, '(A)', advance='no') 'keff_history = ['
    do i = 1, size(results%keff_history)
      if (i > 1) write(py_unit, '(A)', advance='no') ', '
      write(py_unit, '(ES18.10)', advance='no') results%keff_history(i)
    end do
    write(py_unit, '(A)') ']'

    write(py_unit, '(A)', advance='no') 'source_region_weights = ['
    do i = 1, size(results%source_weights)
      if (i > 1) write(py_unit, '(A)', advance='no') ', '
      write(py_unit, '(ES18.10)', advance='no') results%source_weights(i)
    end do
    write(py_unit, '(A)') ']'

    write(py_unit, '(A)') 'source_region_flux = ['
    do i = 1, size(model%source_regions)
      write(py_unit, '(A)', advance='no') '  ['
      do g = 1, model%ngroups
        if (g > 1) write(py_unit, '(A)', advance='no') ', '
        write(py_unit, '(ES18.10)', advance='no') results%flux(i, g)
      end do
      if (i < size(model%source_regions)) then
        write(py_unit, '(A)') '],'
      else
        write(py_unit, '(A)') ']'
      end if
    end do
    write(py_unit, '(A)') ']'

    write(py_unit, '(A)') 'cell_flux = {'
    do i = 1, size(model%cells)
      if (model%cells(i)%is_void) cycle
      write(py_unit, '(A)', advance='no') '  "'//trim(model%cells(i)%id)//'": ['
      do g = 1, model%ngroups
        if (g > 1) write(py_unit, '(A)', advance='no') ', '
        write(py_unit, '(ES18.10)', advance='no') results%cell_flux(i, g)
      end do
      write(py_unit, '(A)') '],'
    end do
    write(py_unit, '(A)') '}'

    close(py_unit)
  end subroutine write_summary

end module strack_output
