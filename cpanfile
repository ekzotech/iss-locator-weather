requires 'perl', '5.026';
requires 'Mojolicious', '9.0';
requires 'Mojo::SQLite';
requires 'DBD::SQLite', '1.78';
requires 'IO::Socket::SSL';

on test => sub {
  requires 'Test::More';
};
