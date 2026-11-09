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
  my $db_path = $ENV{ISS_TRACKER_DB};
  $self->config->{db_path} = defined($db_path) && length($db_path)
    ? path($db_path)->to_abs->to_string
    : $root->child('var', 'observations.sqlite')->to_string;
}

1;
