package AswatShop::Controller::User;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use Mojo::SQLite;
use Data::Dumper;
use AswatShop::Core::Auth;

# Log to STDERR
my $log = Mojo::Log->new;

# Returns the list of all users in the DB. Admin only
sub list_user {
	my ($self) = @_;

	# Get Authenticater
	my $auth = AswatShop::Core::Auth->new($self->stash('config'));

	# Authorize session token and get User Hash
	my $user = $auth->getAuthorizedUser(
		$self->req->headers->header('x-aswat-token')
	);

	# Return 401 if user is not authorized. Only admin can edit user
	unless ($user && $user->{is_admin}) {
		$self->res->code(401);
		return $self->render(json => {error => 'access denied'});
	}

	# Initialize DB
	my $db_file = $self->stash('config')->{aswat_db_file};
	my $sqlite 	= Mojo::SQLite->new($db_file);
	my $db 		= $sqlite->db;

	# Get all users from DB
	my $sql = 'SELECT id, name, password, is_admin FROM user';
	my @users = $db->query($sql)->hashes->each;
	$log->debug("All users in DB: " . Dumper(\@users));

	# return user array
	return $self->render(json => { users => \@users });
}

# Updates an existing user. Admin only
sub update_user {
	my ($self) = @_;

	# Fetch product ID parameter
	my $user_id = $self->stash('userId');

	# Return 400 unless parsed values pass validation
	unless ( $user_id =~ m/^[0-9]{1,5}$/ ) {
		$self->res->code(400);
		return $self->render(json => {error => 'invalid user id'});
	}

	# Get Authenticater
	my $auth = AswatShop::Core::Auth->new($self->stash('config'));

	# Authorize session token and get User Hash
	my $user = $auth->getAuthorizedUser(
		$self->req->headers->header('x-aswat-token')
	);

	# Return 401 if user is not authorized. Only admin can edit user
	unless ($user && $user->{is_admin}) {
		$self->res->code(401);
		return $self->render(json => {error => 'access denied'});
	}

	# Initialize DB
	my $db_file = $self->stash('config')->{aswat_db_file};
	my $sqlite 	= Mojo::SQLite->new($db_file);
	my $db 		= $sqlite->db;

	# Get old user data
	my $sql 	 = 'SELECT name, password, is_admin FROM user WHERE id = ?';
	my $old_user = $db->query($sql, $user_id)->hash;
	$log->debug("Old user data: " . Dumper($old_user));

	# Get all users from DB
	$sql 	  = 'SELECT id, name, password, is_admin FROM user';
	my @users = $db->query($sql)->hashes->each;
	$log->debug("All users in DB: " . Dumper(\@users));

	my $user_data = $self->req->json;
	$log->debug("[/user] Payload: " . Dumper($user_data));

	# Check if user already exists. Update or create
	my $username_payload = $user_data->{username};
	my $user_exists 	 = 0;
	foreach my $user (@users) {
		$user_exists = 1
			if $user->{name} eq $username_payload;
	}

	# Set missing parameters to original values to pass validation
	$user_data->{username} = $old_user->{name}
		unless $user_data->{username};

	$user_data->{password} = $old_user->{password}
		unless $user_data->{password};

	$user_data->{is_admin} = $old_user->{is_admin}
		unless $user_data->{is_admin};

	# Return 400 unless parsed values pass validation
	unless ( _is_userdata_valid($user_data) ) {
		$self->res->code(400);
		return $self->render(json => {error => 'invalid format'});
	}

	# Set default return values
	my $success_status = 0;
	my $return_message = "Unable to parse payload. Invalid format?";

	# If user exists, return error
	if ($user_exists) {
		$log->debug("User '$username_payload' already exists in DB");
		$return_message = "Username already taken";

	# If user doesn't exist, create new user
	} else {
		$log->debug("Editing user ID '$user_id'...");
		$return_message = "User updated successfully";
		$success_status = 1;

		$user_data->{is_admin} = 0
			unless $user_data->{is_admin};

		my @values = (
			$user_data->{username},
			$user_data->{password},
			$user_data->{is_admin},
			$user_id
		);

		my $sql = "UPDATE user SET name = ?, password = ?, is_admin = ? "
			. "WHERE id = ?";
		$db->query($sql, @values);

		$log->debug("User updated: " . Dumper($user_data));
	}

	# Return JSON message with success status and message
	return $self->render(
		json => {
			success => $success_status,
			message => $return_message
		}
	);
}

# Creates a new user. Admin only
sub create_user {
	my ($self) = @_;

}

# Deletes a user from the DB. Admin only
sub delete_user {
	my ($self) = @_;

}

sub _is_userdata_valid {
	my ($user_candidate) = @_;

	# Username has to be min 3, max 10 chars and only alphanumeric
	return
		unless $user_candidate->{username} =~ m/^[a-zA-B0-9]{3,10}$/;

	# Password has to be min 4, max 30 chars
	return
		unless $user_candidate->{password} =~ m/^.{4,30}$/;

	return 1;
}

42;
