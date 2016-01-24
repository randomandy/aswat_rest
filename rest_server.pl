#!/usr/bin/env perl

use strict;
use warnings;

use feature qw(say);

use Path::Class 'file';
use Mojolicious::Lite;


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

# Run the application
$app->start;

