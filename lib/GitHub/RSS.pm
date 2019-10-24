package GitHub::RSS;
use strict;
use 5.010;
use Moo 2;
use feature 'signatures';
no warnings 'experimental::signatures';
use PerlX::Maybe;

use IO::Socket::SSL;
use Net::GitHub;
use DBI;
use JSON;

use Data::Dumper;

our $VERSION = '0.01';

=head1 NAME

GitHub::RSS - collect data from Github.com for feeding into RSS

=cut

has 'gh' => (
    is => 'ro',
    default => sub( $self ) {
        Net::GitHub->new(
            maybe access_token => $self->token
        ),
    },
);

has 'token_file' => (
    is => 'lazy',
    default => \&_find_gh_token_file,
);

has 'token' => (
    is => 'lazy',
    default => \&_read_gh_token,
);

has default_user => (
    is => 'ro',
);

has default_repo => (
    is => 'ro',
);

has dbh => (
    is       => 'ro',
    required => 1,
    coerce   => \&_build_dbh,
);

sub _build_dbh( $args ) {
    return $args if ref($args) eq 'DBI::db';
    ref($args) eq 'HASH' or die 'Not a DB handle nor a hashref';
    return DBI->connect( @{$args}{qw/dsn db_user db_password db_options/} );
}

sub _find_gh_token_file( $self, $env=undef ) {
    $env //= \%ENV;

    my $token_file;

    # This should use File::User
    for my $candidate_dir ('.',
                           $ENV{XDG_DATA_HOME},
                           $ENV{USERPROFILE},
                           $ENV{HOME}
    ) {
        next unless defined $candidate_dir;
        if( -f "$candidate_dir/github.credentials" ) {
            $token_file = "$candidate_dir/github.credentials";
            last
        };
    };

    return $token_file
}

sub _read_gh_token( $self, $token_file=undef ) {
    my $file = $token_file // $self->token_file;

    if( $file ) {
        open my $fh, '<', $file
            or die "Couldn't open file '$file': $!";
        binmode $fh;
        local $/;
        my $json = <$fh>;
        my $token_json = decode_json( $json );
        return $token_json->{token};
    } else {
        # We'll run without a known account
        return
    }
}

sub fetch_all_issues( $self,
    $user = $self->default_user,
    $repo = $self->default_repo,
    $since=undef ) {
    my @issues = $self->fetch_issues( $user, $repo, $since );
    my $gh = $self->gh;
    while ($gh->issue->has_next_page) {
        push @issues, $gh->issue->next_page;
    }
    @issues
}

sub fetch_issues( $self,
    $user = $self->default_user,
    $repo = $self->default_repo,
    $since=undef ) {
    my $gh = $self->gh;
    my @issues = $gh->issue->repos_issues($user => $repo,
                                          { sort => 'updated',
                                          direction => 'asc', # so we can interrupt any time
                                          maybe since => $since,
                                          }
                                         );
};

sub fetch_issue_comments( $self, $issue_number,
        $user=$self->default_user,
        $repo=$self->default_repo
    ) {
    # Shouldn't this loop as well, just like with the issues?!
    return $self->gh->issue->comments($user, $repo, $issue_number );
}

sub write_data( $self, $table, @rows) {
    my @columns = sort keys %{ $rows[0] };
    my $statement = sprintf q{replace into "%s" (%s) values (%s)},
                        $table,
                        join( ",", map qq{"$_"}, @columns ),
                        join( ",", ('?') x (0+@columns))
                        ;
    my $sth = $self->dbh->prepare( $statement );
    eval {
        $sth->execute_for_fetch(sub { @rows ? [ @{ shift @rows }{@columns} ] : () }, \my @errors);
    } or die Dumper \@rows;
    #if( @errors ) {
    #    warn Dumper \@errors if (0+@errors);
    #};
}

sub store_issues_comments( $self, $user, $repo, $issues ) {
    # Munge some columns:
    for (@$issues) {
        my $u = delete $_->{user};
        @{ $_ }{qw( user_id user_login user_gravatar_id )}
            = @{ $u }{qw( id login gravatar_id )};

        # Squish all structure into JSON, for later
        for (values %$_) {
            if( ref($_) ) { $_ = encode_json($_) };
        };
    };

    for my $issue (@$issues) {
        #$|=1;
        #print sprintf "% 6d %s\r", $issue->{number}, $issue->{updated_at};
        my @comments = $self->fetch_issue_comments( $issue->{number}, $user => $repo );

        # Squish all structure into JSON, for later
        for (@comments) {
            for (values %$_) {
                if( ref($_) ) { $_ = encode_json($_) };
            };
        };
        $self->write_data( 'comment' => @comments )
            if @comments;
    };

    # We wrote the comments first so we will refetch them if there is a problem
    # when writing the issue
    $self->write_data( 'issue' => @$issues );
};

sub fetch_and_store( $self,
                     $user  = $self->default_user,
                     $repo  = $self->default_repo,
                     $since = undef) {
    my $dbh = $self->dbh;
    my $gh = $self->gh;

    # Throw old data away instead of keeping it for diffs
    # We should do this per-user, per-repository, or do REPLACE instead
    #$dbh->do("delete from $_") for (qw(issue comment));

    my @issues = $self->fetch_issues( $user => $repo, $since );
    my $has_more = $gh->issue->has_next_page;
    $self->store_issues_comments( $user => $repo, \@issues );

# Meh - we lose the information here since we fetch the comments immediately.
# Oh well ...
    while ($has_more) {
        @issues = $gh->issue->next_page;
        $has_more = $gh->issue->has_next_page;

        $self->store_issues_comments( $user => $repo, \@issues );
    }
}

sub comments( $self, $since ) {
    map {
        $_->{user} = decode_json( $_->{user} );
        $_
    }
    @{ $self->dbh->selectall_arrayref(<<'SQL', { Slice => {}}, $since) }
        select
               c.* -- this should become an exact list, later
          from comment c
          join issue i on c.issue_url=i.url
         where i.updated_at >= ?
      order by html_url
SQL
}

sub last_check( $self,
                $user = $self->default_user,
                $repo = $self->default_repo ) {
    my $last = $self->dbh->selectall_arrayref(<<'SQL', { Slice => {} });
        select
            max(updated_at) as updated_at
          from issue
SQL
    if( @$last ) {
        return $last->[0]->{updated_at}
    } else {
        return undef # empty DB
    }
}

1;
