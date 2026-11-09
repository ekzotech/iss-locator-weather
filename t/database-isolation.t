use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";
use ISSTrackerTest 'new_tracker';
use Test::More;

my ($first_dir, $second_dir);
my ($first, $second);
($first, $first_dir) = new_tracker();
($second, $second_dir) = new_tracker();
ok -f $first->app->config->{db_path}, 'startup creates the SQLite file';
my $first_db = $first->app->sqlite->db;
my $second_db = $second->app->sqlite->db;

$first_db->query('INSERT INTO observations (observed_at, latitude, longitude) VALUES (?, ?, ?)', 100, 45, 20);
is $first_db->query('SELECT latitude FROM observations')->array->[0], 45, 'first database sees its record';
is $second_db->query('SELECT COUNT(*) FROM observations')->array->[0], 0, 'second database remains empty';

done_testing;
