package Sloth;
# ABSTRACT: A PSGI compatible REST framework

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

=method resource_arguments

    $self->resource_arguments : @List

Generate a set of parameters that will be passed to resources. If your resources
all require a set of common, shared objects, you can override this to provide
those extra initialization arguments.

=cut

sub resource_arguments { }

=attr representations

A C<ArrayRef[Sloth::Representation]> of all known representations of resources.

=cut

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

=attr resources

A C<ArrayRef[Sloth::Resource]> of all servable resources.

=cut

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

=attr router

A L<Path::Router> defining the possible URIs in this API. Each path in
the router is expected to have a C<target> that points to a
L<Sloth::Resource>.

=cut

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

=method call

    $self->call($psgi_env : HashRef)

Entry point for each request. This is called for you via the PSGI
specification from your server.

=cut

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

=head1 SYNOPSIS

    # app.psgi
    use strict;
    use warnings;

    # See Sloth::Manual for more information on building MyApp
    use MyApp;
    MyApp->new;

=head1 DESCRIPTION

Sloth is a framework for building a RESTful Web service. Sloth allows you
to define resources, methods to operate on these resources, and representations
of these resources and their results, while doing the plumbing to bind it all
together for you.

Sloth is also a PSGI basedframework. This means that it is a framework that
can be deployed on PSGI compatible server software, such as L<Starman>,
L<Twiggy>, but also standard server such as Apache and anything that can
understand FastCGI.

=head2 WHY?

Sloth was born out of the L<MusicBrainz|http://musicbrainz.org> project while
refactoring our existing L<Catalyst> REST controllers. They were considerably
tied to a single representation (XML), and had a large amount of plumbing.
The state of the art in terms of Catalyst has got better (see
L<Catalyst::Action::REST> for example), however I still think we can do better.

I also wanted felt that I didn't need the entire Catalyst stack, and that
by rolling something domain-specific I could by at lot more concise in
specifying the necessary logic. By using PSGI, we benefit immediately from
potential high performance, by hosting on servers that speak directly to
PSGI, too - and as our web service accounted for 90% of traffic, performance
was certainly a motivating factor!

=head1 IMPORTANT DOCUMENTATION

The following pieces of documentation are what I consider to be key to
understanding how to use Sloth:

=over 4

=item L<Sloth::Manual::Architecture>

Explains how the various parts of Sloth interact with each other, how they are
glued together by default, and how you can replace this with your own glue.

=item L<Sloth::Manual::Tutorial>

Looks at building a RESTful Web service for a Zoo, and looks at displaying
resources in various representations, and handling various HTTP methods.

=back

=cut
