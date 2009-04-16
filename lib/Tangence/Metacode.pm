package Tangence::Metacode;

use strict;

use Carp;

use Tangence::Constants;

sub init_class
{
   my $class = shift;

   # This method does lots of evilness. But we'll try to keep it brief, and
   # all in one place
   no strict 'refs';

   foreach my $superclass ( @{$class."::ISA"} ) {
      init_class( $superclass ) unless defined &{"${superclass}::_has_Tangence"};
   }

   my %subs = (
      _has_Tangence => sub() { 1 },
   );

   my %props = %{$class."::PROPS"};

   foreach my $prop ( keys %props ) {
      my $pdef = $props{$prop};

      init_class_property( $class, $prop, $pdef, \%subs );
   }

   foreach my $name ( keys %subs ) {
      next if defined &{"${class}::${name}"};
      *{"${class}::${name}"} = $subs{$name};
   }
}

sub init_class_property
{
   my ( $class, $prop, $pdef, $subs ) = @_;

   $subs->{"get_prop_$prop"} = sub {
      my $self = shift;
      return $self->{properties}->{$prop}->[0]
   };

   $subs->{"set_prop_$prop"} = sub {
      my $self = shift;
      my ( $newval ) = @_;
      $self->{properties}->{$prop}->[0] = $newval;
      my $cbs = $self->{properties}->{$prop}->[1];
      $_->{on_set}->( $newval ) for @$cbs;
   };

   my $dim = $pdef->{dim};

   my $dimname = DIMNAMES->[$dim];
   if( my $code = __PACKAGE__->can( "init_class_property_$dimname" ) ) {
      $code->( $class, $prop, $pdef, $subs );
   }
   else {
      croak "Unrecognised property dimension $dim for $class :: $prop";
   }
}

sub init_class_property_scalar
{
   my ( $class, $prop, $pdef, $subs ) = @_;

   # Nothing needed
}

sub init_class_property_hash
{
   my ( $class, $prop, $pdef, $subs ) = @_;

   $subs->{"add_prop_$prop"} = sub {
      my $self = shift;
      my ( $key, $value ) = @_;
      $self->{properties}->{$prop}->[0]->{$key} = $value;
      my $cbs = $self->{properties}->{$prop}->[1];
      $_->{on_add}->( $key, $value ) for @$cbs;
   };

   $subs->{"del_prop_$prop"} = sub {
      my $self = shift;
      my ( $key ) = @_;
      delete $self->{properties}->{$prop}->[0]->{$key};
      my $cbs = $self->{properties}->{$prop}->[1];
      $_->{on_del}->( $key ) for @$cbs;
   };
}

sub init_class_property_queue
{
   my ( $class, $prop, $pdef, $subs ) = @_;

   $subs->{"push_prop_$prop"} = sub {
      my $self = shift;
      my @values = @_;
      push @{ $self->{properties}->{$prop}->[0] }, @values;
      my $cbs = $self->{properties}->{$prop}->[1];
      $_->{on_push}->( @values ) for @$cbs;
   };

   $subs->{"shift_prop_$prop"} = sub {
      my $self = shift;
      my ( $count ) = @_;
      $count = 1 unless @_;
      splice @{ $self->{properties}->{$prop}->[0] }, 0, $count, ();
      my $cbs = $self->{properties}->{$prop}->[1];
      $_->{on_shift}->( $count ) for @$cbs;
   };
}

sub init_class_property_array
{
   my ( $class, $prop, $pdef, $subs ) = @_;

   $subs->{"push_prop_$prop"} = sub {
      my $self = shift;
      my @values = @_;
      push @{ $self->{properties}->{$prop}->[0] }, @values;
      my $cbs = $self->{properties}->{$prop}->[1];
      $_->{on_push}->( @values ) for @$cbs;
   };

   $subs->{"shift_prop_$prop"} = sub {
      my $self = shift;
      my ( $count ) = @_;
      $count = 1 unless @_;
      splice @{ $self->{properties}->{$prop}->[0] }, 0, $count, ();
      my $cbs = $self->{properties}->{$prop}->[1];
      $_->{on_shift}->( $count ) for @$cbs;
   };

   $subs->{"splice_prop_$prop"} = sub {
      my $self = shift;
      my ( $index, $count, @values ) = @_;
      splice @{ $self->{properties}->{$prop}->[0] }, $index, $count, @values;
      my $cbs = $self->{properties}->{$prop}->[1];
      $_->{on_splice}->( $index, $count, @values ) for @$cbs;
   };
}

sub init_class_property_objset
{
   my ( $class, $prop, $pdef, $subs ) = @_;

   # Different set method
   $subs->{"set_prop_$prop"} = sub {
      my $self = shift;
      my ( $newval ) = @_;
      $self->{properties}->{$prop}->[0] = $newval;
      my $cbs = $self->{properties}->{$prop}->[1];
      $_->{on_set}->( [ values %$newval ] ) for @$cbs;
   };

   $subs->{"add_prop_$prop"} = sub {
      my $self = shift;
      my ( $obj ) = @_;
      $self->{properties}->{$prop}->[0]->{$obj->id} = $obj;
      my $cbs = $self->{properties}->{$prop}->[1];
      $_->{on_add}->( $obj ) for @$cbs;
   };

   $subs->{"del_prop_$prop"} = sub {
      my $self = shift;
      my ( $obj_or_id ) = @_;
      my $id = ref $obj_or_id ? $obj_or_id->id : $obj_or_id;
      delete $self->{properties}->{$prop}->[0]->{$id};
      my $cbs = $self->{properties}->{$prop}->[1];
      $_->{on_del}->( $id ) for @$cbs;
   };
}

1;