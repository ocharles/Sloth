package Sloth::Representation;
# ABSTRACT: An object capable of creating a representation of a resource

use Moose::Role;

=method content_type

    $self->content_type

B<Required>. Classes which consume this role must implement this method.

Returns either a string of the content-type that this representation
represents (ie, 'application/xml'), or a regular expression to match
against a content type (ie, qr{.+/.+}).

=method serialize

    $self->serialize($resource);

B<Required>. Classes which consume this role must implement this method.

Takes a resource, returned by processing a L<Sloth::Method>, and creates
a representation of the resource. For example, a JSON representation
might just return the result of L<JSON::Any/encode_json>.

=cut

requires 'content_type', 'serialize';

1;
