package AswatShop::Core::Auth;

use Mojo::Base -strict;
use Date::Parse;

sub new {
	my ($class, $config) = @_;

	my $self = {};
	bless $self, $class;

	$self->{config} = $config;

	return $self;
}

sub getAuthorizedUser {
	my ($self, $session_token) = @_;

	# Validate session token. Invalid if longer than MD5 32 chars
	return
		unless $session_token =~ m/^.{1,32}$/;

	# Initialize DB
	my $db_file = $self->{config}->{aswat_db_file};
	my $sqlite 	= Mojo::SQLite->new($db_file);
	my $db 		= $sqlite->db;

	# Check if session token is valid/exists in db
	my $sql = "SELECT id, user_id, datetime(created, 'localtime') AS created "
		. 'FROM session WHERE token = ?';
	my $session = $db->query($sql, $session_token)->hash;

	return
		unless $session->{id};

	# Check if token is expired
	my ($ss,$mm,$hh,$day,$month,$year) = strptime($session->{created});
	my ($ss_now,$mm_now,$hh_now,$day_now,$month_now,$year_now) = localtime;

	return
		if $year != $year_now
			|| $month != $month_now
			|| $day != $day_now;

	# Fetch all users from DB for later authentication
	$sql = "SELECT id, name, password, is_admin FROM user "
		. "WHERE id = ?";
	my $user = $db->query($sql, $session->{user_id})->hash;	

	return $user;
}

42;
