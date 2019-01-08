#!/usr/bin/env perl
package SlashBar;
use strict;
use File::AddInc;
use MOP4Import::Base::CLI_JSON -as_base;

MY->run(\@ARGV) unless caller;

1;
