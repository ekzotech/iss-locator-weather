package ISSTracker::Runner;
use Mojo::Base -base;
use Mojo::IOLoop;

has [qw(collector log)];
has loop => sub { Mojo::IOLoop->singleton };

sub start {
  my $self = shift;
  my $timer = $self->loop->recurring(60 => sub { $self->_tick });
  $self->_tick;
  return $timer;
}

sub _tick {
  my $self = shift;
  return $self->collector->collect_p->catch(sub { $self->log->error('Collection cycle failed') });
}

1;
