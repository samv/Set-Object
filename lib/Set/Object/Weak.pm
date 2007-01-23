
=head1 NAME

Set::Object::Weak - Sets without the referant reference increment

=head1 SYNOPSIS

 use Set::Object::Weak qw(weak_set);

 my $set = Set::Object::Weak->new( 0, "", {}, [], $object );

 # or
 my $set = weak_set( "hello", "hello", "hello" );
 print $set->size;  # 1. 

=head1 DESCRIPTION

Sets, but weak.  See L<Set::Object/weaken>.

=cut

package Set::Object::Weak;

use base qw(Set::Object);  # boo hiss no moose::role yet I hear you say

use base qw(Exporter);     # my users would hate me otherwise
use vars qw(@ISA @EXPORT_OK);

our @EXPORT_OK = qw(weak_set);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->weaken;
    $self;
}

sub weak_set {
    __PACKAGE__->new(@_);
}

1;
