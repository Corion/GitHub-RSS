#!perl
use strict;
use warnings;
use Data::Dumper;
use feature 'signatures';
no warnings 'experimental::signatures';
use Getopt::Long;
#use Text::CleanFragment 'clean_fragment';
use GitHub::RSS;
use XML::Feed;
use DateTime;
use DateTime::Format::ISO8601;
use Text::Markdown;

GetOptions(
    'filter=s' => \my $issue_regex,
    'issue=s' => \my $github_issue,
    'user=s' => \my $github_user,
    'repo=s' => \my $github_repo,
    'dbfile=s' => \my $store,
    'output-file=s' => \my $output_file,
);

$store //= 'db/issues.sqlite';

my $gh = GitHub::RSS->new(
    dbh => {
        dsn => "dbi:SQLite:dbname=$store",
    },
);

my $feed = XML::Feed->new('RSS');
$feed->title("Github comments for $github_user/$github_repo");
$feed->link("https://github.com/$github_user/$github_repo");
#$feed->self("https://corion.net/github-rss/Perl-perl5.rss");

my @comments = map {
    my $entry = XML::Feed::Entry->new('RSS');
    $entry->id( $_->{id} );
    $entry->title( "Comment by $_->{user}->{login}" );
    $entry->link( $_->{html_url} );

    # Convert from md to html, url-encode
    #my $body = Text::Markdown->new->markdown( $_->{body} );
    my $body = $_->{body};
    $entry->content( $body );
    $entry->author( $_->{user}->{login} );

    my $modified_or_created = DateTime::Format::ISO8601->parse_datetime(
        $_->{modified_at} || $_->{created_at}
    );
    $entry->modified( $modified_or_created );

    $feed->add_entry( $entry );
} $gh->comments(
    #Perl => 'perl5'
    );

open my $fh, '>', $output_file
    or die "Couldn't create '$output_file': $!";
print {$fh} $feed->as_xml;
