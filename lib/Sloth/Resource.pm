package Sloth::Resource;
# ABSTRACT: A resource that exposed by the REST server

use Moose::Role;
use namespace::autoclean;

use HTTP::Throwable::Factory 'http_throw';
use Module::Pluggable::Object;
use REST::Utils qw( best_match );
use Scalar::Util qw( blessed );
use String::CamelCase 'decamelize';
use Try::Tiny;

has c => (
    is => 'ro'
);

=method resource_arguments

    $self->resource_arguments : @List

Generate a set of parameters that will be passed to methods. If your methods
all require a set of common, shared objects, you can override this to provide
those extra initialization arguments.

=cut

sub resource_arguments {
    return ( c => shift->c );
}

=attr representations

A C<Map[Str => Sloth::Representation]> of all known representations of resources.

By default, this will be taken from L<Sloth>, your main Sloth application.
However, if this resource only has specific representations that differ from the
rest of you application, you can override it.

=cut

has representations => (
    required => 1,
    isa => 'HashRef',
    traits => [ 'Hash' ],
    handles => {
        representations => 'values',
        accepts => 'keys',
        representation => 'get'
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
                uc($method) => $_->new($self->resource_arguments);
            } grep {
                $_->does('Sloth::Method')
            } $mpo->plugins
        }
    },
    handles => {
        _method_handler => 'get',
        _method_handlers => 'values',
        supported_methods => 'keys'
    }
);

has router => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $router = Path::Router->new
    }
);

has path => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has _routes => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        return [
            map {
                my $router = Path::Router->new;
                $router->add_route(
                    $_->path => (
                        defaults => {
                            resource => $self->name,
                        },
                        target => $self
                    )
                );
                $router;
            } $self->_method_handlers
        ];
    }
);

has name => (
    is => 'ro',
    default => sub {
        my $self = shift;
        my ($name) = $self->meta->name =~ /^.*::(.*)$/;
        return decamelize($name);
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

    my $serializer;
    if($self->accepts and my $best_match = best_match(
        [ $self->accepts ],
        $request->header('Accept')
    )) {
        $serializer = $self->representation($best_match);
    }

    try {
        # This is done in 2 steps because we might not need to serialize if we
        # throw a 2xx exception.
        return $method->process_request($request, $serializer);
    }
    catch {
        if(blessed($_) && $_->does('HTTP::Throwable')) {
            $_->throw;
        }
        else {
            $_
                ? http_throw(BadRequest => { message => $_ || '' })
                : http_throw('BadRequest')
        }
    };
}

1;
