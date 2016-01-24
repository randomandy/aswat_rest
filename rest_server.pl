#!/usr/bin/env perl

use strict;
use warnings;

use feature qw(say);

use Path::Class 'file';
use Mojolicious::Lite;

# Class to format data for debugging and logging
use Data::Dumper;

# Rewriting the app handler into my own valid Perl object
# quick note: 'app' is a keyword added by the Mojolicious framework
my $app = app;

#TODO add username/password validation/limit
#TODO add oauth2 or other token handling
#TODO add TLS
#TODO add versioning
#TODO add routes
#TODO add db

# Route to fetch all products via GET /product
get '/product/' => sub {
	my ($self) = @_;

#TODO replace with real data
	my @mock_products = (
		{
			id => 1,
			name => 'the one ring',
			stock => 1
		},
		{
			id => 2,
			name => 'death star plans',
			stock => 7
		}
	);

	# return the mock data in JSON
	return $self->render( json => { products => \@mock_products } );
};

# Route to fetch product details via GET /product/123
get '/product/:id' => sub {
	my ($self) = @_;

	my $product_id = $self->stash('id');

#TODO replace with real data
	my $mock_product_details = {
		id => 2,
		name => 'death star plans',
		stock => 7
	};

	# return the mock data in JSON
	return $self->render( json => $mock_product_details );
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

# Run the application
$app->start;

