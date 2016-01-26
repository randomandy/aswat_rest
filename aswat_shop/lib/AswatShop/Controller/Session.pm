package AswatShop::Controller::Session;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use Mojo::SQLite;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);

# Log to STDERR
my $log = Mojo::Log->new;

sub create_session {
	my ($self) = @_;

	# Initialize DB
	my $db_file = $self->stash('config')->{aswat_db_file};
	my $sqlite 	= Mojo::SQLite->new($db_file);
	my $db 		= $sqlite->db;

	$log->debug("[Auth] Trying to authorize basic auth: "
		. $self->req->headers->authorization);

	# Fetch all users from DB for later authentication
	my $sql   = 'SELECT id, name, password FROM user';
	my @users = $db->query($sql)->hashes->each;
	my %user_pwd_strings;

	foreach my $user (@users) {
		# Copy user string for basic auth and store user ID for session
		my $auth_string = $user->{name} . " " . $user->{password};
		$user_pwd_strings{$auth_string} = $user->{id};
	}
	$log->debug("[/session] All users: ". Dumper(\%user_pwd_strings));

	# Authenticate user passed via basic auth with previsously fetched users
	# and create new session in DB

	# If user is authenticated
	my $authorized_user_id;
	if ($self->basic_auth( realm => sub {
			if (exists $user_pwd_strings{"@_"}) {
				$authorized_user_id = $user_pwd_strings{"@_"};
				return 1;
			}
		}))
	{
		$log->debug("User ID Authorized: '$authorized_user_id'");

		# Check for old session
		my $sql = "SELECT id, datetime(created, 'localtime') AS created "
			. 'FROM session WHERE user_id = ?';
		my $session = $db->query($sql, ( $authorized_user_id ))->hash;

		if ($session) {
			$log->debug("Session already exists for User ID "
				. "'$authorized_user_id': " . Dumper($session));

			# Delete old session
			my $sql = "DELETE FROM session WHERE user_id = ?";
			$db->query($sql, $authorized_user_id);
		}

		# Create session
		my $new_session_token = md5_hex(localtime . 'secret');
		my @values = (
			$authorized_user_id,
			$new_session_token
		);
#TODO check if DB operation was succesful
		$sql = 'INSERT INTO session (user_id, token) VALUES (?, ?)';
		my $session_id = $db->query($sql, @values)->last_insert_id;

		$log->debug("New session key '$new_session_token' added for User "
			. "ID: '$authorized_user_id'");

		return $self->render( json => {
			session_id 	  => $session_id,
			session_token => $new_session_token
		} );
	} 

	# Deny access if DB user validation was unsuccessful
	$log->debug("User access denied");

	return;
}

sub delete_session {
	my ($self) = @_;

	# Fetch product ID parameter
	my $session_id = $self->stash('sessionId');

	$log->debug("[/session] ID: ". Dumper($session_id));	

	# Initialize DB
	my $db_file = $self->stash('config')->{aswat_db_file};
	my $sqlite 	= Mojo::SQLite->new($db_file);
	my $db 		= $sqlite->db;

	# Fetch the session token from the HTTP header
#TODO validate session token (max length)
	my $session_token = $self->req->headers->header('x-aswat-token');

	# Delete old session
	my $sql = "DELETE FROM session WHERE token = ? AND id = ?";
	my $success = $db->query($sql, $session_token, $session_id)->rows;

	return $self->render( json => {success => $success} );
}

42;
