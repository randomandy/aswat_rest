use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);

my $t = Test::Mojo->new('AswatShop');

# Create session for user tests
my $url = $t->ua->server->url->userinfo('linustorvalds:ilovexbox')
	->path('/api/v1/sessions');

my $session_json = $t->post_ok($url)->status_is(200)
	->json_message_has('session_token')
		->tx->res->content->asset->slurp;

my $session = decode_json($session_json);


# Test PUT /carts/PRODUCT_ID
my $tx = $t->ua->build_tx(
	PUT => '/api/v1/carts/2'
		=> {'x-aswat-token' => $session->{session_token}}
);
my $json_response = $t->request_ok($tx)->status_is(200)
	->tx->res->content->asset->slurp;
my $response = decode_json($json_response);

print STDERR Dumper($response);

ok ($response->{success} == 1, 'Product added to cart');


# Test GET /carts
$tx = $t->ua->build_tx(
	GET => '/api/v1/carts'
		=> {'x-aswat-token' => $session->{session_token}}
);
$json_response = $t->request_ok($tx)->status_is(200)
	->tx->res->content->asset->slurp;
$response = decode_json($json_response);
print STDERR Dumper($response);

ok (scalar(@$response) >= 1, 'Valid cart received');


# Test DELETE /carts/PRODUCT_ID
$tx = $t->ua->build_tx(
	DELETE => '/api/v1/carts/2'
		=> {'x-aswat-token' => $session->{session_token}}
);
$json_response = $t->request_ok($tx)->status_is(200)
	->tx->res->content->asset->slurp;
$response = decode_json($json_response);

print STDERR Dumper($response);


# Logout / Delete session
$tx = $t->ua->build_tx(
	DELETE => '/api/v1/sessions/' . $session->{session_id} 
		=> {'x-aswat-token' => $session->{session_token}}
);
$t->request_ok($tx)->status_is(200);



done_testing();
