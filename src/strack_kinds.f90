module strack_kinds
  implicit none
  integer, parameter :: dp = selected_real_kind(15, 307)
  integer, parameter :: str_len = 64
  integer, parameter :: path_len = 512
  real(dp), parameter :: pi = 3.1415926535897932384626433832795_dp
  real(dp), parameter :: tiny_value = 1.0e-12_dp
end module strack_kinds
