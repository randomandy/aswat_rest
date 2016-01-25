#!/usr/bin/env perl

use strict;
use warnings;

use Mojolicious::Lite;
use Mojo::SQLite;
use Date::Parse;
use Data::Dumper;

plugin 'basic_auth';

# Rewriting the app handler into my own valid Perl object
# quick note: 'app' is a keyword added by the Mojolicious framework
my $app = app;

#TODO add username/password validation/limit
#TODO add TLS
#TODO add versioning

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

		# Check for old session
		my $sql = "SELECT id, datetime(created, 'localtime') AS created "
			. 'FROM session WHERE user_id = ?';
		my $session = $db->query($sql, ( $authorized_user_id ))->hash;

		if ($session) {
			$app->log->debug("Session already exists for User ID "
				. "'$authorized_user_id': " . Dumper($session));

			# Delete old session
			my $sql = "DELETE FROM session WHERE user_id = ?";
			$db->query($sql, $authorized_user_id)->hash;
		}

		# Create session
#TODO generate secure token
		my $new_session_token = "123abc " . localtime;
		my @values = (
			$authorized_user_id,
			$new_session_token
		);
#TODO check if DB operation was succesful
		$sql = 'INSERT INTO session (user_id, token) VALUES (?, ?)';
		$db->query($sql, @values);

		$app->log->debug("New session key '$new_session_token' added for User "
			. "ID: '$authorized_user_id'");

		return $self->render( json => {session_token => $new_session_token} );
	} 

	# Deny access if DB user validation was unsuccessful
	$app->log->debug("User access denied");

	return;
};

# Route to remove session and logout user DELETE /session
del '/session' => sub {
	my ($self) = @_;

	# Fetch the session token from the HTTP header
#TODO validate session token (max length)
	my $session_token = $self->req->headers->header('x-aswat-token');

	# Delete old session
	my $sql = "DELETE FROM session WHERE token = ?";
	$db->query($sql, $session_token)->hash;

	return $self->render( json => {success => 1} );
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

	# Authorize session token and get User ID
	my $user_id = _is_authorized($self->req->headers->header('x-aswat-token'));
	$app->log->debug("User ID extracted from session: " . Dumper($user_id));

	# Return 401 if user is not authorized
	unless ($user_id) {
		$self->res->code(401);
		return $self->render(json => {error => 'access denied'});
	}

	# Fetch all cart entries for logged in user
	my $sql  = 'SELECT id, product_id, quantity FROM cart WHERE user_id = ?';
	my @cart = $db->query($sql, $user_id)->hashes->each;

	# Get product details for each product in cart
	foreach my $product (@cart) {
		my $sql 		 = 'SELECT name FROM product WHERE id = ?';
		$product->{name} = $db->query($sql, $product->{product_id})->hash;
	}

	$app->log->debug("Cart for User ID '$user_id': " . Dumper(\@cart));

	# Return array of products in cart
	return $self->render( json => \@cart );
};

# Route to add product to user cart via PUT /cart/123
put '/cart/:productid' => sub {
	my ($self) = @_;

	# Authorize session token and get User ID
	my $user_id = _is_authorized($self->req->headers->header('x-aswat-token'));
	$app->log->debug("User ID extracted from session: " . Dumper($user_id));

	# Return 401 if user is not authorized
	unless ($user_id) {
		$self->res->code(401);
		return $self->render(json => {error => 'access denied'});
	}

	# Fetch product ID parameter
#TODO validate ID (int, max length)
	my $product_id = $self->stash('productid');

	# Get product details
	my $sql 	= 'SELECT id, name, stock FROM product WHERE id = ?';
	my $product = $db->query($sql, $product_id)->hash;
	$app->log->debug("[/cart] Product details: " . Dumper($product));

	# Return 410 and error message if product is out of stock
	if ($product->{stock} <= 0) {
		$app->log->debug("[/cart] Product '$product_id' out of stock");
		$self->res->code(410);
		return $self->render(json => {error => 'out of stock'});
	}

	# Check if product is already in cart
	$sql = "SELECT id, quantity FROM cart "
		. "WHERE product_id = ? AND user_id = ?";
	my $product_in_cart = $db->query($sql, ($product_id, $user_id))->hash;	

	# Begin DB transaction
	my $tx = $db->begin;

	# Increase quantity in cart if product is already in cart
	# Check if product is already in cart
	my $new_cart_entry_id = undef;

	if ($product_in_cart) {
		$app->log->debug("[/cart] Product already in cart. Quantity: "
			. "'$product_in_cart->{quantity}'. Adding one more...");

		my $sql    = 'UPDATE cart SET quantity = ? WHERE id = ?';
		my @values = ($product_in_cart->{quantity} +1, $product_in_cart->{id});
		$db->query($sql, @values);
		$new_cart_entry_id = 1;

	# Add product to cart unless already in cart
	} else {
		$app->log->debug("[/cart] Adding product '$product_id' to cart...");
		my $sql    = "INSERT INTO cart (user_id, product_id, quantity) "
			. "VALUES (?, ?, ?)";
		my @values = ($user_id, $product_id, 1);
		$new_cart_entry_id = $db->query($sql, @values)->last_insert_id;
	}

	# Remove product from stock
	my $new_product_stock = $product->{stock} - 1;
	$sql = 'UPDATE product SET stock = ? WHERE id = ?';
	$db->query($sql, ($new_product_stock, $product_id));
	$app->log->debug("[/cart] New product stock: '$new_product_stock'");

	# Rollback DB transaction if any DB operiation failed
	unless ($new_cart_entry_id) {
		# Auto rollback transaction
		$app->log->debug("[/cart] DB update failed. Rollback.");
		$tx = undef;

		return $self->render(json => {success => 0});
	}

	# Commit DB transaction
	$tx->commit;

	return $self->render(json => {success => 1});
};

# Route to remove product from user cart via DELETE /cart/123
del '/cart/:productid' => sub {
	my ($self) = @_;

	# Authorize session token and get User ID
	my $user_id = _is_authorized($self->req->headers->header('x-aswat-token'));
	$app->log->debug("User ID extracted from session: " . Dumper($user_id));

	# Return 401 if user is not authorized
	unless ($user_id) {
		$self->res->code(401);
		return $self->render(json => {error => 'access denied'});
	}

	# Fetch product ID parameter
#TODO validate ID (int, max length)
	my $product_id = $self->stash('productid');

	# Get product details
	my $sql 	= 'SELECT id, name, stock FROM product WHERE id = ?';
	my $product = $db->query($sql, $product_id)->hash;
	$app->log->debug("[/cart] Product details: " . Dumper($product));

	# Check if product is in cart
	$sql = "SELECT id, quantity FROM cart "
		. "WHERE product_id = ? AND user_id = ?";
	my $product_in_cart = $db->query($sql, ($product_id, $user_id))->hash;

	# Return 404 and error message if product cannot be found in cart
	unless ($product_in_cart) {
		$self->res->code(404);
		return $self->render(json => {error => 'product not found in cart'});
	}

	# If product is in cart only once, delete from cart
	if ($product_in_cart->{quantity} == 1) {
		my $sql = "DELETE FROM cart WHERE user_id = ? AND product_id = ?";
		$db->query($sql, ($user_id, $product_id))->hash;
		$app->log->debug("[/cart] Product deleted from cart");

	# If product is in cart more than once, reduce quantity by one
	} elsif ($product_in_cart->{quantity} >= 2) {
		my $sql    = 'UPDATE cart SET quantity = ? WHERE id = ?';
		my @values = ($product_in_cart->{quantity} -1, $product_in_cart->{id});
		$db->query($sql, @values);
		$app->log->debug("[/cart] One product removed from cart");
	}

	# Add product back to stock
	$sql 	   = 'UPDATE product SET stock = ? WHERE id = ?';
	my @values = ($product->{stock} +1, $product->{id});
	$db->query($sql, @values);
	$app->log->debug("[/cart] One product moved back to stock");

	return $self->render(json => {success => 1});
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

sub _is_authorized {
	my ($session_token) = @_;

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

	return $session->{user_id};
}

sub _get_authorized_user {
	my ($session_token) = @_;

	# Validate session token. Invalid if longer than MD5 32 chars
	return
		unless $session_token =~ m/^.{1,32}$/;

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

# Run the application
$app->start;
