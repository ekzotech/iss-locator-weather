package ISSTracker::Command::collect;
use Mojo::Base 'Mojolicious::Command';

has description => 'Collect one ISS position and its weather';
has usage => "Usage: APPLICATION collect [--once]\n";

sub run {
  my ($self, @args) = @_;
  die $self->usage if @args && (@args != 1 || $args[0] ne '--once');
  my $error;
  $self->app->collector->collect_p->catch(sub { $error = shift })->wait;
  die "Collection failed: $error\n" if defined $error;
  return;
}

1;
