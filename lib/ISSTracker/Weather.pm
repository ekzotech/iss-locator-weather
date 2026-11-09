package ISSTracker::Weather;
use strict;
use warnings;
use utf8;
use Exporter 'import';

our @EXPORT_OK = qw(weather_label);

my %label = (
  0 => 'Ясно',
  1 => 'Преимущественно ясно',
  2 => 'Переменная облачность',
  3 => 'Пасмурно',
  45 => 'Туман',
  48 => 'Туман с отложением инея',
);

sub weather_label {
  my $code = shift;
  return defined($code) ? $label{$code} : undef;
}

1;
