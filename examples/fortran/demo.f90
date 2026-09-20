! Call the Julia-generated shared library from Fortran.
!
! Build (from the repository root, after `julia --project=. build.jl`):
!   gfortran examples/fortran/demo.f90 out/jlw_example.dylib \
!       -o examples/fortran/demo
!
! On Linux replace `out/jlw_example.dylib` with `out/jlw_example.so`.

module jlw_example_mod
  use, intrinsic :: iso_c_binding
  implicit none

  ! Mirror the struct layouts emitted in out/jlw_example.h.
  type, bind(c) :: JLWStatus
     integer(c_int32_t) :: code
     integer(c_int8_t)  :: message(256)
  end type JLWStatus

  type, bind(c) :: JLWResult_Int64
     type(JLWStatus)    :: status
     integer(c_int64_t) :: value
  end type JLWResult_Int64

  type, bind(c) :: CVector_borrowed_Float64
     integer(c_int64_t) :: dims(1)
     type(c_ptr)        :: data
  end type CVector_borrowed_Float64

  type, bind(c) :: CString_borrowed
     integer(c_int64_t) :: length
     type(c_ptr)        :: data
  end type CString_borrowed

  type, bind(c) :: CString_owned
     integer(c_int64_t) :: length
     type(c_ptr)        :: data
  end type CString_owned

  type, bind(c) :: JLWResult_CString_owned
     type(JLWStatus)     :: status
     type(CString_owned) :: value
  end type JLWResult_CString_owned

  type, bind(c) :: CMatrix_owned_Int32
     integer(c_int64_t) :: dims(2)
     type(c_ptr)        :: data
  end type CMatrix_owned_Int32

  type, bind(c) :: JLWResult_CMatrix_owned_Int32
     type(JLWStatus)           :: status
     type(CMatrix_owned_Int32) :: value
  end type JLWResult_CMatrix_owned_Int32

  interface
     subroutine jlw_free(p) bind(c, name="jlw_free")
       import :: c_ptr
       type(c_ptr), value :: p
     end subroutine jlw_free

     function jlw_example_escape_time(cx, cy, maxiter) &
          bind(c, name="jlw_example_escape_time") result(r)
       import :: c_double, c_int64_t, JLWResult_Int64
       real(c_double), value    :: cx, cy
       integer(c_int64_t), value :: maxiter
       type(JLWResult_Int64)    :: r
     end function jlw_example_escape_time

     function jlw_example_scale_inplace(a, factor) &
          bind(c, name="jlw_example_scale_inplace") result(s)
       import :: c_double, CVector_borrowed_Float64, JLWStatus
       type(CVector_borrowed_Float64), value :: a
       real(c_double), value                 :: factor
       type(JLWStatus)                       :: s
     end function jlw_example_scale_inplace

     function jlw_example_hello(who) &
          bind(c, name="jlw_example_hello") result(r)
       import :: CString_borrowed, JLWResult_CString_owned
       type(CString_borrowed), value :: who
       type(JLWResult_CString_owned) :: r
     end function jlw_example_hello

     function jlw_example_mandelbrot(width, height, maxiter) &
          bind(c, name="jlw_example_mandelbrot") result(r)
       import :: c_int64_t, JLWResult_CMatrix_owned_Int32
       integer(c_int64_t), value :: width, height, maxiter
       type(JLWResult_CMatrix_owned_Int32) :: r
     end function jlw_example_mandelbrot
  end interface
end module jlw_example_mod

program demo
  use, intrinsic :: iso_c_binding
  use jlw_example_mod
  implicit none

  integer, parameter :: width = 78, height = 34, maxiter = 250
  character(len=*), parameter :: ramp = " .:-=+*#%@"

  call demo_hello()
  call demo_scale()
  call demo_escape()
  call demo_mandelbrot()

contains

  subroutine check(status, what)
    type(JLWStatus), intent(in) :: status
    character(len=*), intent(in) :: what
    if (status%code /= 0) then
       print '(a,a,i0,a,a)', what, " failed [", status%code, "]: ", status_text(status)
       error stop 1
    end if
  end subroutine check

  function status_text(status) result(text)
    type(JLWStatus), intent(in) :: status
    character(len=:), allocatable :: text
    integer :: i
    do i = 1, 256
       if (status%message(i) == 0) exit
    end do
    allocate(character(len=i - 1) :: text)
    do i = 1, len(text)
       text(i:i) = achar(iand(int(status%message(i)), 255))
    end do
  end function status_text

  subroutine demo_hello()
    character(len=3, kind=c_char), target :: who = "C++"
    type(CString_borrowed) :: arg
    type(JLWResult_CString_owned) :: r
    character(len=:), allocatable :: text
    integer :: i

    arg%length = int(len(who), c_int64_t)
    arg%data = c_loc(who)
    r = jlw_example_hello(arg)
    call check(r%status, "hello")

    allocate(character(len=r%value%length) :: text)
    block
      integer(c_int8_t), pointer :: bytes(:)
      call c_f_pointer(r%value%data, bytes, [r%value%length])
      do i = 1, len(text)
         text(i:i) = achar(iand(int(bytes(i)), 255))
      end do
    end block
    print '(a)', text
    call jlw_free(r%value%data)
  end subroutine demo_hello

  subroutine demo_scale()
    real(c_double), dimension(4), target :: a = [1.0d0, 2.0d0, 3.0d0, 4.0d0]
    type(CVector_borrowed_Float64) :: vec
    type(JLWStatus) :: s

    vec%dims(1) = int(size(a), c_int64_t)
    vec%data = c_loc(a)
    s = jlw_example_scale_inplace(vec, 0.5d0)
    call check(s, "scale_inplace")
    print '(a,4f6.2)', "scale_inplace ->", a
  end subroutine demo_scale

  subroutine demo_escape()
    type(JLWResult_Int64) :: r
    r = jlw_example_escape_time(0.5d0, 0.5d0, int(100, c_int64_t))
    call check(r%status, "escape_time")
    print '(a,i0)', "escape_time(0.5, 0.5) = ", r%value
  end subroutine demo_escape

  subroutine demo_mandelbrot()
    type(JLWResult_CMatrix_owned_Int32) :: r
    integer(c_int32_t), pointer :: img(:, :)
    integer(c_int64_t) :: rows, cols
    character(len=width) :: line
    integer :: i, j, n, idx

    r = jlw_example_mandelbrot(int(width, c_int64_t), int(height, c_int64_t), &
                               int(maxiter, c_int64_t))
    call check(r%status, "mandelbrot")
    rows = r%value%dims(1)
    cols = r%value%dims(2)
    call c_f_pointer(r%value%data, img, [rows, cols]) ! column-major, like Fortran

    print '(a)', ""
    print '(a,i0,a,i0,a,i0,a)', "Mandelbrot ", cols, "x", rows, " (maxiter ", maxiter, "):"
    do i = 1, rows
       do j = 1, cols
          n = img(i, j)
          if (n >= maxiter) then
             line(j:j) = "@"
          else
             idx = (n * (len_trim(ramp) - 1)) / maxiter + 1
             line(j:j) = ramp(idx:idx)
          end if
       end do
       print '(a)', line
    end do
    call jlw_free(r%value%data)
  end subroutine demo_mandelbrot

end program demo
