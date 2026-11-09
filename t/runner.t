use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use ISSTracker::Runner;
use Mojo::Log;
use Mojo::Promise;
use Test::More;

{
  package Local::Timer;
  use Mojo::Base -base;
  has [qw(interval callback)];
  has [qw(removed stopped)];
  sub recurring {
    my ($self, $interval, $callback) = @_;
    $self->interval($interval)->callback($callback);
    return 'timer';
  }
  sub remove { $_[0]->removed($_[1])->callback(undef) }
  sub stop { $_[0]->stopped(1) }
}

{
  package Local::Collector;
  use Mojo::Base -base;
  has calls => 0;
  has 'pending';
  sub collect_p {
    my $self = shift;
    $self->calls($self->calls + 1);
    my $pending = Mojo::Promise->new;
    $self->pending($pending);
    return $pending;
  }
}

my $timer = Local::Timer->new;
my $collector = Local::Collector->new;
my $runner = ISSTracker::Runner->new(loop => $timer, collector => $collector, log => Mojo::Log->new);
is $runner->start, 'timer', 'collector installs its timer';
is $collector->calls, 1, 'first cycle starts immediately';
is $timer->interval, 60, 'future cycles are scheduled once a minute';
is $runner->start, 'timer', 'starting again reuses the existing timer';
my $first_cycle = $timer->callback->();
is $collector->calls, 1, 'timer tick skips a cycle while the previous one is in flight';
$collector->pending->resolve(1);
$first_cycle->wait;
my $second_cycle = $timer->callback->();
is $collector->calls, 2, 'timer starts the next collection cycle';
my $stale_tick = $timer->callback;
$runner->stop;
is $timer->removed, 'timer', 'shutdown removes the recurring timer';
ok !$timer->stopped, 'shutdown waits for the active cycle';
$stale_tick->();
is $collector->calls, 2, 'a callback already queued cannot start another cycle';
$collector->pending->resolve(1);
$second_cycle->wait;
ok $timer->stopped, 'loop stops once the active cycle has finished';

done_testing;
