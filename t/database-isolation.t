use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";
use ISSTrackerTest 'new_tracker';
use Mojo::SQLite;
use Test::More;

my ($first, $first_dir) = new_tracker();
my ($second, $second_dir) = new_tracker();
my $db_for = sub { Mojo::SQLite->new->from_filename(shift->app->config->{db_path})->db };
my $first_db = $db_for->($first);
my $second_db = $db_for->($second);

for my $db ($first_db, $second_db) {
  $db->query('CREATE TABLE isolation_probe (value TEXT)');
}
$first_db->query('INSERT INTO isolation_probe VALUES (?)', 'first');
is $first_db->query('SELECT value FROM isolation_probe')->array->[0], 'first', 'first database sees its record';
is $second_db->query('SELECT COUNT(*) FROM isolation_probe')->array->[0], 0, 'second database remains empty';

done_testing;
