package Sloth;
use Moose;
use MooseX::NonMoose;

use aliased 'Sloth::Request';

use HTTP::Throwable::Factory qw(http_throw);
use Module::Pluggable::Object;
use Moose::Util qw( does_role );
use Path::Router;
use Plack::Request;
use Try::Tiny;

extends 'Plack::Component';

sub resource_arguments { }

has representations => (
    is => 'ro',
    default => sub {
        my $self = shift;
        my $prefix = $self->meta->name . '::Representation';
        return [
            map {
                $_->new
            } grep {
                does_role($_ => 'Sloth::Representation');
            } Module::Pluggable::Object->new(
                search_path => $prefix,
                require => 1
            )->plugins
        ];
    },
    lazy => 1
);

has resources => (
    default => sub {
        my $self = shift;
        my $prefix = $self->meta->name . '::Resource';
        return {
            map {
                my ($name) = $_ =~ /${prefix}::(.*)$/;
                $name => $_->new(
                    representations => $self->representations,
                    $self->resource_arguments
                )
            } grep {
                does_role($_ => 'Sloth::Resource');
            } Module::Pluggable::Object->new(
                search_path => $prefix,
                require => 1
            )->plugins
        };
    },
    traits => [ 'Hash' ],
    handles => {
        resource => 'get',
        resources => 'values'
    },
    lazy => 1,
);

has router => (
    is => 'ro',
    default => sub {
        my $self = shift;
        my $router = Path::Router->new;
        for my $resource ($self->resources) {
            $router->add_route(
                $resource->path => (
                    target => $resource
                )
            );
        }
        return $router;
    },
    lazy => 1
);

sub call {
    my ($self, $env) = @_;
    my $request = Plack::Request->new($env);

    my $ret = try {
        if(my $route = $self->router->match($request->path)) {
            return $route->target->handle_request(
                Request->new(
                    plack_request => $request,
                    path_components => $route->mapping
                )
            )->finalize;
        }
        else {
            http_throw('NotFound');
        }
    } catch {
        $_->as_psgi;
    };

    return $ret;
};

1;
