package ISSTracker::Providers;
use Mojo::Base -base;
use Mojo::UserAgent;

has ua => sub {
  return Mojo::UserAgent->new(connect_timeout => 5, inactivity_timeout => 8, request_timeout => 12);
};

1;
