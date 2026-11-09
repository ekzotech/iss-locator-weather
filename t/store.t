use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";
use ISSTrackerTest 'new_tracker';
use Mojo::SQLite;
use Test::More;
use Time::HiRes 'time';

my $dir;
my $tracker;
($tracker, $dir) = new_tracker();
my $store = $tracker->app->store;
my $reader = Mojo::SQLite->new->from_filename($tracker->app->config->{db_path});
my %observation = (
  observed_at => 100, latitude => 45, longitude => 20, weather_status => 'available',
  temperature_c => 0, cloud_cover => 15, weather_code => 1, weather_at => 90
);
is scalar($store->latest), undef, 'empty database has no latest observation';
is $store->record(\%observation), 1, 'one observation inserted';
is_deeply $reader->db->query('SELECT * FROM observations WHERE observed_at = ?', 100)->hash,
  \%observation, 'observation is visible to a separate connection';
is $store->record({%observation, latitude => 46}), 0, 'duplicate timestamp does not insert';
is $reader->db->query('SELECT latitude FROM observations WHERE observed_at = ?', 100)->array->[0],
  45, 'duplicate timestamp preserves original observation';
eval { $store->record({%observation, observed_at => undef}) };
like $@, qr/timestamp is required/, 'missing timestamp cannot create an implicit observation';
$store->record({%observation, observed_at => 99});
is_deeply scalar($store->latest), \%observation, 'latest is selected by observation time';
$store->record({%observation, observed_at => 101});
is_deeply [map { $_->{observed_at} } @{$store->history(2)}], [101, 100],
  'history is newest first and respects the limit';
is_deeply [map { $_->{observed_at} } @{$store->history(2, 100)}], [99],
  'history cursor excludes the previous page';
is_deeply $store->track_recent(1), [
  {observed_at => 100, latitude => 45, longitude => 20},
  {observed_at => 101, latitude => 45, longitude => 20},
], 'track includes recent positions in chronological order';

my $locked_db = $reader->db;
$locked_db->query('BEGIN IMMEDIATE');
my $writer_db = $tracker->app->sqlite->db;
is $writer_db->dbh->sqlite_busy_timeout, 5000, 'application waits for SQLite locks';
$writer_db->dbh->sqlite_busy_timeout(100);
my $started = time;
eval { $writer_db->query('UPDATE observations SET longitude = longitude WHERE observed_at = 100') };
like $@, qr/database is locked/, 'a lock held past the deadline is reported';
cmp_ok time - $started, '>=', 0.08, 'the writer waits before reporting contention';
$locked_db->query('ROLLBACK');
is $writer_db->query('UPDATE observations SET longitude = longitude WHERE observed_at = 100')->rows,
  1, 'the write can be retried after the lock is released';
undef $writer_db;
undef $locked_db;

my $saved_path = $tracker->app->config->{db_path};
undef $reader;
undef $store;
undef $tracker;
{
  local $ENV{ISS_TRACKER_DB} = $saved_path;
  my $restarted = ISSTracker->new;
  is_deeply $restarted->store->history(3), [
    {%observation, observed_at => 101}, \%observation, {%observation, observed_at => 99}
  ], 'startup migrations preserve existing observations after reopening';
}

done_testing;
