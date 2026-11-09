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

my $insert = 'INSERT INTO observations (observed_at, latitude, longitude) VALUES (?, ?, ?)';
$first_db->query($insert, 101, -90, 180);
for my $coordinates ([91, 0], [0, -181], ['invalid', 0]) {
  eval { $first_db->query($insert, 102, @$coordinates) };
  like $@, qr/coordinates out of range/, "invalid coordinates @$coordinates are rejected";
}
eval { $first_db->query('UPDATE observations SET longitude = 181 WHERE observed_at = 100') };
like $@, qr/coordinates out of range/, 'invalid update is rejected';

my $weather_status = sub {
  $first_db->query('SELECT weather_status FROM observations WHERE observed_at = 100')->array->[0];
};
is $weather_status->(), 'unavailable', 'weather defaults to unavailable';
$first_db->query('UPDATE observations SET weather_status = ? WHERE observed_at = 100', 'water');
is $weather_status->(), 'water', 'water status is preserved';
eval { $first_db->query('UPDATE observations SET weather_status = ? WHERE observed_at = 100', 'unknown') };
like $@, qr/CHECK constraint failed/, 'unknown weather status is rejected';

$first_db->query(q{
  UPDATE observations
  SET weather_status = 'available', temperature_c = 0, cloud_cover = 0, weather_code = 0, weather_at = 90
  WHERE observed_at = 100
});
is_deeply $first_db->query(q{
  SELECT temperature_c, cloud_cover, weather_code, weather_at FROM observations WHERE observed_at = 100
})->array, [0, 0, 0, 90], 'weather zeros and model timestamp are stored';

done_testing;
