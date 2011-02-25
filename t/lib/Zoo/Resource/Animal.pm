package Zoo::Resource::Animal;
use Moose;
with 'Sloth::Resource';

sub path { '/animal/:name' }

1;
