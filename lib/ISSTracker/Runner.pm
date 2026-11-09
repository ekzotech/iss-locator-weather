package ISSTracker::Runner;
use Mojo::Base -base;
use Mojo::IOLoop;
use Mojo::Promise;

has [qw(collector log)];
has loop => sub { Mojo::IOLoop->singleton };
has [qw(_pending _timer)];
has _stopping => 0;

sub start {
  my $self = shift;
  return if $self->_stopping;
  return $self->_timer if defined $self->_timer;
  my $timer = $self->loop->recurring(60 => sub { $self->_tick });
  $self->_timer($timer);
  $self->_tick;
  return $timer;
}

sub stop {
  my $self = shift;
  return if $self->_stopping;
  $self->_stopping(1);
  if (defined(my $timer = $self->_timer)) {
    $self->loop->remove($timer);
    $self->_timer(undef);
  }
  $self->loop->stop unless $self->_pending;
}

sub _tick {
  my $self = shift;
  return if $self->_stopping;
  return $self->_pending if $self->_pending;
  my $work = eval { $self->collector->collect_p } // Mojo::Promise->reject($@);
  my $pending = $work
    ->catch(sub { $self->log->error('Collection cycle failed') })
    ->finally(sub {
      $self->_pending(undef);
      $self->loop->stop if $self->_stopping;
      return;
    });
  $self->_pending($pending);
  return $pending;
}

1;
