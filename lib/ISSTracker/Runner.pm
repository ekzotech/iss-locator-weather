package ISSTracker::Runner;
use Mojo::Base -base;
use Mojo::IOLoop;

has [qw(collector log)];
has loop => sub { Mojo::IOLoop->singleton };
has [qw(_pending _timer)];

sub start {
  my $self = shift;
  return $self->_timer if defined $self->_timer;
  my $timer = $self->loop->recurring(60 => sub { $self->_tick });
  $self->_timer($timer);
  $self->_tick;
  return $timer;
}

sub _tick {
  my $self = shift;
  return $self->_pending if $self->_pending;
  my $pending = $self->collector->collect_p
    ->catch(sub { $self->log->error('Collection cycle failed') })
    ->finally(sub { $self->_pending(undef) });
  $self->_pending($pending);
  return $pending;
}

1;
