package t::Conversation;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw(
   %S2C
   %C2S

   $MSG_OK
);

our %S2C;
our %C2S;

our $MSG_OK = "\x80" . "\0\0\0\0";

# This module contains the string values used in various testing scripts that
# act as an example conversation between server and client. The strings are
# kept here in order to avoid mass duplication between the other testing
# modules, and to try to shield unwary visitors from the mass horror that is
# the following collection of large hex-encoded strings.

# If you are sitting comfortably, our story begings with the client...

# MSG_INIT
$C2S{INIT} =
   "\x7f" . "\0\0\0\6" .
   "\x02" . "\0" .
   "\x02" . "\3" .
   "\x02" . "\1";

# MSG_INITED
$S2C{INITED} =
   "\xff" . "\0\0\0\4" .
   "\x02" . "\0" .
   "\x02" . "\3";

# MSG_GETROOT
$C2S{GETROOT} = 
   "\x40" . "\0\0\0\x0b" .
   "\x2a" . "testscript";
$S2C{GETROOT} =
   "\x82" . "\0\0\0\xd0" .
   "\xe2" . "\x29t.TestObj" .
            "\x02\1" .
            "\xa4" . "\x02\1" .
                     "\x61" . "\x26method"  . "\xa2" . "\x02\2" .
                                                       "\x42" . "\x23int" .
                                                                "\x23str" .
                                                       "\x23str" .
                     "\x61" . "\x25event" . "\xa1" . "\x02\3" .
                                                     "\x42" . "\x23int" .
                                                              "\x23str" .
                     "\x67" . "\x25array" . "\xa3" . "\x02\4" .
                                                     "\x02\4" .
                                                     "\x23int" .
                                                     "\x00" .
                              "\x24hash" . "\xa3" . "\x02\4" .
                                                    "\x02\2" .
                                                    "\x23int" .
                                                    "\x00" .
                              "\x25items" . "\xa3" . "\x02\4" .
                                                     "\x02\1" .
                                                     "\x29list(obj)" .
                                                     "\x00" .
                              "\x26objset" . "\xa3" . "\x02\4" .
                                                      "\x02\5" .
                                                      "\x23obj" .
                                                      "\x00" .
                              "\x25queue" . "\xa3" . "\x02\4" .
                                                     "\x02\3" .
                                                     "\x23int" .
                                                     "\x00" .
                              "\x28s_scalar" . "\xa3" . "\x02\4" .
                                                        "\x02\1" .
                                                        "\x23int" .
                                                        "\x01" .
                              "\x26scalar" . "\xa3" . "\x02\4" .
                                                      "\x02\1" .
                                                      "\x23int" .
                                                      "\x00" .
                     "\x40" .
            "\x41" . "\x28s_scalar" .
   "\xe1" . "\x02\1" .
            "\x02\1" .
            "\x41" . "\x23456" . # TODO: should be \x04..
   "\x84" . "\0\0\0\1";

# MSG_GETREGISTRY
$C2S{GETREGISTRY} =
   "\x41" . "\0\0\0\0";
$S2C{GETREGISTRY} =
   "\x82" . "\0\0\0\x84" .
   "\xe2" . "\x31Tangence.Registry" .
            "\x02\2" .
            "\xa4" . "\x02\1" .
                     "\x61" . "\x29get_by_id" . "\xa2" . "\x02\2" . 
                                                         "\x41" . "\x23" . "int" .
                                                         "\x23" . "obj" .
                     "\x62" . "\x32object_constructed" . "\xa1" . "\x02\3" .
                                                         "\x41" . "\x23" . "int" .
                              "\x30object_destroyed"   . "\xa1" . "\x02\3" .
                                                         "\x41" . "\x23" . "int" .
                     "\x61" . "\x27objects" . "\xa3" . "\x02\4" .
                                                       "\x02\2" .
                                                       "\x23" . "str" .
                                                       "\x00" .
                     "\x40" .
            "\x40" .
   "\xe1" . "\x02\0" .
            "\x02\2" .
            "\x40" .
   "\x84" . "\0\0\0\0";

# MSG_CALL
$C2S{CALL} =
   "\1" . "\0\0\0\x11" .
   "\x02\x01" .
   "\x26method" .
   "\x02\x0a" .
   "\x25hello";
# MSG_RESULT
$S2C{CALL} =
   "\x82" . "\0\0\0\x09" .
   "\x2810/hello";
