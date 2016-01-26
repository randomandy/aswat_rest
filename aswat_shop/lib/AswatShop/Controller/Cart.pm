package AswatShop::Controller::Cart;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use Mojo::SQLite;
use Data::Dumper;
use AswatShop::Core::Auth;

# Log to STDERR
my $log = Mojo::Log->new;

# Returns the list of products in cart for the logged in user
sub list_cart {
	my ($self) = @_;

	# Get Authenticater
	my $auth = AswatShop::Core::Auth->new($self->stash('config'));

	# Authorize session token and get User Hash
	my $user = $auth->getAuthorizedUser(
		$self->req->headers->header('x-aswat-token')
	);

	# Return 401 if user is not authorized
	unless ($user) {
		$self->res->code(401);
		return $self->render(json => {error => 'access denied'});
	}

	# Initialize DB
	my $db_file = $self->stash('config')->{aswat_db_file};
	my $sqlite 	= Mojo::SQLite->new($db_file);
	my $db 		= $sqlite->db;

	my $user_id = $user->{id};

	$log->debug("User ID extracted from session: " . Dumper($user_id));

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

	$log->debug("Cart for User ID '$user_id': " . Dumper(\@cart));

	# Return array of products in cart
	return $self->render( json => \@cart );
}

# Add a product to the users cart
sub update_cart {
	my ($self) = @_;

	# Get Authenticater
	my $auth = AswatShop::Core::Auth->new($self->stash('config'));

	# Authorize session token and get User Hash
	my $user = $auth->getAuthorizedUser(
		$self->req->headers->header('x-aswat-token')
	);

	# Return 401 if user is not authorized
	unless ($user) {
		$self->res->code(401);
		return $self->render(json => {error => 'access denied'});
	}

	# Initialize DB
	my $db_file = $self->stash('config')->{aswat_db_file};
	my $sqlite 	= Mojo::SQLite->new($db_file);
	my $db 		= $sqlite->db;

	my $user_id = $user->{id};

	# Fetch product ID parameter
	my $product_id = $self->stash('cartId');

	# Return 400 unless parsed values pass validation
	unless ( $product_id =~ m/^[0-9]{1,5}$/ ) {
		$self->res->code(400);
		return $self->render(json => {error => 'invalid user id'});
	}

	# Get product details
	my $sql 	= 'SELECT id, name, stock FROM product WHERE id = ?';
	my $product = $db->query($sql, $product_id)->hash;
	$log->debug("[/cart] Product details: " . Dumper($product));

	# Return 410 and error message if product is out of stock
	if ($product->{stock} <= 0) {
		$log->debug("[/cart] Product '$product_id' out of stock");
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
		$log->debug("[/cart] Product already in cart. Quantity: "
			. "'$product_in_cart->{quantity}'. Adding one more...");

		my $sql    = 'UPDATE cart SET quantity = ? WHERE id = ?';
		my @values = ($product_in_cart->{quantity} +1, $product_in_cart->{id});
		$db->query($sql, @values);
		$new_cart_entry_id = 1;

	# Add product to cart unless already in cart
	} else {
		$log->debug("[/cart] Adding product '$product_id' to cart...");
		my $sql    = "INSERT INTO cart (user_id, product_id, quantity) "
			. "VALUES (?, ?, ?)";
		my @values = ($user_id, $product_id, 1);
		$new_cart_entry_id = $db->query($sql, @values)->last_insert_id;
	}

	# Remove product from stock
	my $new_product_stock = $product->{stock} - 1;
	$sql = 'UPDATE product SET stock = ? WHERE id = ?';
	$db->query($sql, ($new_product_stock, $product_id));
	$log->debug("[/cart] New product stock: '$new_product_stock'");

	# Rollback DB transaction if any DB operiation failed
	unless ($new_cart_entry_id) {
		# Auto rollback transaction
		$log->debug("[/cart] DB update failed. Rollback.");
		$tx = undef;

		return $self->render(json => {success => 0});
	}

	# Commit DB transaction
	$tx->commit;

	return $self->render(json => {success => 1});
}

# Remove a product from the users cart
sub delete_cart {
	my ($self) = @_;

	# Get Authenticater
	my $auth = AswatShop::Core::Auth->new($self->stash('config'));

	# Authorize session token and get User Hash
	my $user = $auth->getAuthorizedUser(
		$self->req->headers->header('x-aswat-token')
	);

	# Return 401 if user is not authorized
	unless ($user) {
		$self->res->code(401);
		return $self->render(json => {error => 'access denied'});
	}

	# Initialize DB
	my $db_file = $self->stash('config')->{aswat_db_file};
	my $sqlite 	= Mojo::SQLite->new($db_file);
	my $db 		= $sqlite->db;

	my $user_id = $user->{id};

	# Fetch product ID parameter
#TODO validate ID (int, max length)
	my $product_id = $self->stash('cartId');

	# Get product details
	my $sql 	= 'SELECT id, name, stock FROM product WHERE id = ?';
	my $product = $db->query($sql, $product_id)->hash;
	$log->debug("[/cart] Product details: " . Dumper($product));

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
		$log->debug("[/cart] Product deleted from cart");

	# If product is in cart more than once, reduce quantity by one
	} elsif ($product_in_cart->{quantity} >= 2) {
		my $sql    = 'UPDATE cart SET quantity = ? WHERE id = ?';
		my @values = ($product_in_cart->{quantity} -1, $product_in_cart->{id});
		$db->query($sql, @values);
		$log->debug("[/cart] One product removed from cart");
	}

	# Add product back to stock
	$sql 	   = 'UPDATE product SET stock = ? WHERE id = ?';
	my @values = ($product->{stock} +1, $product->{id});
	$db->query($sql, @values);
	$log->debug("[/cart] One product moved back to stock");

	return $self->render(json => {success => 1});
}

42;
