package Redis::hiredis;

use strict;
our $VERSION = "0.0.2";
require XSLoader;
XSLoader::load('Redis::hiredis', $VERSION);

1;
__END__

=head1 NAME

Redis::hiredis - interact with Redis using the hiredis client.

=head1 SYNOPSIS

  use Redis::hiredis;
  my $redis = Redis::hiredis->new();
  $redis->connect('127.0.0.1', 6379);
  $redis->command([qw(set foo bar)]);
  my $val = $redis->command([qw(get foo)]);

=head1 DESCRIPTION

C<Redis::hiredis> is a simple wrapper around Salvatore Sanfilippo's
hiredis C client that allows connecting and sending any command
just like you would from a command line Redis client.

=head2 METHODS

=over 4

=item new()

Creates a new Redis::hiredis object.

=item connect( $hostname, $port )

C<$hostname> is the hostname of the Redis server to connect to

C<$port> is the port to connect on.  Default 6379

=item command( $command )

C<$command> is an array ref of the command and parameters you would like
to send to Redis ex:

  [qw( set foo bar )]

command will return a scalar value which will either be an integer, string
or an array ref (if multiple values are returned).

=back

=head1 SEE ALSO

The Redis command reference can be found here:
F<http://code.google.com/p/redis/wiki/CommandReference>

Documentation on the hiredis client can be found here:
F<http://github.com/antirez/hiredis>

=cut
