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

GetOptions(
    'filter=s' => \my $issue_regex,
    'issue=s' => \my $github_issue,
    'user=s' => \my $github_user,
    'output-file=s' => \my $output_file,
);

my ($user,$repo) = ('Perl' => 'perl5');

my $store = 'db/issues.sqlite';

my $gh = GitHub::RSS->new(
    dbh => {
        dsn => 'dbi:SQLite:dbname=db/issues.sqlite',
    },
);

my $feed = XML::Feed->new('RSS');
$feed->title("Github comments for $user/$repo");
$feed->link("https://github.com/$user/$repo");
#$feed->self("https://corion.net/github-rss/Perl-perl5.rss");

my @comments = map {
    my $entry = XML::Feed::Entry->new('RSS');
    $entry->id( $_->{id} );
    $entry->title( "Comment by $_->{user}" );
    $entry->link( $_->{html_url} );

    # Convert from md to html, url-encode
    $entry->content( $_->{body} );
    $entry->author( $_->{user_login} );

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
