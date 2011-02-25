package Sloth::Resource;
# ABSTRACT: A resource that exposed by the REST server

use Moose::Role;
use namespace::autoclean;

use HTTP::Throwable::Factory 'http_throw';
use Module::Pluggable::Object;
use Plack::Response;

=attr representations

A C<ArrayRef[Sloth::Representation]> of all known representations of resources.

By default, this will be taken from L<Sloth>, your main Sloth application.
However, if this resource only has specific representations that differ from the
rest of you application, you can override it.

=cut

has representations => (
    required => 1,
    isa => 'ArrayRef',
    traits => [ 'Array' ],
    handles => {
        representations => 'elements'
    }
);

=attr methods

A C<Map[MethodName => Sloth::Method>.

A map of allowed HTTP methods on this resource, to their L<Sloth::Method>
implementation. By default you do not need to worry about specifying this
attribute as Sloth will default to looking for methods below the current
resource namespace (for example, C<Resource::Pancake> would look for
C<Resource::Pancake::GET> and so on).

=cut

has methods => (
    isa => 'HashRef',
    is => 'ro',
    required => 1,
    traits => [ 'Hash' ],
    lazy => 1,
    default => sub {
        my $self = shift;
        my $mpo = Module::Pluggable::Object->new(
            search_path => $self->meta->name,
            require => 1
        );
        return {
            map {
                my ($method) = $_ =~ /.*::([a-z]*)$/i;
                uc($method) => $_->new
            } grep {
                $_->does('Sloth::Method')
            } $mpo->plugins
        }
    },
    handles => {
        _method_handler => 'get',
        supported_methods => 'keys'
    }
);

sub _serializer {
    my ($self, $type) = @_;
    for my $rep ($self->representations) {
        return $rep if $type =~ $rep->content_type;
    }
}

=method handle_request

    $self->handle_request($request : Sloth::Request)

Handle a request for a resource.

You will not normally need to change this method, as by default
it will check if the method is allowed, if there is an available
serializer, and handle all the dispatching for you.

=cut

sub handle_request {
    my ($self, $request) = @_;

    my $method = $self->_method_handler($request->method)
        or return http_throw('MethodNotAllowed' => {
            allow => [ $self->supported_methods ]
        });

    my $resource = $method->process_request($request);

    my @accept = $request->header('Accept');
    for my $accept ($request->header('Accept')) {
        my $serializer = $self->_serializer($accept)
            or next;

        return Plack::Response->new(
            200 => [] => $serializer->serialize($resource)
        ) or http_throw('NotAcceptable');
    }

    http_throw('NotAcceptable');
}

1;
