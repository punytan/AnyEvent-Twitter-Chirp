# t/00_compile.t

use strict;
use Test::More;

plan( tests => 1 );

BEGIN { use_ok 'AnyEvent::Twitter::Chirp' }
