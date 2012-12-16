#!/usr/bin/env perl

open my $in,  "<", "script/cpant.PL" or die $!;
open my $out, ">", "cpant.tmp" or die $!;

print STDERR "Generating cpant from script/cpant.PL\n";

while (<$in>) {
    next if /Auto-removed/;
    s/DEVELOPERS:.*/DO NOT EDIT -- this is an auto generated file/;
    s/.*__FATPACK__/zomg_hfs(scalar `$^X -e "use App::FatPacker -run_script" file`)/e;
    print $out $_;
}

close $out;

unlink "cpant";
rename "cpant.tmp", "cpant";
chmod 0755, "cpant";

END { unlink "cpant.tmp" }

# HFS is case sensitive, we have fatlib/version that contains Version/Requirements.pm :(
sub zomg_hfs {
    local $_ = shift;
    s!version/Requirements.pm!Version/Requirements.pm!;
    return $_;
}
