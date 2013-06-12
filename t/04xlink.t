#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal qw( dies_ok );
use Test::Memory::Cycle;
use IO::Async::Test;
use IO::Async::Loop;
use IO::Async::OS;
use IO::Async::Stream;

use Tangence::Constants;
use Tangence::Registry;

use Net::Async::Tangence::Server;
use Net::Async::Tangence::Client;

use t::TestObj;

my $loop = IO::Async::Loop->new();
testing_loop( $loop );

my $registry = Tangence::Registry->new(
   tanfile => "t/TestObj.tan",
);
my $obj = $registry->construct(
   "t::TestObj",
   scalar   => 123,
   s_scalar => 456,
);

my $server = Net::Async::Tangence::Server->new(
   registry => $registry,
);

$loop->add( $server );

my ( $S1, $S2 ) = IO::Async::OS->socketpair() or die "Cannot create socket pair - $!";

$server->on_stream( IO::Async::Stream->new( handle => $S1 ) );

my $client = Net::Async::Tangence::Client->new( handle => $S2 );
$loop->add( $client );

wait_for { defined $client->rootobj };

my $objproxy = $client->rootobj;

# Methods
{
   my $result;
   $objproxy->call_method(
      method => "method",
      args   => [ 10, "hello" ],
      on_result => sub { $result = shift },
   );

   wait_for { defined $result };

   is( $result, "10/hello", 'result of call_method()' );
}

# That'll do; everything should be tested by Tangence itself

memory_cycle_ok( $obj, '$obj has no memory cycles' );
memory_cycle_ok( $registry, '$registry has no memory cycles' );
memory_cycle_ok( $objproxy, '$objproxy has no memory cycles' );

# Deconfigure the connection otherwise Devel::Cycle will throw
#   Unhandled type: GLOB at /usr/share/perl5/Devel/Cycle.pm line 107.
# on account of filehandles
$client->configure( transport => undef );
memory_cycle_ok( $client, '$client has no memory cycles' );

done_testing;
