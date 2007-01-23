
=head1 NAME

Set::Object::Weak - Sets without the referant reference increment

=head1 SYNOPSIS

 use Set::Object::Weak qw(weak_set);

 my $set = Set::Object::Weak->new( 0, "", {}, [], $object );
 # or
 my $set = weak_set( 0, "", {}, [], $object );

 print $set->size;  # 2 - the scalars aren't objects

=head1 DESCRIPTION

Sets, but weak.  See L<Set::Object/weaken>.

Note that the C<set> in C<Set::Object::Weak> returns weak sets.  This
is intentional, so that you can make all the sets in scope weak just
by changing C<use Set::Object> to C<use Set::Object::Weak>.

=cut

package Set::Object::Weak;

use base qw(Set::Object);  # boo hiss no moose::role yet I hear you say

use base qw(Exporter);     # my users would hate me otherwise
use vars qw(@ISA @EXPORT_OK);

our @EXPORT_OK = qw(weak_set set);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new();
    $self->weaken;
    $self->insert(@_);
    $self;
}

sub weak_set {
    __PACKAGE__->new(@_);
}

sub set {
    __PACKAGE__->new();
}

1;

__END__

=head1 SEE ALSO

L<Set::Object>

=head1 CREDITS

Perl magic by Sam Vilain, <samv@cpan.org>

Idea from nothingmuch.
