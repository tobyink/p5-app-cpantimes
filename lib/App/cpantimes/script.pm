package App::cpantimes::script;

our $VERSION = "1.501900";

use 5.008;
use strict;
use base 'App::cpanminus::script';

my $HOME =
	defined $ENV{HOME}     ? $ENV{HOME} :
	defined $ENV{APPDATA}  ? $ENV{APPDATA} :
	die("Could not determine home directory!");

sub new
{
	my ($class, @args) = @_;
	my $self = $class->SUPER::new(@args);
	
	$self->{_metabase_api}  = 'https://metabase.cpantesters.org/api/v1/';
	$self->{_metabase_file} = "File::Spec"->catfile(
		$HOME,
		qw< .cpantesters metabase_id.json >,
	);

	eval {
		require Test::Reporter;
		require Test::Reporter::Transport::Metabase;
		-r $self->{_metabase_file};
	} or warn <<"WARNING";

*** WARNING ***
You are using cpantimes, a modified version of cpanminus with CPAN
testers support, but it is not correctly configured. Please ensure
Test::Reporter and Test::Reporter::Transport::Metabase are installed,
and use the `metabase-profile` tool to create Metabase login details
as "$self->{_metabase_file}".

Installation will now continue as normal, but test reports will NOT
be sent!

WARNING

	return $self;
}

# Need to clear _current_dist before each installation, to ensure reports
# don't get sent based on incorrect info.
sub install_module
{
	my ($self, @args) = @_;
	delete $self->{_current_dist};
	$self->SUPER::install_module(@args);
}

sub resolve_name
{
	my ($self, @args) = @_;
	my $dist = $self->SUPER::resolve_name(@args);
	$self->{_current_dist} = $dist;
	return $dist;
}

sub cpants_report
{	
	my ($self, $grade, $distname) = @_;
	eval {
		require Test::Reporter;
		require Test::Reporter::Transport::Metabase;
		-r $self->{_metabase_file} and exists $self->{_current_dist}{filename};
	} or return;
	
	my $report = <<"REPORT";
$distname ... @{[ uc $grade ]}

Perl           : $^V
System         : $^O
Local Versions :
REPORT

	for my $mod (keys %{ $self->{local_versions} }) {
		$report .= sprintf("    %-32s : %s\n", $mod, $self->{local_versions}{$mod});
	}
	$report .= "\n";
	
	$report .= "Test Output    :\n\n";
	$report .= do {
		open my $log, '<', $self->{log};
		local $/ = <$log>;
	};
	$report .= "\n";

	my $Report = "Test::Reporter"->new(
		transport      => 'Metabase',
		transport_args => [
			uri     => $self->{_metabase_api},
			id_file => $self->{_metabase_file},
		],
		distribution   => $distname,
		distfile       => sprintf(
			'%s/%s',
			$self->{_current_dist}{cpanid},
			$self->{_current_dist}{filename},
		),
		grade          => $grade,
		from           => 'null@invalid.invalid',
		comments       => $report,
	);

	$Report->send;
	warn $Report->errstr if $Report->errstr;
}

sub test
{
	my($self, $cmd, $distname) = @_;
	return 1 if $self->{notest};

	my $oldlog  = $self->{log};
	my $logfile = "File::Spec"->catfile($self->{home}, "test.log");
	1 while unlink $logfile;

	local $ENV{PERL_MM_USE_DEFAULT} = 1;
	local $self->{log} = $logfile;

	my $return;
	if ( $self->run_timeout($cmd, $self->{test_timeout}) )
	{
		$self->cpants_report(pass => $distname);
		$return = 1;
	}
	else
	{
		$self->cpants_report(fail => $distname);
	}
		
	open my $FULL, '>>', $oldlog;
	open my $TEST, '<',  $self->{log};
	while (<$TEST>) { print {$FULL} $_ };
	$self->{log} = $oldlog;
	return $return if defined $return;
	
	if ($self->{force})
	{
		$self->diag_fail("Testing $distname failed but installing it anyway.");
		return 1;
	}	
	else
	{
		$self->diag_fail;
		while (1)
		{
			my $ans = lc $self->prompt("Testing $distname failed.\nYou can s)kip, r)etry, f)orce install, e)xamine build log, or l)ook ?", "s");
			return                              if $ans eq 's';
			return $self->test($cmd, $distname) if $ans eq 'r';
			return 1                            if $ans eq 'f';
			$self->show_build_log               if $ans eq 'e';
			$self->look                         if $ans eq 'l';
		}
	}
}

sub show_help {
    my $self = shift;

    if ($_[0]) {
        die <<USAGE;
Usage: cpant [options] Module [...]

Try `cpant --help` or `man cpant` for more options.
USAGE
    }

    print <<HELP;
Usage: cpant [options] Module [...]

Options:
  -v,--verbose              Turns on chatty output
  -q,--quiet                Turns off the most output
  --interactive             Turns on interactive configure (required for Task:: modules)
  -f,--force                force install
  -n,--notest               Do not run unit tests
  --test-only               Run tests only, do not install
  -S,--sudo                 sudo to run install commands
  --installdeps             Only install dependencies
  --showdeps                Only display direct dependencies
  --reinstall               Reinstall the distribution even if you already have the latest version installed
  --mirror                  Specify the base URL for the mirror (e.g. http://cpan.cpantesters.org/)
  --mirror-only             Use the mirror's index file instead of the CPAN Meta DB
  --prompt                  Prompt when configure/build/test fails
  -l,--local-lib            Specify the install base to install modules
  -L,--local-lib-contained  Specify the install base to install all non-core modules
  --auto-cleanup            Number of days that cpant's work directories expire in. Defaults to 7

Commands:
  --self-upgrade            upgrades itself
  --info                    Displays distribution info on CPAN
  --look                    Opens the distribution with your SHELL
  -V,--version              Displays software version

Examples:

  cpant Test::More                                          # install Test::More
  cpant MIYAGAWA/Plack-0.99_05.tar.gz                       # full distribution path
  cpant http://example.org/LDS/CGI.pm-3.20.tar.gz           # install from URL
  cpant ~/dists/MyCompany-Enterprise-1.00.tar.gz            # install from a local file
  cpant --interactive Task::Kensho                          # Configure interactively
  cpant .                                                   # install from local directory
  cpant --installdeps .                                     # install all the deps for the current directory
  cpant -L extlib Plack                                     # install Plack and all non-core deps into extlib
  cpant --mirror http://cpan.cpantesters.org/ DBI           # use the fast-syncing mirror

You can also specify the default options in PERL_CPANM_OPT environment variable in the shell rc:

  export PERL_CPANM_OPT="--prompt --reinstall -l ~/perl --mirror http://cpan.cpantesters.org"

Type `man cpant` or `perldoc cpant` for the more detailed explanation of the options.

HELP

    return 1;
}


1;
