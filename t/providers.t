use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use ISSTracker::Providers;
use Test::More;

my $providers = ISSTracker::Providers->new;
my $ua = $providers->ua;
is $ua->connect_timeout, 5, 'connect timeout is bounded';
is $ua->inactivity_timeout, 8, 'inactivity timeout is bounded';
is $ua->request_timeout, 12, 'total request timeout is bounded';

done_testing;
