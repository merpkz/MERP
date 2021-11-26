package MERP::DB;
use warnings;
use strict;
use feature 'say';

use Exporter qw(import);
our @EXPORT      = qw(db_do db_exec db_prepare db_connect);
our @EXPORT_OK   = qw();

use DBIx::Connector;
use Getopt::Long qw(:config pass_through);

my $conn;

my $default_auth = {
	db_type => 'SQLite',
	db_name => ':memory:',
	db_user => '',
	db_pass => '',
	db_host => '127.0.0.1',
	db_port => 5432
};

my %opts;
# get options but don't necessary die:
GetOptions(
	"db_type=s" => \$opts{db_type},
	"db_name=s" => \$opts{db_name},
	"db_user=s" => \$opts{db_user},
	"db_pass=s" => \$opts{db_pass},
	"db_host=s" => \$opts{db_host},
	"db_port=s" => \$opts{db_port},

	"db_autocommit" => \$opts{auto_commit},
	"db_raiseerror" => \$opts{raiseerror}
);

sub db_connect {
	my $auth = shift || {};
	# merge auth keys with default values:
	if ( ref $auth eq 'HASH' ) {
		for ( keys %{ $default_auth } ) {
			# pick up some default value from either opts or ENV:
			$$auth{ $_ } //= $opts{ $_ } // $ENV{ uc $_ } // $$default_auth{ $_ };
		}
	}

	$conn = DBIx::Connector->new(
		sprintf('dbi:%s:dbname=%s;host=%s;port=%d', @{ $auth }{ qw/db_type db_name db_host db_port/ }, ), $$auth{db_user}, $$auth{db_pass},
		{
			AutoCommit => $$auth{AutoCommit} // $ENV{DB_AUTOCOMMIT} // $opts{db_autocommit} // 1, 
			RaiseError => $$auth{RaiseError} // $ENV{DB_RAISEERROR} // $opts{db_raiseerror} // 0, 
			sqlite_see_if_its_a_number => 1
		}
	) or die $DBI::errstr;

	$conn->mode('fixup');

	if ( $$auth{db_type} eq 'Pg' ) {
		db_do( "SET TIME ZONE 'UTC';" );
	}
}

# can call this as: $sth = db_exec('SELECT * FROM TABLE WHERE ID = ?;', 1337 );
# and collect results: $sth->fetchrow_hashref() && $sth->finish;
sub db_exec {
	my $query = shift;
	my $sth = $conn->run( sub { $_->prepare($query); } );
	if ( not defined wantarray() ) {
		$sth->finish;
		return undef;
	} else {
		$sth->execute( @_ )
	}
	return $sth;
}

sub db_do {
	my $query = shift;
	my @opts = @_;
	$conn->run( sub { $_->do( $query, {}, @opts ) } );
}

sub db_prepare {
	my $query = shift;
	$conn->run( sub { $_->prepare($query) } );
}

1;
