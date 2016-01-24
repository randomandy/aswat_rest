#!/usr/bin/env perl

use strict;
use warnings;

use Mojolicious::Lite;
use Mojo::SQLite;
use Data::Dumper;

plugin 'basic_auth';

# Rewriting the app handler into my own valid Perl object
# quick note: 'app' is a keyword added by the Mojolicious framework
my $app = app;

#TODO add username/password validation/limit
#TODO add oauth2 or other token handling
#TODO add TLS
#TODO add versioning
#TODO add routes
#TODO add db

# Initialize SQLite DB
#TODO move to config
my $sql = Mojo::SQLite->new('sqlite:aswat_shop.db');
my $db 	= $sql->db;

# Route to get new session via GET /product
get '/session/' => sub {
	my ($self) = @_;

	$app->log->debug("[Auth] Trying to authorize basic auth: "
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
	$app->log->debug("[/session] All users: ". Dumper(\%user_pwd_strings));

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
		$app->log->debug("User ID Authorized: '$authorized_user_id'");

		# check for old session
#TODO check if DB operation was succesful

		my $sql = "SELECT id, datetime(created, 'localtime') AS created "
			. 'FROM session WHERE user_id = ?';
		my $session = $db->query($sql, ( $authorized_user_id ))->hash;

		if ($session) {
			$app->log->debug("Session already exists for User ID "
				. "'$authorized_user_id': " . Dumper($session));

			# delete / update session

			return $self->render( json => { session => $session} );
		}

		# create session
#TODO generate secure token
		my $new_session_token = '123abc';
		my @values = (
			$authorized_user_id,
			$new_session_token
		);
#TODO check if DB operation was succesful
		$sql = 'INSERT INTO session (user_id, token) VALUES (?, ?)';
		$db->query($sql, @values);

		$app->log->debug("New session key '$new_session_token' added for User "
			. "ID: '$authorized_user_id'");

		return $self->render( json => { session_token => $new_session_token} );
	} 

	# Deny access if DB user validation was unsuccessful
	$app->log->debug("User access denied");

	return;
};

# Route to fetch all products via GET /product
# No need for AUTH here, it's public data
get '/product/' => sub {
	my ($self) = @_;

	# return the processed data in JSON
	return $self->render( json => _get_product() );
};

# Route to fetch product details via GET /product/123
get '/product/:id' => sub {
	my ($self) = @_;

	my $product_id = $self->stash('id');

	# return the processed data in JSON
	return $self->render( json => _get_product($product_id) );
};

# Route to fetch user cart via GET /cart
get '/cart' => sub {
	my ($self) = @_;

	# Fetch the session token from the HTTP header
	my $session_token = $self->req->headers->header('x-aswat-token');

#TODO fetch user cart based on session token

	# Write debug to STDOUT
	$app->log->debug("[/cart] Session: " . Dumper($session_token));

	# MOCK DATA
	my $cart_id = 1;
	my @product_ids_in_cart = (
		{
			id => 1,
			quantity => 1
		},
		{
			id => 2,
			quantity => 3
		}
	);

	my $mock_cart = {
		id => $cart_id,
		products => \@product_ids_in_cart,
	};

	# return the mock data in JSON
	return $self->render( json => $mock_cart );
};

# Route to add product to user cart via PUT /cart/123
put '/cart/:productid' => sub {
	my ($self) = @_;

	# Fetch the session token from the HTTP header
#TODO validate session token (max length)
	my $session_token = $self->req->headers->header('x-aswat-token');

	# Fetch product ID parameter
#TODO validate ID (int, max length)
	my $product_id = $self->stash('productid');

	# MOCK DATA
	my $cart_id = 1;
	my @product_ids_in_cart = (
		{
			id => 1,
			quantity => 1
		},
		{
			id => 2,
			quantity => 3
		}
	);

	my $mock_cart = {
		id => $cart_id,
		products => \@product_ids_in_cart,
	};

	# Write debug to STDOUT
	$app->log->debug("[/cart] Session: " . Dumper($session_token));
	$app->log->debug("[/cart] Adding product '$product_id' to cart '$cart_id'");

	# return the mock data in JSON
	return $self->render( json => $mock_cart );
};

# Route to remove product from user cart via DELETE /cart/123
del '/cart/:productid' => sub {
	my ($self) = @_;

	# Fetch the session token from the HTTP header
#TODO validate session token (max length)
	my $session_token = $self->req->headers->header('x-aswat-token');

	# Fetch product ID parameter
#TODO validate ID (int, max length)
	my $product_id = $self->stash('productid');

	# MOCK DATA
	my $cart_id = 1;
	my @product_ids_in_cart = (
		{
			id => 1,
			quantity => 1
		},
		{
			id => 2,
			quantity => 3
		}
	);

	my $mock_cart = {
		id => $cart_id,
		products => \@product_ids_in_cart,
	};

	# Write debug to STDOUT
	$app->log->debug("[/cart] Session: " . Dumper($session_token));
	$app->log->debug("[/cart] Removing product '$product_id' "
		. "from cart '$cart_id'");

	# return the mock data in JSON
	return $self->render( json => $mock_cart );
};

# Route to add new user via POST /user
#TODO add check for is_admin
post '/user' => sub {
	my ($self) = @_;

	# Fetch the session token from the HTTP header
#TODO validate session token (max length)
	my $session_token = $self->req->headers->header('x-aswat-token');

	$app->log->debug("[/user] Payload: " . Dumper($self->req->json));
	my $hashref_payload = $self->req->json;

	# Set default return values
	my $success_status = 0;
	my $return_message = "Unable to parse payload. Invalid format?";

	# Check if payload was successfully decoded from JSON
	if (ref($hashref_payload) eq 'HASH') {

#TODO Fetch all users (only usernames) from DB for later authentication
		my @users = (
			{
				name 	 => 'billgates',
				password => 'linuxrules'
			},
			{
				name 	 => 'linustorvalds',
				password => 'ilovexbox'
			},
		);

		# Check if user already exists. Update or create
		my $username_payload = $hashref_payload->{user};
		my $user_exists 	 = 0;
		foreach my $user_in_db (@users) {
			$user_exists = 1
				if $user_in_db->{name} eq $username_payload;
		}

		# If user exists, return error
		if ($user_exists) {
			$app->log->debug("User '$username_payload' already exists in DB");
			$return_message = "Username already taken";

		# If user doesn't exist, create new user
		} else {
			$app->log->debug("Creating new user '$username_payload'...");
			$return_message = "New user added successfully";
			$success_status = 1;

			# Prepare data for DB
			my @new_user = (
				$hashref_payload->{user},
				$hashref_payload->{password}
			);
#TODO write new user to DB
#TODO add validation, prevent SQL injection
		}
	}

	# Return JSON message with success status and message
	return $self->render(
		json => {
			success => $success_status,
			message => $return_message
		}
	);
};

# Route to update user via PUT /user/123
put '/user/:userid' => sub {
	my ($self) = @_;

	# Fetch the session token from the HTTP header
#TODO validate session token (max length)
	my $session_token = $self->req->headers->header('x-aswat-token');

	# Fetch product ID parameter
#TODO validate ID (int, max length)
	my $user_id = $self->stash('userid');

	$app->log->debug("[/user] Payload: " . Dumper($self->req->json));
	my $hashref_payload = $self->req->json;

#TODO update user

	# Write debug to STDOUT
	$app->log->debug("[/user] Session: " . Dumper($session_token));

	# return the mock data in JSON
	return $self->render( json => { success => 1 } );
};

# Route get all users (admin only) via GET /user
get '/user' => sub {
	my ($self) = @_;

	# Fetch the session token from the HTTP header
#TODO validate session token (max length)
	my $session_token = $self->req->headers->header('x-aswat-token');

#TODO fetch all users from DB
		my @mock_users = (
			{
				id 		 => 1,
				name 	 => 'billgates',
				password => 'linuxrules'
			},
			{
				id 		 => 2,
				name 	 => 'linustorvalds',
				password => 'ilovexbox'
			},
		);


	# Write debug to STDOUT
	$app->log->debug("[/user] Session: " . Dumper($session_token));

	# return the mock data in JSON
	return $self->render( json => { users => \@mock_users } );
};

# Route to update user via PUT /user/123
del '/user/:userid' => sub {
	my ($self) = @_;

	# Fetch the session token from the HTTP header
#TODO validate session token (max length)
	my $session_token = $self->req->headers->header('x-aswat-token');

	# Fetch product ID parameter
#TODO validate ID (int, max length)
	my $user_id = $self->stash('userid');

#TODO delete user

	# Write debug to STDOUT
	$app->log->debug("[/user] Session: " . Dumper($session_token));

	# return the mock data in JSON
	return $self->render( json => { success => 1 } );
};

# Function to retrieve products from DB
sub _get_product {
	my ($product_id) = @_;

	# Validate parsed data to avoid SQL injection et al.
	$product_id = undef
		unless $product_id =~ m/^\d+$/;

	my $sql = "SELECT id, name, stock FROM product";
	$sql .= " WHERE id = ?"
		if $product_id;

	# Fetch all products from DB
	my @products = $db->query($sql, $product_id)->hashes->each;

	# return the processed data in JSON
	return { products => \@products };
}

# Run the application
$app->start;

