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

}

# Creates a new user. Admin only
sub create_user {
	my ($self) = @_;

}

# Deletes a user from the DB. Admin only
sub delete_user {
	my ($self) = @_;

}

42;
