package ISSTracker::Command::collect;
use Mojo::Base 'Mojolicious::Command';
use ISSTracker::Runner;

has description => 'Collect ISS positions and weather every minute';
has usage => "Usage: APPLICATION collect [--once]\n";

sub run {
  my ($self, @args) = @_;
  die $self->usage if @args && (@args != 1 || $args[0] ne '--once');
  unless (@args) {
    my $runner = ISSTracker::Runner->new(collector => $self->app->collector, log => $self->app->log);
    $runner->start;
    $runner->loop->start;
    return;
  }
  my $error;
  $self->app->collector->collect_p->catch(sub { $error = shift })->wait;
  die "Collection failed: $error\n" if defined $error;
  return;
}

1;
