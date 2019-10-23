#!perl
use strict;
use warnings;
use 5.010;
use Data::Dumper;
use feature 'signatures';
no warnings 'experimental::signatures';
use Getopt::Long;
use GitHub::RSS;

GetOptions(
    'token=s' => \my $token,
    'token-file=s' => \my $token_file,
    'filter=s' => \my $issue_regex,
    'user=s' => \my $github_user,
    'repo=s' => \my $github_repo,
    'dbfile=s' => \my $store,
);

$store //= 'db/issues.sqlite';

my $gh = GitHub::RSS->new(
    dbh => {
        dsn => "dbi:SQLite:dbname=$store",
    },
);

$gh->fetch_and_store( $github_user => $github_store );
