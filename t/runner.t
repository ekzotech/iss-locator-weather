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
  sub recurring {
    my ($self, $interval, $callback) = @_;
    $self->interval($interval)->callback($callback);
    return 'timer';
  }
}

{
  package Local::Collector;
  use Mojo::Base -base;
  has calls => 0;
  sub collect_p {
    my $self = shift;
    $self->calls($self->calls + 1);
    return Mojo::Promise->resolve(1);
  }
}

my $timer = Local::Timer->new;
my $collector = Local::Collector->new;
my $runner = ISSTracker::Runner->new(loop => $timer, collector => $collector, log => Mojo::Log->new);
is $runner->start, 'timer', 'collector installs its timer';
is $collector->calls, 1, 'first cycle starts immediately';
is $timer->interval, 60, 'future cycles are scheduled once a minute';
$timer->callback->()->wait;
is $collector->calls, 2, 'timer starts the next collection cycle';

done_testing;
