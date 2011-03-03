package Sloth::Method;
# ABSTRACT: The implementation of a single HTTP method on a resource

use Moose::Role;

use Data::TreeValidator::Sugar qw( branch );
use HTTP::Throwable::Factory qw( http_throw );
use Try::Tiny;

has c => (
    is => 'ro',
);

=method execute

    $self->execute($cleaned_parameters)

B<Required>. Classes which consume this role must implement this method.

Executes the implemented HTTP method (for example a GET or DELETE operation)
and optionally returns a resource to represent back to the user. Takes an
object that represents the cleaned input parameters - a combination of
path arguments, query paramaters and the parsed body (if there was one).

=cut

requires 'execute';

=attr request_parsers

A C<Map[ContentType => Sloth::RequestParser].

This map defines a list of parsers that are able to parse the body of
a HTTP request into a meaningful, but more importantly, I<common>, set
of input parameters.

If this is left undefined it is assumed that a body is not meant to be
provided to the method, and that all necessary parameters can be derived
from the URI query parameters and path parts.

=cut

has request_parsers => (
    is => 'ro',
    traits => [ 'Hash' ],
    isa => 'HashRef',
    predicate => 'handles_content_types',
    handles => {
        request_parser => 'get',
        supported_content_types => 'keys'
    }
);

=attr request_data_validator

A L<Data::TreeValidator> validator.

This takes the input from query parameters, path parts, and possibly the parsed
request body, and validates it. It can optionally transform the data, and will
finally return a set of clean input parameters which are passed to L</execute>.

=cut

has request_data_validator => (
    is => 'ro',
    default => sub {
        branch { }
    }
);

=attr process_request

    $self->process_request($request : Sloth::Request)

Process a L<Sloth::Request> and possibly return a resource.

You usually won't need to override this method, as by default it does the
boiler plate plumbing for you (checking the Accept header, trying to parse
the body, etc). Most users will simply need to implement L</execute>.

=cut

sub process_request {
    my ($self, $request) = @_;

    my %args = %{ $request->path_components };
    if ($self->handles_content_types) {
        my $parser = $self->request_parser($request->header('Content-Type'))
            or http_throw('UnsupportedMediaType');

        %args = $parser->parse($request);
    }
    else {
        %args = (
            %{ $request->query_parameters },
            %args,
        );
    }

    my $result = $self->request_data_validator->process({ %args });

    http_throw('BadRequest' => {
        message => join(' ', _collect_errors($result))
    })
        unless $result->valid;

    $self->execute($result->clean, $request);
}

sub _collect_errors {
    my ($result) = @_;
    my @child;
    if (my $child = $result->can('results')) {
        push @child, _collect_errors($_)
            for $result->results;
    }
    return (
        $result->errors,
        @child
    );
}

has path => (
    isa => 'Str',
    default => '',
    is => 'ro'
);

1;
