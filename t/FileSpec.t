# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

################################################################################
# FileSpec.t,v 1.2 2006/09/13 12:54:58 sberrick Exp
# -@@@ S4P, Version Release-5_28_5
################################################################################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 7;
use Sys::Hostname;
use strict;
BEGIN { use_ok('S4P::FileSpec') };

my $file_spec = new S4P::FileSpec;
$file_spec->pathname('/var/tmp/foo.bar');
is($file_spec->file_id, 'foo.bar');
is($file_spec->directory_id, '/var/tmp');
is($file_spec->pathname, '/var/tmp/foo.bar');

$file_spec = new S4P::FileSpec('file_type' => 'METADATA', 
    'pathname' => '/usr/tmp/hello.world');
is($file_spec->file_id, 'hello.world');
is($file_spec->directory_id, '/usr/tmp');
is($file_spec->pathname, '/usr/tmp/hello.world');

