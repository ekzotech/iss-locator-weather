package ISSTrackerTest;
use strict;
use warnings;
use Exporter 'import';
use Mojo::File 'tempdir';
use Test::Mojo;

our @EXPORT_OK = qw(new_tracker);

sub new_tracker {
  my $dir = tempdir;
  local $ENV{ISS_TRACKER_DB} = $dir->child('observations.sqlite')->to_string;
  return (Test::Mojo->new('ISSTracker'), $dir);
}

1;
