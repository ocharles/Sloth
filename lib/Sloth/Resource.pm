package Sloth::Resource;
use Moose::Role;
use namespace::autoclean;

use HTTP::Throwable::Factory 'http_throw';
use Module::Pluggable::Object;
use Plack::Response;

has representations => (
    required => 1,
    isa => 'ArrayRef',
    traits => [ 'Array' ],
    handles => {
        representations => 'elements'
    }
);

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
        method_handler => 'get',
        supported_methods => 'keys'
    }
);

sub serializer {
    my ($self, $type) = @_;
    for my $rep ($self->representations) {
        return $rep if $type =~ $rep->content_type;
    }
}

sub handle_request {
    my ($self, $request) = @_;

    my $method = $self->method_handler($request->method)
        or return http_throw('MethodNotAllowed' => {
            allow => [ $self->supported_methods ]
        });

    my $resource = $method->process_request($request);

    my @accept = $request->header('Accept');
    for my $accept ($request->header('Accept')) {
        my $serializer = $self->serializer($accept)
            or next;

        return Plack::Response->new(
            200 => [] => $serializer->serialize($resource)
        ) or http_throw('NotAcceptable');
    }

    http_throw('NotAcceptable');
}

1;
