package AswatShop::Controller::Cart;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use Mojo::SQLite;
use Data::Dumper;
use AswatShop::Core::Auth;

# Log to STDERR
my $log = Mojo::Log->new;

sub list_cart {
	my ($self) = @_;

	# Get Authenticater
	my $auth = AswatShop::Core::Auth->new($self->stash('config'));

	# Authorize session token and get User Hash
	my $user = $auth->getAuthorizedUser(
		$self->req->headers->header('x-aswat-token')
	);

	return
		unless $user;

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

42;
