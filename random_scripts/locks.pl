#!/usr/bin/perl
use warnings;
use strict;
use feature 'say';

use DBI;

my $numchild = 0;
$SIG{CHLD} = sub {
	if (wait) { 
		$numchild-- 
	}
};

# reworked script for db controlled concurrency
# documentation: https://www.postgresql.org/docs/current/sql-select.html#SQL-FOR-UPDATE-SHARE
# original is here: https://stackoverflow.com/questions/6497545/consistency-in-postgresql-with-locking-and-select-for-update

#                               Table "public.slots"
#   Column  |  Type   | Collation | Nullable |              Default
# ----------+---------+-----------+----------+-----------------------------------
#  id       | integer |           | not null | nextval('slots_id_seq'::regclass)
#  job_name | text    |           |          |
#  usage    | integer |           |          |
# Indexes:
#     "slots_pkey" PRIMARY KEY, btree (id)

sub worker($) {
  my ($i) = @_;
  my $job;

  # reconnect to db in child process:
  my $dbh = DBI->connect("dbi:Pg:host=localhost;dbname=testing", 'testing', 'testing', {RaiseError => 1, AutoCommit => 0}) or die $DBI::errstr;

  my ($x) = 0;
  while(++$x) {
	# fetch an ID to work with and LOCK that table row until end of our trans-action.
    my @id = $dbh->selectrow_array("SELECT ID FROM SLOTS WHERE JOB_NAME IS NULL LIMIT 1 FOR UPDATE;");

    # TODO: what's this?
    # this sleeps for 0.5 before retrying fetching a new job, because there just werent any free.
    if ($#id < 0) {
	$dbh->rollback;
	sleep(.5);
	next;
    }

    $job = "$$-$i-($x)";
    # Update slot name, for some reason?
    $dbh->do(
	    "UPDATE SLOTS SET JOB_NAME = ? WHERE ID = ?", {}, 
	    $job, $id[0]
    ) or die "Cannot update at int: $i";
    # this basically unlocks our row already?
    # but it wont be selected because name is not null yet.
    $dbh->commit or die "Cannot commit! - ", $DBI::errstr;
    last;
  }

  if ( ! $job ) {
    print STDERR "Could not find slots in 5 attempts for $i $$\n" if ($ENV{'verbose'});
    return;
  } else {
    print STDERR "Got $job\n" if ($ENV{'verbose'} > 1);
  }
  sleep(rand(5));

  # update slow counter and unset job_name now:
  # this will make this slot available again.
  $dbh->do(
	  "UPDATE SLOTS SET USAGE = USAGE + 1, JOB_NAME = NULL WHERE JOB_NAME = ?", {}, 
	  $job 
  ) or die "Can't unlock job: $job ", $DBI::errstr;

  print STDERR "PID: $$ - Unlocked $job\n" if ($ENV{'verbose'} > 2);
  $dbh->commit || die "Cannot commit";
}

# connect to db with autocommit on in parent process:
my $dbh = DBI->connect("dbi:Pg:host=localhost;dbname=testing", 'testing', 'testing', {RaiseError => 1, AutoCommit => 1});

say 'Creating new slots table...';
$dbh->do("DROP TABLE IF EXISTS SLOTS;") or die 'Failed to drop TABLE SLOTS...', $DBI::errstr;

$dbh->do("CREATE TABLE IF NOT EXISTS SLOTS(
	ID SERIAL PRIMARY KEY,
	JOB_NAME TEXT,
	USAGE INT);"
) or die "Cannot create TABLE SLOTS - ", $DBI::errstr;

$dbh->do("INSERT INTO SLOTS VALUES (DEFAULT,NULL,0), (DEFAULT,NULL,0), (DEFAULT,NULL,0), (DEFAULT,NULL,0), (DEFAULT,NULL,0), (DEFAULT,NULL,0), (DEFAULT,NULL,0), (DEFAULT,NULL,0), (DEFAULT,NULL,0), (DEFAULT,NULL,0);") or die "Cannot insert dummy data - ", $DBI::errstr;

for(my $i=0;$i<100;$i++) {
  if (!fork) {
# disconnect from db in child process:
    $dbh->disconnect;
    worker($i);
    exit(0);
  }

  if (++$numchild > 25) {
    sleep(1);
  }
}

while (wait > 0) {
  $numchild--;
  print "Waiting numchild $numchild\n";
  sleep(1);
}

my $sum = 0;
# my $slots = $dbh->selectall_arrayref("SELECT * FROM SLOTS;") or die "Cannot do final select";
$dbh->disconnect;
$dbh = DBI->connect("dbi:Pg:host=localhost;dbname=testing", 'testing', 'testing', {RaiseError => 1, AutoCommit => 1}) or die $DBI::errstr;
my $prep = $dbh->prepare("SELECT * FROM SLOTS ORDER BY ID DESC;") or die $DBI::errstr;
$prep->execute() or die $DBI::errstr;

# foreach my $slot (@$slots) {
while ( my $slot = $prep->fetchrow_arrayref() ) {
  printf("%02d %3d %s\n",$slot->[0], $slot->[2], $slot->[1]);
  $sum += $slot->[2];
}
$prep->finish;
print "Successfully made $sum entries\n";
$dbh->disconnect;
