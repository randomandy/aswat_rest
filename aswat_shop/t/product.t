use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);

my $t = Test::Mojo->new('AswatShop');


# Test GET /products
my $tx = $t->ua->build_tx(
	GET => '/api/v1/products'
);
my $json_response = $t->request_ok($tx)->status_is(200)
	->tx->res->content->asset->slurp;
my $response = decode_json($json_response);
print STDERR Dumper($response);

ok (exists($response->{products}), 'Valid list of products received');


# Test GET /products/ID
my $tx = $t->ua->build_tx(
	GET => '/api/v1/products/1'
);
my $json_response = $t->request_ok($tx)->status_is(200)
	->tx->res->content->asset->slurp;
my $response = decode_json($json_response);
print STDERR Dumper($response);

ok (exists($response->{products}), 'Valid single product details received');

done_testing();
