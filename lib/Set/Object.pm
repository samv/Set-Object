
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

=head1 FUNCTIONS

The following functions are defined by the Set::Object XS code for
convenience; they are largely identical to the versions in the
Scalar::Util module, but there are a couple that provide functions not
catered to by that module.

=over

=item B<blessed>

Returns a true value if the passed reference (RV) is blessed.  See
also L<Acme::Holy>.

=item B<reftype>

A bit like the perl built-in C<ref> function, but returns the I<type>
of reference; ie, if the reference is blessed then it returns what
C<ref> would have if it were not blessed.  Useful for "seeing through"
blessed references.

=item B<refaddr>

Returns the memory address of a scalar.  B<Warning>: this is I<not>
guaranteed to be unique for scalars created in a program; memory might
get re-used!

=item B<is_int>, B<is_string>, B<is_double>

A quick way of checking the three bits on scalars - IOK (is_int), NOK
(is_double) and POK (is_string).  Note that the exact behaviour of
when these bits get set is not defined by the perl API.

This function returns the "p" versions of the macro (SvIOKp, etc); use
with caution.

=item B<is_overloaded>

A quick way to check if an object has overload magic on it.

=item B<ish_int>

This function returns true, if the value it is passed looks like it
I<already is> a representation of an I<integer>.  This is so that you
can decide whether the value passed is a hash key or an array
index... <devious grin>.

=item B<is_key>

This function returns true, if the value it is passed looks more like
an I<index> to a collection than a I<value> of a collection.

But wait, you say - Set::Object has no indices, one of the fundamental
properties of a Set is that it is an I<unordered collection>.  Which
means I<no indices>.  Stay tuned for the answer.

=back

=head1 INSTALLATION

This module is partly written in C, so you'll need a C compiler to
install it.  Use the familiar sequence:

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

Original Set::Object module by Jean-Louis Leroy, <jll@skynet.be>

=head1 LICENCE

Copyright (c) 1998-1999, Jean-Louis Leroy. All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

Portions Copyright (c) 2003, Sam Vilain.  All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License

=head1 SEE ALSO

perl(1), perltie(1), overload.pm

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

@EXPORT_OK = qw( ish_int is_int is_string is_double blessed reftype
		 refaddr is_overloaded is_object is_key );
$VERSION = '1.08_01';

bootstrap Set::Object $VERSION;

# Preloaded methods go here.

our $cust_disp;

sub as_string
{
    return $cust_disp->(@_) if $cust_disp;
    my $self = shift;
    croak "Tried to use as_string on something other than a Set::Object"
	unless (UNIVERSAL::isa($self, __PACKAGE__));

   'Set::Object(' . (join ' ', sort { $a cmp $b }
		     $self->members) . ')'
}

sub equal
{
   my ($s1, $s2) = @_;
   return undef unless (UNIVERSAL::isa($s2, __PACKAGE__));

   $s1->size() == $s2->size() && $s1->includes($s2->members);
}

sub not_equal
{
   !shift->equal(shift);
}

sub union
{
    my $set = Set::Object->new
	( map { $_->members() }
	  grep { UNIVERSAL::isa($_, __PACKAGE__) }
	  @_ );

    $set->unimerge($_) foreach 
	  grep { UNIVERSAL::isa($_, __PACKAGE__) }
	      @_;

    $set;
}

sub op_union
{
    my $self = shift;
    my $other;
    if (ref $_[0]) {
	$other = shift;
    } else {
	$other = __PACKAGE__->new(shift);
    }

    croak("Tried to form union between Set::Object & "
	  ."`$other'")
	if ref $other and not UNIVERSAL::isa($other, __PACKAGE__);

    $self->union($other);

}

sub intersection
{
   my $s = shift;
   return Set::Object->new() unless $s;

   my $rem = __PACKAGE__->new($s->members);
   $rem->unimerge($s);

   while ($s = shift)
   {
       if (!ref $s) {
	   $s = __PACKAGE__->new($s);
       }

       croak("Tried to form intersection between Set::Object & "
	     .(ref($s)||$s)) unless UNIVERSAL::isa($s, __PACKAGE__);

       $rem->unimerge($s);
       $rem->remove(grep { !$s->includes($_) } $rem->members);
   }

   $rem;
}

sub op_intersection
{
    my $s1 = shift;
    my $s2;
    if (ref $_[0]) {
	$s2 = shift;
    } else {
	$s2 = __PACKAGE__->new(shift);
    }
    my $r = shift;
    if ( $r ) {
	return intersection($s2, $s1);
    } else {
	return intersection($s1, $s2);
    }

}

sub difference
{
   my ($s1, $s2, $r) = @_;
   if ( ! ref $s2 ) {
       if ( is_int($s2) and !is_string($s2) and $s2 == 0 ) {
	   my $rv = $s1->union;
	   $rv->_complement;
	   return $rv;
       } else {
	   my $set = __PACKAGE__->new($s2);
	   $s2 = $set;
       }
   }
   croak("Tried to find difference between Set::Object & "
	 .(ref($s2)||$s2)) unless UNIVERSAL::isa($s2, __PACKAGE__);

   my $s;
   if ( $r ) {
       $s = Set::Object->new( grep { !$s1->includes($_) } $s2->members );
   } else {
       $s = Set::Object->new( grep { !$s2->includes($_) } $s1->members );
   }
   $s->unimerge($s1);
   $s->unimerge($s2);
   $s;
}

sub op_invert
{
    my $self = shift;
    my $other;
    if (ref $_[0]) {
	$other = shift;
    } else {
	$other = __PACKAGE__->new(shift);
    }

    croak("Tried to form union between Set::Object & "
	  ."`$other'")
	if ref $other and not UNIVERSAL::isa($other, __PACKAGE__);

    my $result = Set::Object->new( $self->members() );
    $result->invert( $other->members() );
    $result->unimerge($self);
    $result->unimerge($other);
    return $result;

}


sub symmetric_difference
{
   my ($s1, $s2) = @_;
   croak("Tried to find symmetric difference between Set::Object & "
	 .(ref($s2)||$s2)) unless UNIVERSAL::isa($s2, __PACKAGE__);

   $s1->difference( $s2 )->union( $s2->difference( $s1 ) );
}

sub proper_subset
{
   my ($s1, $s2) = @_;
   croak("Tried to find proper subset of Set::Object & "
	 .(ref($s2)||$s2)) unless UNIVERSAL::isa($s2, __PACKAGE__);
   $s1->size < $s2->size && $s1->subset( $s2 );
}

sub subset
{
   my ($s1, $s2, $r) = @_;
   croak("Tried to find subset of Set::Object & "
	 .(ref($s2)||$s2)) unless UNIVERSAL::isa($s2, __PACKAGE__);
   $s2->includes($s1->members);
}

sub proper_superset
{
   my ($s1, $s2, $r) = @_;
   croak("Tried to find proper superset of Set::Object & "
	 .(ref($s2)||$s2)) unless UNIVERSAL::isa($s2, __PACKAGE__);
   proper_subset( $s2, $s1 );
}

sub superset
{
   my ($s1, $s2) = @_;
   croak("Tried to find superset of Set::Object & "
	 .(ref($s2)||$s2)) unless UNIVERSAL::isa($s2, __PACKAGE__);
   subset( $s2, $s1 );
}

# following code pasted from Set::Scalar; thanks Jarkko Hietaniemi

use overload
   '""'  =>		\&as_string,
   '+'   =>		\&op_union,
   '*'   =>		\&op_intersection,
   '%'   =>		\&symmetric_difference,
   '/'   =>		\&op_invert,
   '-'   =>		\&difference,
   '=='  =>		\&equal,
   '!='  =>		\&not_equal,
   '<'   =>		\&proper_subset,
   '>'   =>		\&proper_superset,
   '<='  =>		\&subset,
   '>='  =>		\&superset,
    fallback => 1,
   ;

# Autoload methods go after =cut, and are processed by the autosplit program.
# This function is used to differentiate between an integer and a
# string for use by the hash container types


# This function is not from Scalar::Util; it is a DWIMy function to
# decide whether the passed thingy could reasonably be considered
# to be an array index, and if so returns the index
sub ish_int {
    my $i;
    eval { $i = _ish_int($_[0]) };

    if ($@) {
	if ($@ =~ /overload/i) {
	    if (my $sub = UNIVERSAL::can($_[0], "(0+")) {
		return ish_int(&$sub($_[0]));
	    } else {
		return undef;
	    }
	} elsif ($@ =~ /tie/i) {
	    my $x = $_[0];
	    return ish_int($x);
	}
    } else {
	return $i;
    }
}

# returns true if the value looks like a key, not an object or a
# collection
sub is_key {
    if (my $class = tied $_[0]) {
	if ($class =~ m/^Tangram::/) { # hack for Tangram RefOnDemands
	    return undef;
	} else {
	    my $x = $_[0];
	    return is_key($x);
	}
    } elsif (is_overloaded($_[0])) {
	# this is a bit of a hack - intrude into the overload internal
	# space
	if (my $sub = UNIVERSAL::can($_[0], "(0+")) {
	    return is_key(&$sub($_[0]));
	} elsif ($sub = UNIVERSAL::can($_[0], '(""')) {
	    return is_key(&$sub($_[0]));
	} elsif ($sub = UNIVERAL::can($_[0], '(nomethod')) {
	    return is_key(&$sub($_[0]));
	} else {
	    return undef;
	}
    } elsif (is_int($_[0]) || is_string($_[0]) || is_double($_[0])) {
	return 1;
    } else {
	return undef;
    }
}

# interface so that Storable may still work
sub STORABLE_freeze {
    my $obj = shift;
    my $am_cloning = shift;
    return ("", $obj->members);
}

use Devel::Peek qw(Dump);

sub STORABLE_thaw {
    #print Dump $_ foreach (@_);

    goto &_STORABLE_thaw;
    #print "Got here\n";
}

sub delete {
    my $self = shift;
    return $self->remove(@_);
}

our $AUTOLOAD;
sub AUTOLOAD {
    croak "No such method $AUTOLOAD";
}

sub universe {
    my $self = shift;
    if ( wantarray ) {
	return $self->_universe;
    } else {
	return $self->clone(1);
    }
}

sub clone {
    my $self = shift;
    my $full = shift;
    my $clone = __PACKAGE__->new($self->universe);
    unless ( $full ) {
	$clone->clear;
	$clone->insert($self->members);
    }
    $clone;
}

# suck in the universe of another set
sub unimerge {
    my $self = shift;
    my $other = shift or die;
    my ($flat, $outer) = $self->_;

    for my $x ( $other->universe ) {
	next if ref $x;
	exists $flat->{$x} or
	    exists $outer->{$x} or
		$outer->{$x} = $x;
    }
}

sub insert_blanks {
    my $self = shift;
    my ($flat, $outer) = $self->_;
    while ( my $thingy = shift ) {
	if ( ref $thingy ) {
	    next;
	} else {
	    $outer->{$thingy} = $thingy
		unless exists $flat->{$thingy};
	}
    }
}

sub _fill {
    my $self = shift;
    my ($flat, $outer) = $self->_;

    while ( my ($key, $v) = each %$outer ) {
	$flat->{$key} = $key;
	delete $outer->{$key};
    }
}

sub invert {
    my $self = shift;
    while ( @_ ) {
	my $sv = shift;
	defined $sv or next;
	#print STDERR "Hello (sv=$sv)!\n";
	if ( $self->includes($sv) ) {
	    #print STDERR "There (it's already there)!\n";
	    $self->remove($sv);
	    #print STDERR "There\n";
	} else {
	    #print STDERR "Dude (it's not already there)!\n";
	    $self->insert($sv);
	    #print STDERR "Dude\n";
	}
	#print STDERR "Alright (done invert)!\n";
    }
}

sub compare {
    my $self = shift;
    my $other = shift;

    return "apples, oranges" unless UNIVERSAL::isa($other, __PACKAGE__);

    my $only_self = $self - $other;
    my $only_other = $other - $self;
    my $intersect = $self * $other;

    if ( $intersect->size ) {
	if ( $only_self->size ) {
	    if ( $only_other->size ) {
		return "proper intersect";
	    } else {
		return "proper subset";
	    }
	} else {
	    if ( $only_other->size ) {
		return "proper superset";
	    } else {
		return "equal";
	    }
	}
    } else {
	return "disjoint";
    }
}

sub is_disjoint {
    my $self = shift;
    my $other = shift;

    return "apples, oranges" unless UNIVERSAL::isa($other, __PACKAGE__);
    return !($self*$other)->size;
}

use Data::Dumper;
sub as_string_callback {
    shift;
    if ( @_ ) {
	$cust_disp = shift;
	if ( $cust_disp &&
	     $cust_disp == \&as_string ) {
	    undef($cust_disp);
	}
    } else {
	\&as_string;
    }
}

sub elements {
    my $self = shift;
    return $self->members(@_);
}

sub has { (shift)->includes(@_) }
sub contains { (shift)->includes(@_) }

sub _outer_members {
    my ($flat, $outer) = (shift)->_;

    values %$outer;
}

sub _universe {
    my $self = shift;
    if ( wantarray ) {
	return ($self->members,
		$self->_outer_members);
    } else {
	return __PACKAGE__->new($self->members,
				$self->_outer_members);
    }
}

sub null {
    my $self = shift;
    my $null = $self->_universe;
    $null->clear;
    $null;
}

1;

__END__
