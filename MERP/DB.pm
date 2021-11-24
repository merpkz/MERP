package MERP::DB;
use warnings;
use strict;
use feature 'say';

use Exporter qw(import);
our @EXPORT      = qw(db_do db_exec);	# always exported
our @EXPORT_OK   = qw(); 		# optional to export

use DBIx::Connector;
use Data::Dumper;

# TODO: how do we pass this during startup?
# simple auth hash used to connect to dbs:

my $auth = {
	type => 'SQLite',
	name => ':memory:',
	user => '',
	pass => '',
	host => '127.0.0.1',
	port => 5432
};

my $conn = DBIx::Connector->new(
	sprintf('dbi:%s:dbname=%s;host=%s;port=%d', @{ $auth }{ qw/type name host port/ }, ), $$auth{user}, $$auth{pass},
	{ AutoCommit => 1, RaiseError => 0, sqlite_see_if_its_a_number => 1 } 
) or die $DBI::errstr;
# what is the default, anways?
$conn->mode('fixup');

if ( $$auth{type} eq 'Pg' ) {
	db_do( "SET TIMEZONE 'UTC';" );
}

# can call this as: $sth = db_exec('SELECT * FROM TABLE WHERE ID = ?;', 1337 );
# and collect results: $sth->fetchrow_hashref() && $sth->finish;

sub db_exec {
	my $query = shift;
	my $sth = $conn->run( sub { $_->prepare_cached($query); } );
	if ( not defined wantarray() ) {
		$sth->finish;
		return undef;
	} else {
		$sth->execute( @_ );
	}
	return $sth;
}

sub db_do {
	my $query = shift;
	my @opts = @_;
	$conn->run( sub { $_->do( $query, {}, @opts ) } );
}

1;
