!!
!! NKA_TYPE
!!
!! Neil N. Carlson <neil.n.carlson@gmail.com>
!! Last revised 14 Oct 2006; initial F90 version 1996.
!!
!! This module implements the nonlinear Krylov accelerator (NKA) introduced
!! in [1] for fixed point or Picard iterations.  Placed in the iteration loop,
!! this black-box accelerator listens to the sequence of solution updates and
!! replaces them with accelerated updates.  More generally, NKA can accelerate
!! typical quasi-Newton iterations, which can usually be viewed as a fixed
!! point iteration for a preconditioned function.
!!
!! [1] N.N.Carlson and K.Miller, "Design and application of a gradient-
!!     weighted moving finite element code I: in one dimension", SIAM J.
!!     Sci. Comput;, 19 (1998), pp. 728-765.  See section 9.
!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!
!! Copyright (c) 1996, 2004, 2006, 2013  Neil N. Carlson
!!
!! Permission is hereby granted, free of charge, to any person obtaining a
!! copy of this software and associated documentation files (the "Software"),
!! to deal in the Software without restriction, including without limitation
!! the rights to use, copy, modify, merge, publish, distribute, sublicense,
!! and/or sell copies of the Software, and to permit persons to whom the
!! Software is furnished to do so, subject to the following conditions:
!!
!! The above copyright notice and this permission notice shall be included
!! in all copies or substantial portions of the Software.
!!
!! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
!! IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
!! FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
!! THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
!! LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
!! FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
!! DEALINGS IN THE SOFTWARE.
!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!
!! PROGRAMING INTERFACE
!!
!! This module provides the derived data type NKA with private components that
!! encapsulates the state of the acceleration procedure, and the following
!! procedures that operate on variables of that type.  All real arguments are
!! of kind R8 (double precision).
!!
!!  CALL NKA_INIT (THIS, VLEN, MVEC)
!!    TYPE(NKA), INTENT(OUT) :: THIS
!!    INTEGER,   INTENT(IN)  :: VLEN
!!    INTEGER,   INTENT(IN)  :: MVEC
!!
!!    Initializes the accelerator THIS to handle as many as MVEC vectors of
!!    length VLEN.
!!
!!  CALL NKA_DELETE (THIS)
!!    TYPE(NKA), INTENT(INOUT) :: THIS
!!
!!    Deallocates all the array components of the accelerator THIS and
!!    returns it to its default initialization state.
!!
!!  CALL SET_VEC_TOL (THIS, VTOL)
!!    TYPE(NKA), INTENT(INOUT) :: THIS
!!    REAL(R8), INTENT(IN) :: VTOL
!!
!!    Sets the vector drop tolerance. A vector is dropped from the acceleration
!!    subspace when the sine of the angle between the vector and the subspace
!!    spanned by the preceding vectors is less than this value.  If not set,
!!    the default value 0.01 is used.
!!
!!  CALL NKA_ACCEL_UPDATE (THIS, F, DP)
!!    TYPE(NKA), INTENT(INOUT) :: THIS
!!    REAL(R8),  INTENT(INOUT) :: F(:)
!!    OPTIONAL :: DP
!!
!!    Takes the function value F, which would be the update vector in a fixed
!!    point iteration, and overwrites it with the accelerated update computed
!!    from the acceleration subspace stored in THIS.  This subspace is updated
!!    prior to computing the update using F and previous function value and
!!    update that were cached on the preceding call to NKA_ACCEL_UPDATE, if any.
!!    The input F and returned update are cached in THIS for use by the next
!!    call to NKA_ACCEL_UPDATE.
!!
!!    DP is an optional procedure argument having the same interface as the
!!    intrinsic function DOT_PRODUCT with rank-1 array arguments.  If DP is
!!    present, it is used to compute vector dot products instead of DOT_PRODUCT.
!!    In a parallel context where the vector components are distributed across
!!    processes, a global dot product procedure needs to be supplied that
!!    performs the necessary communications internally.
!!
!!  CALL NKA_RELAX (THIS)
!!    TYPE(NKA), INTENT(INOUT) :: THIS
!!
!!    Deletes the pending vectors that were cached by the preceding call
!!    to NKA_ACCEL_UPDATE, if any.  This modifies the behavior of the next
!!    call to NKA_ACCEL_UPDATE in that the acceleration subspace will not be
!!    updated prior to computing the accelerated update.  This could be used,
!!    for example, to carry over the subspace from one nonlinear solve to
!!    another.  (Whether this is an effective strategy is an open question.)
!!    NKA_ACCEL_UPDATE expects that the passed function value is connected to
!!    the preceding update (if it exists), but this is not normally true for
!!    the first call in a subsequent nonlinear solve, and would result in the
!!    subspace being updated with bogus information.  A call to RELAX at the
!!    end of a nonlinear solve prevents this from occuring.
!!
!!  CALL NKA_RESTART (THIS)
!!    TYPE(NKA), INTENT(OUT) :: THIS
!!
!!    Flushes the acceleration subspace from THIS, returning THIS to its state
!!    as returned by NKA_INIT; the next call to NKA_ACCEL_UPDATE begins the
!!    process of accumulating a new subspace.  Typical usage is to call
!!    NKA_RESTART at the start of each nonlinear solve in a sequence of solves.
!!    This allows the object to be reused and eliminates the overhead of
!!    repeated memory allocation and deallocation that would otherwise occur.
!!
!!
!!  NKA_NUM_VEC(THIS) returns the number of vectors in the acceleration
!!    subspace.
!!
!!  NKA_MAX_VEC(THIS) returns the max number of vectors in the acceleration
!!    subspace.
!!
!!  NKA_VEC_LEN(THIS) returns the length of the vectors.
!!
!!  NKA_VEC_TOL(THIS) returns the vector drop tolerance.
!!
!!  NKA_REAL_KIND(THIS) returns the real kind parameter expected of all real
!!    arguments.
!!
!!  NKA_DEFINED(THIS)
!!    TYPE(NKA), INTENT(IN) :: THIS
!!
!!    Returns the value true if THIS is well-defined; otherwise it returns the
!!    value false.  Defined means that the data components of the object are
!!    properly and consistently defined.  Due to the significant effort this
!!    function goes through to examine the object, it is primarily intended
!!    to be used in debugging situations.  Note that this function is used
!!    internally when this module is compiled without the preprocessor -DNDEBUG
!!    flag.
!!
!! USAGE EXAMPLE
!!
!!  The following simple example shows the usage of this acceleration
!!  procedure.  For more details, see the associated documentation.
!!  Consider a quasi-Newton iteration for solving the nonlinear system
!!  F(x) = 0.  Suppose PC(y) is some preconditioning procedure that applies
!!  some approximation to the inverse of the Jacobian of F(x) to the vector y.
!!  The original quasi-Newton iteration (equivalent to the fixed point
!!  iteration for PC(F(x)) = 0) would look something like
!!
!!    x = 0
!!    do <until converged>
!!      dx = PC(F(X))
!!      x = x - dx
!!    end do
!!
!!  The accelerated iteration would look something like
!!
!!    type(nka) :: accel
!!    call nka_init (accel, size(v), mvec=5)
!!    x = 0
!!    do <until converged>
!!      dx = PC(F(X))
!!      call nka_accel_update (accel, dx)
!!      x = x - dx
!!    end do
!!    call nka_delete (accel)
!!
!! The INIT and DELETE can of course be moved outside any nonlinear solution
!! procedure containing this iteration, and a single NKA-type variable used
!! for repeated calls to the procedure.  This avoids the repeated allocations
!! and deallocations of memory associated with the accelerator. In this case,
!! one should either include a call to NKA_RESTART before the loop so that
!! each iterative solve starts with clean slate, or include a call to NKA_RELAX
!! after the loop so that first call to NKA_ACCEL_UPDATE in the next iterative
!! solve doesn't update the acceleration subspace with bogus information.
!!

#include "f90_assert.fpp"

module nka_type

  implicit none
  private

  integer, parameter :: r8 = selected_real_kind(15) ! 8-byte IEEE float

  type, public :: nka
    private
    logical :: subspace = .false.
    logical :: pending  = .false.
    integer :: vlen = 0         ! vector length
    integer :: mvec = 0         ! maximum number of vectors
    real(r8) :: vtol = 0.01_r8  ! vector drop tolerance
    !! Subspace storage.
    real(r8), allocatable :: v(:,:)   ! update vectors
    real(r8), allocatable :: w(:,:)   ! function difference vectors
    real(r8), allocatable :: h(:,:)   ! matrix of inner products
    !! Linked-list organization of the vector storage.
    integer :: first, last, free
    integer, allocatable :: next(:), prev(:)
  end type nka

  public :: nka_init, nka_delete, nka_set_vec_tol, nka_defined
  public :: nka_vec_len, nka_num_vec, nka_max_vec, nka_vec_tol, nka_real_kind
  public :: nka_accel_update, nka_relax, nka_restart

contains

  subroutine nka_init (this, vlen, mvec)
    type(nka), intent(out) :: this
    integer, intent(in) :: vlen
    integer, intent(in) :: mvec
    integer :: n
    ASSERT(mvec > 0)
    ASSERT(vlen >= 0)
    this%vlen = vlen
    this%mvec = mvec
    n = mvec + 1
    allocate(this%v(vlen,n), this%w(vlen,n))
    allocate(this%h(n,n), this%next(n), this%prev(n))
    call nka_restart (this)
    ASSERT(nka_defined(this))
  end subroutine nka_init

  subroutine nka_set_vec_tol (this, vtol)
    type(nka), intent(inout) :: this
    real(r8), intent(in) :: vtol
    ASSERT(vtol > 0.0_r8)
    this%vtol = vtol
  end subroutine nka_set_vec_tol

  integer function nka_num_vec (this)
    type(nka), intent(in) :: this
    integer :: k
    nka_num_vec = 0
    k = this%first
    do while (k /= 0)
      nka_num_vec = nka_num_vec + 1
      k = this%next(k)
    end do
    if (this%pending) nka_num_vec = nka_num_vec - 1
  end function nka_num_vec

  integer function nka_max_vec (this)
    type(nka), intent(in) :: this
    nka_max_vec = this%mvec
  end function nka_max_vec

  integer function nka_vec_len (this)
    type(nka), intent(in) :: this
    nka_vec_len = this%vlen
  end function nka_vec_len

  real(r8) function nka_vec_tol (this)
    type(nka), intent(in) :: this
    nka_vec_tol = this%vtol
  end function nka_vec_tol

  integer function nka_real_kind (this)
    type(nka), intent(in) :: this
    nka_real_kind = kind(this%h)
  end function nka_real_kind

  subroutine nka_delete (this)
    type(nka), intent(inout) :: this
    type(nka) :: default
    if (allocated(this%v)) deallocate(this%v)
    if (allocated(this%w)) deallocate(this%w)
    if (allocated(this%h)) deallocate(this%h)
    if (allocated(this%next)) deallocate(this%next)
    if (allocated(this%prev)) deallocate(this%prev)
    this = default    ! Set default values
  end subroutine nka_delete


  subroutine nka_accel_update (this, f, dp)

    type(nka), intent(inout) :: this
    real(r8),  intent(inout) :: f(:)

    !! Optional dot product procedure to use instead of the intrinsic DOT_PRODUCT.
    interface
      pure function dp (x, y)
        integer, parameter :: r8 = selected_real_kind(15) ! 8-byte IEEE float
        real(r8), intent(in) :: x(:), y(:)
        real(r8) :: dp
      end function dp
    end interface
    optional :: dp

    ! local variables.
    integer :: i, j, k, new, nvec
    real(r8) :: s, hkk, hkj, cj, c(this%mvec+1)

    ASSERT(nka_defined(this))
    ASSERT(size(f) == size(this%v,dim=1))

   !!!
   !!! UPDATE THE ACCELERATION SUBSPACE

    if (this%pending) then

      !! Next function difference w_1.
      this%w(:,this%first) = this%w(:,this%first) - f
      if (present(dp)) then
        s = sqrt(dp(this%w(:,this%first), this%w(:,this%first)))
      else
        s = sqrt(dot_product(this%w(:,this%first), this%w(:,this%first)))
      end if

      !! If the function difference is 0, we can't update the subspace with
      !! this data; so we toss it out and continue.  In this case it is likely
      !! that the outer iterative solution procedure has gone badly awry
      !! (unless the function value is itself 0), and we merely want to do
      !! something reasonable here and hope that situation is detected on the
      !! outside.
      if (s == 0.0_r8) call nka_relax (this)

    end if

    if (this%pending) then

      !! Normalize w_1 and apply same factor to v_1.
      this%v(:,this%first) = this%v(:,this%first) / s
      this%w(:,this%first) = this%w(:,this%first) / s

      !! Update H.
      k = this%next(this%first)
      do while (k /= 0)
        if (present(dp)) then
          this%h(this%first,k) = dp(this%w(:,this%first), this%w(:,k))
        else
          this%h(this%first,k) = dot_product(this%w(:,this%first), this%w(:,k))
        end if
        k = this%next(k)
      end do

     !!!
     !!! CHOLESKI FACTORIZATION OF H

      this%h(this%first,this%first) = 1.0_r8
      k = this%next(this%first)
      nvec = 1

      do while (k /= 0)
        nvec = nvec + 1
        if (nvec > this%mvec) then  ! Maintain at most MVEC vectors:
          !! Drop the last vector and update the free storage list.
          ASSERT(this%last == k)
          this%next(this%last) = this%free
          this%free = k
          this%last = this%prev(k)
          this%next(this%last) = 0
          exit
        end if

        hkk = 1.0_r8           ! Single stage of Choleski factorization.
        j = this%first         ! Original matrix kept in lower triangle (unit diagonal).
        do while (j /= k)      ! Upper triangle holds the factorization.
          hkj = this%h(j,k)
          i = this%first
          do while (i /= j)
            hkj = hkj - this%h(k,i) * this%h(j,i)
            i = this%next(i)
          end do
          hkj = hkj / this%h(j,j)
          hkk = hkk - hkj**2
          this%h(k,j) = hkj
          j = this%next(j)
        end do

        if (hkk > this%vtol**2) then
          this%h(k,k) = sqrt(hkk)
        else  ! The current w nearly lies in the span of the previous vectors.

          !! Drop this vector
          ASSERT(this%prev(k) /= 0)
          this%next(this%prev(k)) = this%next(k)
          if (this%next(k) == 0) then
            this%last = this%prev(k)
          else
            this%prev(this%next(k)) = this%prev(k)
          end if

          this%next(k) = this%free    ! update the free storage list,
          this%free = k

          k = this%prev(k)            ! and back-up.
          nvec = nvec - 1

        end if
        k = this%next(k)
      end do

      ASSERT(this%first /= 0)
      this%subspace = .true.

    end if

    !! Locate storage for the new vectors.
    ASSERT(this%free /= 0)
    new = this%free
    this%free = this%next(this%free)

    !! Save the original f for the next call.
    this%w(:,new) = f

   !!!
   !!! ACCELERATED UPDATE

    if (this%subspace) then

      !! Project f onto the span of the w vectors: forward substitution
      j = this%first
      do while (j /= 0)
        if (present(dp)) then
          cj = dp(f, this%w(:,j))
        else
          cj = dot_product(f, this%w(:,j))
        endif
        i = this%first
        do while (i /= j)
          cj = cj - this%h(j,i) * c(i)
          i = this%next(i)
        end do
        c(j) = cj / this%h(j,j)
        j = this%next(j)
      end do

      !! Project f onto the span of the w vectors: backward substitution
      j = this%last
      do while (j /= 0)
        cj = c(j)
        i = this%last
        do while (i /= j)
          cj = cj - this%h(i,j) * c(i)
          i = this%prev(i)
        end do
        c(j) = cj / this%h(j,j)
        j = this%prev(j)
      end do

      !! The accelerated update
      k = this%first
      do while (k /= 0)
        f = f - c(k) * this%w(:,k) + c(k) * this%v(:,k)
        k = this%next(k)
      end do

    end if

    !! Save the update for the next call.
    this%v(:,new) = f

    !! Prepend the new vectors to the list.
    this%prev(new) = 0
    this%next(new) = this%first
    if (this%first == 0) then
      this%last = new
    else
      this%prev(this%first) = new
    end if
    this%first = new

    !! The original f and accelerated update are cached for the next call.
    this%pending = .true.

  end subroutine nka_accel_update


  subroutine nka_restart (this)
    type(nka), intent(inout) :: this
    integer :: k
    this%subspace = .false.
    this%pending  = .false.
    !! No vectors are stored.
    this%first = 0
    this%last  = 0
    !! Initialize the free storage linked list.
    this%free  = 1
    do k = 1, size(this%next)-1
      this%next(k) = k + 1
    end do
    this%next(size(this%next)) = 0
  end subroutine nka_restart


  subroutine nka_relax (this)
    type(nka), intent(inout) :: this
    integer :: new
    if (this%pending) then
      ASSERT(this%first /= 0)
      !! Drop the pending vectors.
      new = this%first
      this%first = this%next(this%first)
      if (this%first == 0) then
        this%last = 0
      else
        this%prev(this%first) = 0
      end if
      !! Update the free storage list.
      this%next(new) = this%free
      this%free = new
      this%pending = .false.
    end if
  end subroutine nka_relax


  logical function nka_defined (this)

    type(nka), intent(in) :: this

    integer :: n
    logical, allocatable :: tag(:)

    CHECKLIST: do
      nka_defined = .false.
      if (this%mvec < 1) exit
      if (.not.allocated(this%v)) exit
      if (.not.allocated(this%w)) exit
      if (any(shape(this%v) /= shape(this%w))) exit
      if (size(this%v,dim=1) /= this%vlen) exit
      if (size(this%v,dim=2) /= this%mvec+1) exit
      if (.not.allocated(this%h)) exit
      if (size(this%h,dim=1) /= this%mvec+1) exit
      if (size(this%h,dim=2) /= this%mvec+1) exit
      if (.not.allocated(this%next)) exit
      if (size(this%next) /= this%mvec+1) exit
      if (.not.allocated(this%prev)) exit
      if (size(this%prev) /= this%mvec+1) exit

      if (this%vtol <= 0.0_r8) exit

      n = size(this%next)
      if (any(this%next < 0) .or. any(this%next > n)) exit
      if (this%first < 0 .or. this%first > n) exit
      if (this%free  < 0 .or. this%free  > n) exit

      !! Tag array: each location is either in the free list or vector list.
      allocate(tag(size(this%next)))
      tag = .false.

      !! Check the vector list for consistency.
      if (this%first == 0) then
        if (this%last /= 0) exit
      else
        n = this%first
        if (this%prev(n) /= 0) exit
        tag(n) = .true.
        do while (this%next(n) /= 0)
          if (this%prev(this%next(n)) /= n) exit CHECKLIST
          n = this%next(n)
          if (tag(n)) exit CHECKLIST
          tag(n) = .true.
        end do
        if (this%last /= n) exit
      end if

      !! Check the free list.
      n = this%free
      do while (n /= 0)
        if (tag(n)) exit CHECKLIST
        tag(n) = .true.
        n = this%next(n)
      end do

      !! All locations accounted for?
      if (.not.all(tag)) exit

      nka_defined = .true.
      exit
    end do CHECKLIST

    if (allocated(tag)) deallocate(tag)

  end function nka_defined

end module nka_type
