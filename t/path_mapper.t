use strict;
use warnings;

use Test::More tests => 28;

use Path::Mapper;

my $mapper = Path::Mapper->new(
    'a/b/c' => 'ABC',
    '/date/:year/:month/:day' => 'Date',
);

isa_ok($mapper, 'Path::Mapper', 'Path::Mapper->new');

$mapper->add_handler('/date/:year/:day/:month/US' => 'Date');

# lots of different versions of the same path, all should match the same
my @variations = (
    'date/2012/12/25',
    '/date/2012/12/25',
    '/date/2012/12/25/',
    'date/2012/12/25/',
    '//date//2012/12/25',
    '/date/2012/25/12/US',
    'date/2012/25/12/US',
);

for my $path (@variations) {
    my $match = $mapper->lookup($path);
    ok $match, "lookup('$path')";
    is $match->handler, 'Date', '.. mapped to Date';
    is_deeply(
        $match->variables,
        { year => 2012, month => 12, day => 25 },
        '.. correct variables'
    );
}

is $mapper->lookup('/a/b/c/')->handler, 'ABC', "lookup('/a/b/c/')";

my @misses = (
    'date',
    'date/2012',
    'date/2012/12',
    'date/2012/12/25/UK',
);

for my $path (@misses) {
    ok !defined $mapper->lookup($path), "lookup('$path') does not match";
}

is_deeply(
    [ qw( ABC Date )],
    [ sort $mapper->handlers ],
    'handlers()'
);
