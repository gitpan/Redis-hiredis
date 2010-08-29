use Test::More tests => 10;
require_ok ( 'Redis::hiredis' );
my $h = Redis::hiredis->new();
isa_ok($h, 'Redis::hiredis');

my $host = $ENV{'REDISHOST'} || 'localhost';
my $port = $ENV{'REDISPORT'} || 6379;

my $r;
my $c = $h->connect($host, $port);
is($c, undef, 'connect success');

my $prefix = "Redis-hiredis-$$-";

$r = $h->command(['multi']);
is($r, 'OK', 'multi');

$h->command(["set", $prefix."foo", "foo"]);
$h->command(["set", $prefix."bar", "bar"]);
$h->command(["set", $prefix."baz", "baz"]);

$r = $h->command(['exec']);
ok(ref $r eq 'ARRAY', 'exec');
is($r->[0], 'OK', 'exec 0');
is($r->[1], 'OK', 'exec 1');
is($r->[2], 'OK', 'exec 2');


$h->command(['multi']);
$h->command(["set", $prefix."foo", "bar"]);
$r = $h->command(['discard']);
is($r, 'OK', 'discard');

$r = $h->command(['get', $prefix.'foo']);
is($r, 'foo', 'discard');
