#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2010-2011 -- leonerd@leonerd.org.uk

package Net::Async::Tangence::Client;

use strict;
use warnings;

use base qw( Net::Async::Tangence::Protocol Tangence::Client );

our $VERSION = '0.07';

use Carp;

use URI::Split qw( uri_split );

=head1 NAME

C<Net::Async::Tangence::Client> - connect to a C<Tangence> server using
C<IO::Async>

=head1 DESCRIPTION

This subclass of L<Net::Async::Tangence::Protocol> connects to a L<Tangence>
server, allowing the client program to access exposed objects in the server.
It is a concrete implementation of the C<Tangence::Client> mixin.

The following documentation concerns this specific implementation of the
client; for more general information on the C<Tangence>-specific parts of this
class, see instead the documentation for L<Tangence::Client>.

=cut

sub new
{
   my $class = shift;
   my %args = @_;

   my $self = $class->SUPER::new( %args );

   # It's possible a handle was passed in the constructor.
   $self->tangence_connected( %args ) if defined $self->transport;

   return $self;
}

=head1 PARAMETERS

The following named parameters may be passed to C<new> or C<configure>:

=over 8

=item identity => STRING

The identity string to send to the server.

=item on_error => STRING or CODE

Default error-handling policy for method calls. If set to either of the
strings C<carp> or C<croak> then a CODE ref will be created that invokes the
given function from C<Carp>; otherwise must be a CODE ref.

=back

=cut

sub _init
{
   my $self = shift;
   my ( $params ) = @_;

   $self->identity( delete $params->{identity} );

   $self->SUPER::_init( $params );

   $params->{on_error} ||= "croak";
}

sub configure
{
   my $self = shift;
   my %params = @_;

   if( my $on_error = delete $params{on_error} ) {
      if( ref $on_error eq "CODE" ) {
         # OK
      }
      elsif( $on_error eq "croak" ) {
         $on_error = sub { croak "Received MSG_ERROR: $_[0]" };
      }
      elsif( $on_error eq "carp" ) {
         $on_error = sub { carp "Received MSG_ERROR: $_[0]" };
      }
      else {
         croak "Expected 'on_error' to be CODE reference or strings 'croak' or 'carp'";
      }

      $self->on_error( $on_error );
   }

   $self->SUPER::configure( %params );
}

=head1 METHODS

=cut

=head2 $client->connect_url( $url, %args )

Connects to a C<Tangence> server at the given URL.

Takes the following named arguments:

=over 8

=item on_connected => CODE

Invoked once the connection to the server has been established.

 $on_connected->( $client )

=item on_registry => CODE

=item on_root => CODE

Invoked once the registry and root object proxies have been obtained from the
server. See the documentation the L<Tangence::Client> C<tangence_connected>
method.

=back

The following URL schemes are recognised:

=over 4

=cut

sub connect_url
{
   my $self = shift;
   my ( $url, %args ) = @_;

   my ( $scheme, $authority, $path, $query, $fragment ) = uri_split( $url );

   defined $scheme or croak "Invalid URL '$url'";

   if( $scheme =~ m/\+/ ) {
      $scheme =~ s/^circle\+// or croak "Found a + within URL scheme that is not 'circle+'";
   }

   if( $scheme eq "exec" ) {
      # Path will start with a leading /; we need to trim that
      $path =~ s{^/}{};
      # $query will contain args to exec - split them on +
      my @argv = split( m/\+/, $query );
      return $self->connect_exec( [ $path, @argv ], %args );
   }
   elsif( $scheme eq "ssh" ) {
      # Path will start with a leading /; we need to trim that
      $path =~ s{^/}{};
      # $query will contain args to exec - split them on +
      my @argv = split( m/\+/, $query );
      return $self->connect_ssh( $authority, [ $path, @argv ], %args );
   }
   elsif( $scheme eq "tcp" ) {
      return $self->connect_tcp( $authority, %args );
   }
   elsif( $scheme eq "unix" ) {
      return $self->connect_unix( $path, %args );
   }

   croak "Unrecognised URL scheme name '$scheme'";
}

=item * exec

Directly executes the server as a child process. This is largely provided for
testing purposes, as the server will only run for this one client; it will
exit when the client disconnects.

 exec:///path/to/command?with+arguments

The URL's path should point to the required command, and the query string will
be split on C<+> signs and used as the arguments. The authority section of the
URL will be ignored, so may be left empty.

=cut

sub connect_exec
{
   my $self = shift;
   my ( $command, %args ) = @_;

   my $loop = $self->get_loop;

   pipe( my $myread, my $childwrite ) or croak "Cannot pipe - $!";
   pipe( my $childread, my $mywrite ) or croak "Cannoe pipe - $!";

   $loop->spawn_child(
      command => $command,

      setup => [
         stdin  => $childread,
         stdout => $childwrite,
      ],

      on_exit => sub {
         print STDERR "Child exited unexpectedly\n";
      },
   );

   $self->configure(
      transport => IO::Async::Stream->new(
         read_handle  => $myread,
         write_handle => $mywrite,
      )
   );

   $args{on_connected}->( $self ) if $args{on_connected};
   $self->tangence_connected( %args );
}

=item * ssh

A convenient wrapper around the C<exec> scheme, to connect to a server running
remotely via F<ssh>.

 ssh://host/path/to/command?with+arguments

The URL's authority section will give the SSH server (and optionally
username), and the path and query sections will be used as for C<exec>.

=cut

sub connect_ssh
{
   my $self = shift;
   my ( $host, $argv, %args ) = @_;

   $self->connect_exec( [ "ssh", $host, @$argv ], %args );
}

=item * tcp

Connects to a server via a TCP socket.

 tcp://host:port/

The URL's authority section will be used to give the server's hostname and
port number. The other sections of the URL will be ignored.

=cut

sub connect_tcp
{
   my $self = shift;
   my ( $authority, %args ) = @_;

   my ( $host, $port ) = $authority =~ m/^(.*):(.*)$/;

   $self->connect(
      host     => $host,
      service  => $port,

      on_connected => sub {
         my ( $self ) = @_;

         $args{on_connected}->( $self ) if $args{on_connected};
         $self->tangence_connected( %args );
      },

      on_connect_error => sub { print STDERR "Cannot connect\n"; },
      on_resolve_error => sub { print STDERR "Cannot resolve - $_[0]\n"; },
   );
}

=item * unix

Connects to a server via a UNIX local socket.

 unix:///path/to/socket

The URL's path section will give the path to the local socket. The other
sections of the URL will be ignored.

=cut

sub connect_unix
{
   my $self = shift;
   my ( $path, %args ) = @_;

   require Socket;

   $self->connect(
      addr => [ Socket::AF_UNIX(), Socket::SOCK_STREAM(), 0, Socket::pack_sockaddr_un( $path ) ],

      on_connected => sub {
         my ( $self ) = @_;

         $args{on_connected}->( $self ) if $args{on_connected};
         $self->tangence_connected( %args );
      },

      on_connect_error => sub { print STDERR "Cannot connect\n"; },
   );
}

=back

=cut

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
