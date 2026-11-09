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

done_testing;
