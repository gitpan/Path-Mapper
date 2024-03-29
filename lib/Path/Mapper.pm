package Path::Mapper;

use strict;
use warnings;

=head1 NAME

Path::Mapper - map paths to handlers

=head1 VERSION

0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    my $mapper = Path::Mapper->new(
        '/x/y/z' => 'XYZ',
        '/a/b/c' => 'ABC',
        '/a/b'   => 'AB',

        '/date/:year/:month/:day' => 'Date',
    );

    if (my $match = $mapper->lookup('/date/2013/12/25')) {
        # $match->handler is 'Date'
        # $match->variables is { year => 2012, month => 12, day => 25 }
    }

    # Add more mappings later
    $mapper->add_handler($path => $target)

=head1 DESCRIPTION

This class maps paths to handlers. The paths can contain variable path
segments, which match against any incoming path segment, where the matching
segments are saved as named variables for later retrieval.

Note that the handlers being mapped to can be any arbitrary data, not just
strings as illustrated in the synopsis.

=head2 Comparison with Path::Router

This class fulfills some of the same jobs as L<Path::Router>, with slightly
different design goals. Broadly speaking, Path::Mapper is a lighter, faster,
but less featureful version of Path::Router.

I've listed a few points of difference here to help highlight the pros and
cons of each class.

=over

=item Speed

The main goal for Path::Mapper is lookup speed. Path::Router uses regexes to
do lookups, but Path::Mapper uses hash lookups. Path::Mapper seems to be at
least an order of magnitude faster based on my benchmarks, and performance
doesn't degrade with the number of routes that are added. The main source of
performance degradation for Path::Mapper is path I<depth>, Path::Router
degrades less with depth but more with width.

This approach also means that the order in which routes are added makes no
difference to Path::Mapper.

=item Reversibility

Path::Router has a specific aim of being reversible. That is to say you can
construct a path from a set of parameters. Path::Mapper does not currently
have this ability, patches welcome!

=item Validation

Path::Mapper has no built-in ability to validate path variables in any way.
Obviously validation can be done externally after the fact, but that doesn't
allow for the more complex routing rules possible in Path::Router. 

In other words, it's not possible for Path::Mapper to differentiate two path
templates which differ only in the variable segments (e.g. C<< /blog/:name >>
vs C<< /blog/:id >> where C<id> matches C<\d+> and C<name> matches C<\D+>).

=item Dependencies

Path::Mapper has a very small dependency chain, whereas Path::Router is based
on L<Moose>, so has a relatively high dependency footprint. If you're already
using Moose, there's obviously no additional cost in using Path::Router.

=back

=cut

use List::Util qw( reduce );
use List::MoreUtils qw( uniq natatime );

use Path::Mapper::Match;

=head1 METHODS

=head2 new

    $mapper = $class->new(@pairs)

The constructor.

Takes an even-sized list and passes each pair to L</add_handler>.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    my $iterator = natatime 2, @_;
    while (my @pair = $iterator->()) {
        $self->add_handler(@pair);
    }

    return $self;
}

=head2 add_handler

    $mapper->add_handler($path_template, $handler)

Adds a single item to the mapping.

The path template should be a string comprising slash-delimited path segments,
where a path segment may contain any character other than the slash. Any
segment beginning with a colon (C<:>) denotes a mandatory named variable.
Empty segments, including those implied by leading or trailing slashes are
ignored.

For example, these are all identical path templates:

    /a/:var/b
    a/:var/b/
    //a//:var//b//

The order in which these templates are added has no bearing on the lookup,
except that later additions with identical templates overwrite earlier ones.

=cut

sub add_handler {
    my ($self, $path, $handler) = @_;
    my $class = ref $self;

    my @parts = $self->_tokenise_path($path);
    my @vars;
    my $mapper = reduce {
        $b =~ s{^:(.*)}{/} and push @vars, $1;
        $a->_map->{$b} ||= $class->new;
    } $self, @parts;

    $mapper->_set_target($handler);
    $mapper->_set_variables(\@vars);

    return;
}

=head2 lookup

    $match = $mapper->lookup($path)

Returns a L<Path::Mapper::Match> object if the path matches a known path
template, C<undef> otherwise.

The two main methods on the match object are:

=over

=item handler

The handler that was matched, identical to whatever was originally passed to
L</add_handler>.

=item variables

The named path variables as a hashref.

=back

=cut

sub lookup {
    my ($mapper, $path) = @_;

    my @parts = $mapper->_tokenise_path($path);
    my @values;

    while () {
        if (my $segment = shift @parts) {
            my $map = $mapper->_map;

            my $next;
            if ($next = $map->{$segment}) {
                # Nothing
            }
            elsif ($next = $map->{'/'}) {
                push @values, $segment;
            }
            else {
                return undef;
            }

            $mapper = $next;
        }
        elsif (defined $mapper->_target) {
            return Path::Mapper::Match->new(
                mapper => $mapper,
                values => \@values
            );
        }
        else {
            return undef;
        }
    }
}

=head2 handlers

    @handlers = $mapper->handlers()

Returns all of the handlers in no particular order.

=cut

sub handlers {
    my $self = shift;

    return uniq(
        grep defined, $self->_target, map $_->handlers, values %{ $self->_map }
    );
}

sub _tokenise_path {
    my ($self, $path) = @_;

    return grep length, split '/', $path;
}

sub _map { $_[0]->{map} ||= {} }

sub _target     { $_[0]->{target} }
sub _set_target { $_[0]->{target} = $_[1] }

sub _variables     { $_[0]->{vars} || [] }
sub _set_variables { $_[0]->{vars} = $_[1] }

=head1 SEE ALSO

L<Path::Router>

=head1 AUTHOR

Matt Lawrence E<lt>mattlaw@cpan.orgE<gt>

=head1 COPYRIGHT

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

1;
