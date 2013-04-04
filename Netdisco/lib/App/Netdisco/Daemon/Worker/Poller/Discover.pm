package App::Netdisco::Daemon::Worker::Poller::Discover;

use Dancer qw/:moose :syntax :script/;
use Dancer::Plugin::DBIC 'schema';

use App::Netdisco::Util::SNMP 'snmp_connect';
use App::Netdisco::Util::Device 'get_device';
use App::Netdisco::Util::DiscoverAndStore ':all';
use App::Netdisco::Daemon::Worker::Interactive::Util ':all';

use NetAddr::IP::Lite ':lower';

use Role::Tiny;
use namespace::clean;

# queue a discover job for all devices known to Netdisco
sub refresh {
  my ($self, $job) = @_;

  my $devices = schema('netdisco')->resultset('Device')->get_column('ip');

  schema('netdisco')->resultset('Admin')->populate([
    map {{
        device => $_,
        action => 'discover',
        status => 'queued',
    }} ($devices->all)
  ]);

  return done("Queued discover job for all devices");
}

sub discover {
  my ($self, $job) = @_;

  my $host = NetAddr::IP::Lite->new($job->device);
  my $device = get_device($host->addr);
  my $snmp = snmp_connect($device);

  if (!defined $snmp) {
      return error("Discover failed: could not SNMP connect to $host");
  }

  store_device($device, $snmp);
  #store_interfaces($ip, $snmp);
  #store_vlans($ip, $snmp);
  #store_power($ip, $snmp);
  #store_modules($ip, $snmp);

  return done("Ended Discover for $host");
}

1;