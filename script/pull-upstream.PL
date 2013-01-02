#!/usr/bin/env perl

use lib 'lib';
use LWP::Simple 'getstore';
use Module::Quote;

my $src  = 'https://raw.github.com/miyagawa/cpanminus/master/lib/App/cpanminus/script.pm';
my $dest = './lib/App/cpanminus/script.pm';

getstore $src => $dest;

my $minus = qm(App::cpanminus::script)->VERSION;
my $times = qm(App::cpantimes::script)->VERSION;

if ($minus gt $times)
{
	my $new = $minus . '00';
	system("perl-reversion ./lib/App/cpantimes* --set $new");
}
