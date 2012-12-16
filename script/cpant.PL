#!/usr/bin/env perl
#
# __FATPACK__
use strict;
use FindBin qw($Bin);                    # For dev -- Auto-removed
use lib "$Bin/../lib", "$Bin/../fatlib"; # For dev -- Auto-removed
use App::cpantimes::script;

unless (caller) {
	my $app = App::cpantimes::script->new;
	$app->parse_options(@ARGV);
	$app->doit or exit(1);
}

__END__

=head1 NAME

cpant - get, unpack, build, install and report on modules from CPAN

=head1 SEE ALSO

L<App::cpantimes>,
L<cpanm>.
