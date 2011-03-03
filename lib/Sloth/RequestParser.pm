package Sloth::RequestParser;
# ABSTRACT: An object that can parse requests into hash references
use Moose::Role;

=method parse

    $self->parse($request : L<Sloth::Request>)

B<Required>. Classes which consume this role must implement this method.

Parses a request into a hash reference.

=cut

requires 'parse';

1;
