#!/usr/bin/env perl

=head1 NAME

bootstrap-locallib.pl, version 0.03

=head1 SYNOPSIS

  perl [PATH]/bootstrap-locallib.pl OPTIONS

  Option Summary

    "t|target=s" => \$target,
    "b|basedir=s" => \$basedir,
    "a|affix=s" => \$affix,
    "w|whichperl=s" => \$whichperl,
    "d|local_env_helper=s" => \$env_helper,
    'h|help'       => \$help

=head1 DESCRIPTION

Script to make it easier to install and used the excellent local::lib perl
module.  For more information about local::lib please see:

    http://search.cpan.org/dist/local-lib

This tool is designed to make it easier to install and manage multiple
local::lib setups.  However, the tool itself is relatively easy to setup, you
may wish to read and follow the instructions linked about.

This script performs two services: 1) provides a single commandline script which
can be used to install multiple local::libs, 2) provides a helper script which
you can use to initialize an installed local::lib for a given command

=head1 EXAMPLES

ALl examples assume you have the file 'bootstrap-locallib.pl' downloaded into 
a directory in your $PATH, and that it's been set to executable.

Deploy a L<local::lib> to $HOME/local-lib5 for the default interpreter

    bootstrap-locallib.pl

Deploy a L<local::lib> to $HOME/myapp-local-lib5

    bootstrap-locallib.pl affix="myapp-local-lib5"

Deploy a L<local::lib> to /usr/local/lib/myapp-local-lib6

    bootstrap-locallib.pl basedir="/usr/local/lib" affix="myapp-local-lib5"

Deploy a L<local::lib> to ./local

    bootstrap-locallib.pl --target ./local

Invoke helper created in the above example to initialize L<local::lib> for the
current shell.

    ./local/bin/env perl -V


Run straight from the Internet.

    curl -L http://github.com/jjn1056/bootstrap-locallib.pl/blob/master/bootstrap_locallib.pl | perl - --target local

=cut

use strict;
use warnings;

use Cwd;
use CPAN;
use Getopt::Long;
use File::Spec;
use Pod::Usage;

our $VERSION = "0.03";

my $help;
my $basedir = $ENV{LOCALLIB_BASEDIR} || $ENV{HOME};
my $affix = $ENV{LOCALLIB_AFFIX} || 'local-lib5';
my $whichperl = $ENV{LOCALLIB_WHICHPERL} || $^X;
my $env_helper = $ENV{LOCALLIB_LOCAL_ENV_HELPER} || '';
my $target = $ENV{LOCALLIB_TARGET} || '';

my $result = GetOptions(
    "t|target=s" => \$target,
    "b|basedir=s" => \$basedir,
    "a|affix=s" => \$affix,
    "w|whichperl=s" => \$whichperl,
    "d|local_env_helper=s" => \$env_helper,
    'h|help'       => \$help
)or die pod2usage;
pod2usage(0) if $help;

unless($target) {
    $target = Cwd::realpath(File::Spec->catdir($basedir,$affix));
}

$target = Cwd::abs_path($target);
$env_helper = File::Spec->catdir($target, 'bin', 'localenv')
  unless $env_helper;

print "Deploying local::lib to $target\n";
&install_locallib($target, $whichperl);
print "Done!\n";

print "Deploying core developer modules...\n";
&install_core_modules($target,$whichperl);
print "Done!\n";

print "Creating env script...\n";
&install_locallib_env($target, $env_helper, $whichperl);
print "Done!";

sub install_locallib {
    my ($target, $whichperl) = @_;
    my $mod = CPAN::Shell->expand(Module => "local::lib");
    $mod->get;
    my $dir = CPAN::Shell->expand(Distribution => $mod->cpan_file)->dir;
    chdir($dir);
    my $make = $CPAN::Config->{make};
    my $bootstrap = $target ? "--bootstrap=$target" : "--bootstrap";

    ## TODO: Needs better error catching
    system($whichperl, 'Makefile.PL', $bootstrap) && exit 1;
    system($make, 'test') && exit 1;
    system($make, 'install') && exit 1;
}

sub install_core_modules {
    my ($target, $whichperl) = @_;
    my $lib = File::Spec->catdir($target, 'lib', 'perl5');

    $ENV{PERL5LIB} = '';
    $ENV{PERL_MM_USE_DEFAULT} = '1';
    $ENV{PERL_AUTOINSTALL_PREFER_CPAN} = '1';

    ## Install these dists even if they are already installed somewhere
    my @default_libs = (
        'ExtUtils::MakeMaker',
        'ExtUtils::Install',
        'Module::Install',
        'Module::Build',
        'YAML',
        'CPAN',
        'App::Ack',
	'App::cpanminus',
    );

    foreach my $module(@default_libs) {
        my $cmd = qq["$whichperl" -I$lib -Mlocal::lib="$target" -e "use CPAN; CPAN::force('install',$module)"];
        print "doing $cmd;\n";
        system($cmd);
    }
}

sub install_locallib_env {
    my ($target, $env_helper, $whichperl) = @_;
    my $lib = File::Spec->catdir($target, 'lib', 'perl5');
    open(my $fh, '>', $env_helper) or die "Can't open $env_helper";

    print $fh <<"END";
#!$whichperl

use strict;
use warnings;
use lib '$lib';
use local::lib '$target';

unless ( caller ) {
    if ( \@ARGV ) {
        exec \@ARGV;
    }
}

1;
END

    close($fh);

    my $mode = '0755';
    chmod oct($mode), $env_helper;
    return $env_helper;
} 

