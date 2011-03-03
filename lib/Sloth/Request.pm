package Sloth::Request;
use Moose;
use namespace::autoclean;

use Plack::Request;

has plack_request => (
    is => 'ro',
    isa => 'Plack::Request',
    required => 1,
    handles => qr{.*}
);

has path_components => (
    required => 1,
    is => 'ro'
);

has router => (
    is => 'ro',
    required => 1
);

=method uri_for

    $self->uri_for(
        resource => 'users',
        name => $user_name,
        { page => $page }
    )

Create a URI from a resource name, set of path components and an optional hash
reference of query parameters.

=cut

sub uri_for {
    my ($self, @args) = @_;
    my $qp = @args % 2 ? pop(@args) : {};
    my $relative = $self->router->uri_for(@args) or return;
    my $uri = $self->base;
    $uri->path($uri->path . $relative);
    $uri->query_form(%$qp);
    return $uri->as_string;
}

1;
