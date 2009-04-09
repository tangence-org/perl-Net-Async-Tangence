#!/usr/bin/perl -w

use strict;

use Test::More tests => 17;
use Test::Exception;
use IO::Async::Test;
use IO::Async::Loop;

use Tangence::Constants;
use Tangence::Registry;
use Tangence::Server;
use Tangence::Connection;
use t::Ball;

my $loop = IO::Async::Loop->new();
testing_loop( $loop );

my $registry = Tangence::Registry->new();
my $ball = $registry->construct(
   "t::Ball",
   colour => "red",
   size   => 100,
);

my $server = Tangence::Server->new(
   loop     => $loop,
   registry => $registry,
);

my ( $S1, $S2 ) = $loop->socketpair() or die "Cannot create socket pair - $!";

$server->new_be( handle => $S1 );

my $conn = Tangence::Connection->new( handle => $S2 );
$loop->add( $conn );

wait_for { defined $conn->get_root };

my $ballproxy = $conn->get_root;

my $result;

$ballproxy->call_method(
   method => "bounce",
   args   => [ "20 metres" ],
   on_result => sub { $result = shift },
);

wait_for { defined $result };

is( $result, "bouncing", 'result of call_method()' );

dies_ok( sub { $ballproxy->call_method(
                 method => "no_such_method",
                 args   => [ 123 ],
                 on_result => sub {},
               ); },
         'Calling no_such_method fails in proxy' );

my $howhigh;
my $subbed;
$ballproxy->subscribe_event(
   event => "bounced",
   on_fire => sub {
      ( $howhigh ) = @_;
   },
   on_subscribed => sub { $subbed = 1 },
);

wait_for { $subbed };

$ball->method_bounce( {}, "10 metres" );

wait_for { defined $howhigh };

is( $howhigh, "10 metres", '$howhigh is 10 metres after subscribed event' );

dies_ok( sub { $ballproxy->subscribe_event(
                 event => "no_such_event",
                 on_fire => sub {},
               ); },
         'Subscribing to no_such_event fails in proxy' );

is( $ballproxy->prop( "size" ), 100, 'Smashed property initially set in proxy' );

my $colour;

$ballproxy->get_property(
   property => "colour",
   on_value => sub { $colour = shift },
);

wait_for { defined $colour };

is( $colour, "red", '$colour is red' );

my $didset = 0;
$ballproxy->set_property(
   property => "colour",
   value    => "blue",
   on_done  => sub { $didset = 1 },
);

wait_for { $didset };

is( $ball->get_prop_colour, "blue", '$ball->colour is now blue' );

my $watched;
$ballproxy->watch_property(
   property => "colour",
   on_change => sub { 
      my ( $how, @value ) = @_;
      $colour = $value[0];
   },
   on_watched => sub { $watched = 1 },
);

wait_for { $watched };

$ball->set_prop_colour( "green" );

undef $colour;
wait_for { defined $colour };

is( $colour, "green", '$colour is green after MSG_UPDATE' );

my $colourchanged = 0;
my $secondcolour;
$ballproxy->watch_property(
   property => "colour",
   on_change => sub {
      ( undef, $secondcolour ) = @_;
      $colourchanged = 1
   },
   want_initial => 1,
);

wait_for { $colourchanged };

is( $secondcolour, "green", '$secondcolour is green after second watch' );

$ball->set_prop_colour( "orange" );

$colourchanged = 0;
wait_for { $colourchanged };

is( $colour, "orange", '$colour is orange after second MSG_UPDATE' );
is( $colourchanged, 1, '$colourchanged is true after second MSG_UPDATE' );

dies_ok( sub { $ballproxy->get_property(
                 property => "no_such_property",
                 on_value => sub {},
               ); },
         'Getting no_such_property fails in proxy' );

# Test the smashed properties

my $size;
$watched = 0;
$ballproxy->watch_property(
   property => "size",
   on_change => sub {
      my ( $how, @value ) = @_;
      $size = $value[0];
   },
   on_watched => sub { $watched = 1 },
   want_initial => 1,
);

is( $watched, 1, 'watch_property on smashed prop is synchronous' );

is( $size, 100, 'watch_property on smashed prop gives initial value' );

$ball->set_prop_size( 200 );

undef $size;
wait_for { defined $size };

is( $size, 200, 'smashed prop watch succeeds' );

# Test object destruction

my $proxy_destroyed = 0;

$ballproxy->subscribe_event(
   event => "destroy",
   on_fire => sub { $proxy_destroyed = 1 },
);

my $obj_destroyed = 0;

$ball->destroy( on_destroyed => sub { $obj_destroyed = 1 } );

wait_for { $proxy_destroyed };
is( $proxy_destroyed, 1, 'proxy gets destroyed' );

wait_for { $obj_destroyed };
is( $obj_destroyed, 1, 'object gets destroyed' );
