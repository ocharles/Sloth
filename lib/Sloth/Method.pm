package Sloth::Method;
use Moose::Role;

use Data::TreeValidator::Sugar qw( branch );
use HTTP::Throwable::Factory qw( http_throw );
use Try::Tiny;

requires 'execute';

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

has request_data_validator => (
    is => 'ro',
    default => sub {
        branch { }
    }
);

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

    $self->execute($result->clean);
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

1;
