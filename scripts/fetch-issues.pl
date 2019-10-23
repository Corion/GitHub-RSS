#!perl
use strict;
use warnings;
use Data::Dumper;
use feature 'signatures';
no warnings 'experimental::signatures';
use Getopt::Long;
use Text::CleanFragment 'clean_fragment';
use GitHub::RSS;

GetOptions(
    'n|dry-run' => \my $dry_run,
    'token=s' => \my $token,
    'token-file=s' => \my $token_file,
    'filter=s' => \my $issue_regex,
    'git=s' => \my $git,
    'issue=s' => \my $github_issue,
    'user=s' => \my $github_user,
    'test' => \my $run_tests,
);

my $store = 'db/issues.sqlite';

my $gh = GitHub::RSS->new(
    dbh => {
        dsn => 'dbi:SQLite:dbname=db/issues.sqlite',
    },
);

$gh->fetch_and_store( Perl => 'perl5' );
