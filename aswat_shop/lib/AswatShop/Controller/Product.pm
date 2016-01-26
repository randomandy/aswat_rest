package AswatShop::Controller::Product;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use Mojo::SQLite;
use Data::Dumper;

# Log to STDERR
my $log = Mojo::Log->new;

sub list_product {
	my ($self) = @_;

	# return JSON with list of all products
	return $self->render( json => $self->_getProduct() );
}

sub read_product {
	my ($self) = @_;

	my $product_id = $self->stash('productId');

	# return the processed data in JSON
	return $self->render( json => $self->_getProduct($product_id) );
}

sub _getProduct {
	my ($self, $product_id) = @_;

	# Initialize DB
	my $db_file = $self->stash('config')->{aswat_db_file};
	my $sqlite 	= Mojo::SQLite->new($db_file);
	my $db 		= $sqlite->db;

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

42;
