use strict;
use warnings;
use Test::More;
use Test::Exception;

plan skip_all => q/$ENV{'REDISHOST'} isn't set/
    if !defined $ENV{'REDISHOST'};

{
    use_ok 'Redis::hiredis';
    my $h = Redis::hiredis->new();
    isa_ok $h, 'Redis::hiredis';

    my $host = $ENV{'REDISHOST'};
    my $port = $ENV{'REDISPORT'} || 6379;

    #
    # bad connect
    #
    throws_ok
        sub { $h->connect('fake_host', $port) },
        qr/Can't resolve: fake_host/,
        'connect failed correctly';

    lives_ok
        sub { $h->connect($host, $port) },
        'connect worked';

    #
    # bad command
    #
    throws_ok
        sub { $h->command( 'NO_SUCH_CMD' ) },
        qr/ERR unknown command 'NO_SUCH_CMD'/,
        'command failed correctly';

    #
    # partially bad pipeline
    #
    lives_ok
        sub { $h->append_command('BAD_CMD0') },
        'append_command 0 worked';

    lives_ok
        sub { $h->append_command('PING') },
        'append_command 0 worked';

    lives_ok
        sub { $h->append_command('BAD_CMD2') },
        'append_command 0 worked';

    throws_ok
        sub { $h->get_reply() },
        qr/ERR unknown command 'BAD_CMD0'/,
        'pipeline cmd 0 failed correctly';

    lives_ok
        sub { $h->get_reply() },
        'pipeline cmd 1 worked';

    throws_ok
        sub { $h->get_reply() },
        qr/ERR unknown command 'BAD_CMD2'/,
        'pipeline cmd 2 failed correctly';
};

done_testing();
