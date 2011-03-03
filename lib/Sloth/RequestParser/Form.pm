package Sloth::RequestParser::Form;
# ABSTRACT: A request parser for application/x-www-urlencoded data
use Moose;

with 'Sloth::RequestParser';

=method parse

Parse a request by extracting a hash reference of body parameters.

=cut

sub parse {
    my ($self, $request) = @_;
    return %{ $request->body_parameters };
}

1;
