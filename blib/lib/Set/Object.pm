
=head1 NAME

Set::Object - set of objects

=head1 SYNOPSIS

  use Set::Object;
  $set = Set::Object->new();

=head1 DESCRIPTION

This modules implements a set of objects, that is, an unordered
collection of objects without duplication.

=head1 CLASS METHODS

=head2 new( [I<list>] )

Return a new C<Set::Object> containing the elements passed in I<list>.
The elements must be objects.

=head1 INSTANCE METHODS

=head2 insert( [I<list>] )

Add objects to the C<Set::Object>.
Adding the same object several times is not an error,
but any C<Set::Object> will contain at most one occurence of the
same object.
Returns the number of elements that were actually added.

=head2 includes( [I<list>] )

Return C<true> if all the objects in I<list> are members of the C<Set::Object>.
I<list> may be empty, in which case C<true> is returned.

=head2 members

Return the objects contained in the C<Set::Object>.

=head2 size

Return the number of elements in the C<Set::Object>.

=head2 remove( [I<list>] )

Remove objects from a C<Set::Object>.
Removing the same object more than once, or removing an object
absent from the C<Set::Object> is not an error.
Returns the number of elements that were actually removed.

=head2 clear

Empty this C<Set::Object>.

=head2 as_string

Return a textual Smalltalk-ish representation of the C<Set::Object>.
Also available as overloaded operator "".

=head2 intersection( [I<list>] )

Return a new C<Set::Object> containing the intersection of the 
C<Set::Object>s passed as arguments.
Also available as overloaded operator *.

=head2 union( [I<list>] )

Return a new C<Set::Object> containing the union of the 
C<Set::Object>s passed as arguments.
Also available as overloaded operator +.

=head2 subset( I<set> )

Return C<true> if this C<Set::Object> is a subset of I<set>.
Also available as operator <=.

=head2 proper_subset( I<set> )

Return C<true> if this C<Set::Object> is a proper subset of I<set>
Also available as operator <.

=head2 superset( I<set> )

Return C<true> if this C<Set::Object> is a superset of I<set>.
Also available as operator >=.

=head2 proper_superset( I<set> )

Return C<true> if this C<Set::Object> is a proper superset of I<set>
Also available as operator >.

=head1 INSTALLATION

This module is partly written in C, so you'll need a C compiler to install it.
Use the familiar sequence:

   perl Makefile.PL
   make
   make test
   make install

This module was developed on Windows NT 4.0, using the Visual C++
compiler with Service Pack 2. It was also tested on AIX using IBM's
xlc compiler.

=head1 PERFORMANCE

The following benchmark compares C<Set::Object> with using a hash to
emulate a set-like collection:

   use Set::Object;

   package Obj;
   sub new { bless { } }

   @els = map { Obj->new() } 1..1000;

   require Benchmark;

   Benchmark::timethese(100, {
      'Control' => sub { },
      'H insert' => sub { my %h = (); @h{@els} = @els; },
      'S insert' => sub { my $s = Set::Object->new(); $s->insert(@els) },
      } );

   %gh = ();
   @gh{@els} = @els;

   $gs = Set::Object->new(@els);
   $el = $els[33];

   Benchmark::timethese(100_000, {
       'H lookup' => sub { exists $gh{33} },
       'S lookup' => sub { $gs->includes($el) }
      } );

On my computer the results are:

   Benchmark: timing 100 iterations of Control, H insert, S insert...
      Control:  0 secs ( 0.01 usr  0.00 sys =  0.01 cpu)
               (warning: too few iterations for a reliable count)
     H insert: 68 secs (67.81 usr  0.00 sys = 67.81 cpu)
     S insert:  9 secs ( 8.81 usr  0.00 sys =  8.81 cpu)
   Benchmark: timing 100000 iterations of H lookup, S lookup...
     H lookup:  7 secs ( 7.14 usr  0.00 sys =  7.14 cpu)
     S lookup:  6 secs ( 5.94 usr  0.00 sys =  5.94 cpu)

=head1 AUTHOR

Jean-Louis Leroy, jll@skynet.be

=head1 LICENCE

Copyright (c) 1998, Jean-Louis Leroy. All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

=head1 SEE ALSO

perl(1).
overload.pm

=cut

package Set::Object;

use strict;
use Carp;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(

);
$VERSION = '1.00';

bootstrap Set::Object $VERSION;

# Preloaded methods go here.

sub dump
{
   my $self = shift;
   my $i = 0;

   foreach my $bucket (@$self)
   {
      if ($bucket)
      {
         printf "%4d: ", $i;
         print join ' ', @$bucket;
         print "\n";
      }

      ++$i;
   }
}

sub _members
{
   my $self = shift;
   map { $_ ? @$_ : () } @$self;
}

sub as_string
{
   'Set::Object(' . (join ' ', shift->members) . ')'
}

sub equal
{
   my ($s1, $s2) = @_;
   $s1->size() == $s2->size() && $s1->includes($s2->members);
}

sub not_equal
{
   !shift->equal(shift);
}

sub union
{
   Set::Object->new( map { $_->members() } @_ )
}

sub op_union
{
   Set::Object->new( shift->members(), shift->members() )
}

sub intersection
{
   my $s = shift;
   
   return Set::Object->new() unless $s;

   my @r = $s->members;

   while (@r && ($s = shift))
   {
      @r = grep { $s->includes( $_ ) } @r;
   }

   Set::Object->new( @r );
}

sub op_intersection
{
   intersection(shift, shift);
}

sub difference
{
   my ($s1, $s2, $r) = @_;
   ($s1, $s2) = ($s2, $s1) if $r;
   Set::Object->new( grep { !$s2->includes($_) } $s1->members );
}

sub symmetric_difference
{
   my ($s1, $s2) = @_;
   $s1->difference( $s2 )->union( $s2->difference( $s1 ) );
}

sub proper_subset
{
   my ($s1, $s2, $r) = @_;
   ($s1, $s2) = ($s2, $s1) if $r;
   $s1->size < $s2->size && $s1->subset( $s2 );
}

sub subset
{
   my ($s1, $s2, $r) = @_;
   ($s1, $s2) = ($s2, $s1) if $r;
   $s2->includes($s1->members);
}

sub proper_superset
{
   my ($s1, $s2, $r) = @_;
   proper_subset( $s1, $s2, !$r);
}

sub superset
{
   my ($s1, $s2, $r) = @_;
   subset( $s1, $s2, !$r);
}

# following code pasted from Set::Scalar; thanks Jarkko Hietaniemi

use overload
   '""'  =>     \&as_string,
   '+'   =>     \&op_union,
   '*'   =>     \&op_intersection,
   '%'   =>     \&symmetric_difference,
   '-'   =>     \&difference,
   '=='  =>     \&equal,
   '!='  =>     \&not_equal,
   '<'   =>     \&proper_subset,
   '>'   =>     \&proper_superset,
   '<='  =>     \&subset,
   '>='  =>     \&superset
   ;

# Autoload methods go after =cut, and are processed by the autosplit program.

1;

__END__
