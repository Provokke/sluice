use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

use Sluice;

my @lines = (
    '203.0.113.9 - - [10/Oct/2026:13:55:36 +1000] "GET /index.html HTTP/1.1" 200 2326 "-" "Mozilla/5.0"',
    '203.0.113.9 - alice [10/Oct/2026:13:58:01 +1000] "GET /about HTTP/1.1" 200 512 "-" "Mozilla/5.0"',
    '198.51.100.4 - - [10/Oct/2026:14:02:10 +1000] "POST /api/orders HTTP/1.1" 500 - "-" "curl/8.5"',
    '198.51.100.4 - - [10/Oct/2026:14:02:11 +1000] "GET /index.html HTTP/1.1" 304 0',
    '192.0.2.77 - - [10/Oct/2026:15:40:00 +1000] "GET /missing HTTP/1.1" 404 153 "-" "Mozilla/5.0"',
    'this is not a log line',
);

my $rec = Sluice::parse_line($lines[1]);
is $rec->{host},   '203.0.113.9', 'host';
is $rec->{user},   'alice',       'user';
is $rec->{method}, 'GET',         'method';
is $rec->{path},   '/about',      'path';
is $rec->{status}, 200,           'status';
is $rec->{bytes},  512,           'bytes';
is $rec->{agent},  'Mozilla/5.0', 'agent';

is Sluice::parse_line($lines[2])->{bytes}, 0, 'dash bytes become zero';
is Sluice::parse_line($lines[3])->{agent}, '', 'common log format has no agent';
ok !defined Sluice::parse_line($lines[5]), 'junk is rejected';

my $all = Sluice->new;
$all->add_line($_) for @lines;
is $all->total,     5,    'total';
is $all->malformed, 1,    'malformed';
is $all->bytes,     2991, 'bytes summed';

my @paths = $all->top('path', 1);
is_deeply \@paths, [ [ '/index.html', 2 ] ], 'top path';

my @hosts = $all->top('host');
is_deeply [ map { $_->[0] } @hosts ], [ '198.51.100.4', '203.0.113.9', '192.0.2.77' ], 'ties break by name';

is_deeply $all->classes, { '2xx' => 2, '3xx' => 1, '4xx' => 1, '5xx' => 1 }, 'classes';
is sprintf('%.2f', $all->error_rate), '0.20', 'error rate';
is_deeply [ sort keys %{ $all->{hour} } ], [ '13', '14', '15' ], 'hours';

my $errors = Sluice->new(filter => Sluice::make_filter(class => 5));
$errors->add_line($_) for @lines;
is $errors->total, 1, 'class filter';

my $posts = Sluice->new(filter => Sluice::make_filter(method => 'post', path => '^/api/'));
$posts->add_line($_) for @lines;
is $posts->total, 1, 'method and path filter';

is Sluice::human_bytes(512),     '512 B',  'bytes';
is Sluice::human_bytes(2048),    '2.0 KB', 'kilobytes';
is Sluice::human_bytes(5 * 1024**2), '5.0 MB', 'megabytes';

open my $fh, '<', \join("\n", @lines, '') or die $!;
my $from_handle = Sluice->new->add_handle($fh);
is $from_handle->total, 5, 'handle input';

like $all->report(3), qr/requests\s+5/, 'report has totals';
is $all->summary->{path}[0]{key}, '/index.html', 'summary';

eval { $all->top('nope') };
like $@, qr/unknown field/, 'unknown field dies';

done_testing;

