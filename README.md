Nonlinear Krylov Acceleration
=============================
Nonlinear Krylov Acceleration (NKA) [1] is a method for accelerating the
convergence of fixed-point (Picard) iterations. Many Newton-like and inexact
Newton methods are fixed point iterations. The NKA project provides the
canonical implementation of the method for several programming languages.
The black-box accelerator is simple to integrate into existing code. Placed
in the iteration loop, it observes the sequence of solution updates and
replaces them with improved updates using information it has gleaned from
previous solution iterates.

It was only recently recognized (2011 [2]) that NKA is essentially equivalent
to Anderson Acceleration [3] for a specific choice of mixing parameter.
NKA was independently devised by Miller in 1990 in a different application
context using a very different approach, and though it leads to the same
algebraic method, NKA's organization is somewhat different, and arguably
superior. The NKA approach also provides clear rationale for the proper
choice of Anderson's arbitrary mixing parameter.

The NKA method was first described in the final section of [1]. A much more
detailed description of it and a comparison with Anderson Acceleration can
be found in [4]. A description can also be found in the slides `doc/nlk.pdf`.

Using NKA
---------
Several different versions of NKA are provided here. The directory `src-F95`
contains the original Fortran 95 implementation. (The original implementation
was in Fortran 77.) A newer object-oriented version implemented in modern
Fortran can be found in `src-F08`. That version requires a compiler that has
a fairly complete implementation of the 2003 standard, perhaps with some minor
2008 features. The directory `src-C` contains a C version.

The source for these versions (F95, F08, C) consists of a single source file
that can be easily incorporated into your own software project.  They all
feature essentially the same interface, which is documented in the comments
at the top of the source file.

Each of these versions also contain an example program that illustrates how
to use NKA by solving a nonlinear elliptic equation on a regular 2D grid.
There is a simple cmake-based build system. A simple `cmake .` in the sub-
directory, followed by `make` should build the `nka_example` program. If cmake
has problems finding your Fortran compiler, try setting the `FC` environment
variable to the path to it. For a test, output from `nka_example` should be
compared to that in `reference_output`. The `F08/nka_example` program is a bit
more elaborate, allowing several problem and method parameters to be set on
the command line. Use the `--help` option to get usage information. You can
get a better idea of how NKA behaves by experimenting with this program.

The directory `src-C++` contains a somewhat different version of NKA. This
is a C++ implementation (by Markus Berndt) that was designed to work with
the NOX package from Trilinos (http://trilinos.org), and which was used to
generate the numerical results in [4]. This code is now obsolete, however,
and is just retained for reference. NOX now includes a version of Anderson
Acceleration.

References
----------
1. N.N. Carlson and K. Miller. Design and Application of a Gradient-
   Weighted Moving Finite Element Code I: in One Dimension. SIAM Journal on
   Scientific Computing, 19(3):728-765, 1998. NKA is described in the final
   section.

2. H.F. Walker and P. Ni. Anderson Acceleration for Fixed-Point Iterations.
   SIAM Journal on Numerical Analysis, 49(4), 2011.

3. D. Anderson. Iterative Procedures for Nonlinear Integral Equations. Journal
   of the ACM, 12(4), 1965.

4. M.T. Calef, E.D. Fichtl, J.S. Warsa, M. Berndt, and N.N. Carlson. Nonlinear
   Krylov acceleration Applied to a Discrete Ordinates Formulation of the
   k-Eigenvalue Problem. Journal of Computational Physics, 238:188–209, 2013.
