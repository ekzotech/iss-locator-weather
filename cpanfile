requires 'perl', '5.026';
requires 'Mojolicious', '9.0';
requires 'Mojo::SQLite';

on test => sub {
  requires 'Test::More';
};
