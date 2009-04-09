#!/usr/bin/perl -w

use strict;

use Test::More tests => 11;
use IO::Async::Test;
use IO::Async::Loop;

use Tangence::Constants;
use Tangence::Registry;
use Tangence::Server;
use Tangence::Connection;
use t::TestObj;

my $loop = IO::Async::Loop->new();
testing_loop( $loop );

my $registry = Tangence::Registry->new();
my $obj = $registry->construct(
   "t::TestObj",
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

my $proxy = $conn->get_root;

my $result;

my $scalar;
$proxy->watch_property(
   property => "scalar",
   on_set => sub { $scalar = shift },
   on_watched => sub { $result = 1 },
   want_initial => 1,
);

undef $result;
wait_for { defined $result };

wait_for { defined $scalar };

is( $scalar, "123", 'Initial value from watch_property' );

$obj->set_prop_scalar( "1234" );

undef $scalar;
wait_for { defined $scalar };

is( $scalar, "1234", 'set scalar value' );

my $hash;
my ( $a_key, $a_value );
my ( $d_key );
$proxy->watch_property(
   property => "hash",
   on_set => sub { $hash = shift },
   on_add => sub { ( $a_key, $a_value ) = @_ },
   on_del => sub { ( $d_key ) = @_ },
   on_watched => sub { $result = 1 },
   want_initial => 1,
);

undef $result;
wait_for { defined $result };

is_deeply( $hash,
           { one => 1, two => 2, three => 3 },
           'Initial value from watch_property' );

$obj->add_prop_hash( four => 4 );

wait_for { defined $a_key and defined $a_value };

is( $a_key,   'four', 'add hash key' );
is( $a_value, 4,      'add hash value' );

$obj->del_prop_hash( 'one' );

wait_for { defined $d_key };

is( $d_key, 'one', 'del hash key' );

my $array;
my ( @p_values );
my ( $sh_count );
my ( $s_index, $s_count, @s_values );
$proxy->watch_property(
   property => "array",
   on_set => sub { $array = shift },
   on_push => sub { @p_values = @_ },
   on_shift => sub { ( $sh_count ) = @_ },
   on_splice => sub { ( $s_index, $s_count, @s_values ) = @_ },
   on_watched => sub { $result = 1 },
   want_initial => 1,
);

undef $result;
wait_for { defined $result };

$obj->push_prop_array( 6 );

wait_for { @p_values };

is_deeply( \@p_values, [ 6 ], 'push array values' );

$obj->shift_prop_array( 1 );

wait_for { defined $sh_count };

is( $sh_count, 1, 'shift array count' );

$obj->splice_prop_array( 1, 2, ( 7 ) );

wait_for { defined $s_index };

is( $s_index, 1, 'splice array index' );
is( $s_count, 2, 'splice array count' );
is_deeply( \@s_values, [ 7 ], 'splice array values' );
