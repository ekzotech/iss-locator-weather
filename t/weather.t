use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../lib";
use ISSTracker::Weather 'weather_label';
use Test::More;

is weather_label(0), 'Ясно', 'clear sky';
is weather_label(2), 'Переменная облачность', 'partly cloudy';
is weather_label(3), 'Пасмурно', 'overcast';
is weather_label(45), 'Туман', 'fog';
is weather_label(48), 'Туман с отложением инея', 'rime fog';
my %precipitation = (
  53 => 'Умеренная морось', 56 => 'Слабая ледяная морось',
  63 => 'Умеренный дождь', 66 => 'Слабый ледяной дождь',
  73 => 'Умеренный снег', 77 => 'Снежные зёрна',
  81 => 'Умеренный ливень', 86 => 'Сильный снежный заряд',
  95 => 'Гроза', 99 => 'Гроза с сильным градом',
);
for my $code (sort {$a <=> $b} keys %precipitation) {
  is weather_label($code), $precipitation{$code}, "precipitation group for WMO $code";
}
is weather_label(98), 'Неизвестные условия', 'unknown WMO code has a fallback';
is weather_label(undef), undef, 'missing weather stays absent';

done_testing;
