package ISSTracker;
use Mojo::Base 'Mojolicious';
use Mojo::File 'path';
use Mojo::Home;

my $root = path(__FILE__)->to_abs->dirname->dirname;

sub startup {
  my $self = shift;
  $self->home(Mojo::Home->new($root));
  $self->renderer->paths([$root->child('templates')]);
  $self->static->paths([$root->child('public')]);
}

1;
