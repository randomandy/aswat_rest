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


# Test GET /users
my $tx = $t->ua->build_tx(
	GET => '/api/v1/users'
		=> {'x-aswat-token' => $session->{session_token}}
);
my $users = $t->request_ok($tx)->status_is(200)
	->tx->res->content->asset->slurp;
# print STDERR Dumper(decode_json($users));


# Test POST /users
$tx = $t->ua->build_tx(
	POST => '/api/v1/users'
		=> {'x-aswat-token' => $session->{session_token}}
		=> json => {username => 'steve130', password => 'steve1234'}
);
# {"username":"andy123", "password":"mYs3Cr3t!", "is_admin":1}
my $json_response = $t->request_ok($tx)->status_is(200)
	->tx->res->content->asset->slurp;
my $response 	= decode_json($json_response);
my $new_user_id = $response->{user_id};

print STDERR Dumper($response);

ok ($response->{success} == 1, 'New user created');


# Test PUT /users/ID
$tx = $t->ua->build_tx(
	PUT => '/api/v1/users/' . $new_user_id
		=> {'x-aswat-token' => $session->{session_token}}
		=> json => {username => 'steve12345', password => 'foobar!'}
);
$json_response = $t->request_ok($tx)->status_is(200)
	->tx->res->content->asset->slurp;
$response 	= decode_json($json_response);

print STDERR Dumper($response);

ok ($response->{success} == 1, 'User password changed');


# Test DELETE /users/ID
$tx = $t->ua->build_tx(
	DELETE => '/api/v1/users/' . $new_user_id
		=> {'x-aswat-token' => $session->{session_token}}
);
$json_response = $t->request_ok($tx)->status_is(200)
	->tx->res->content->asset->slurp;
$response = decode_json($json_response);

print STDERR Dumper($response);

ok ($response->{success} == 1, 'User deleted');


# Logout / Delete session
$tx = $t->ua->build_tx(
	DELETE => '/api/v1/sessions/' . $session->{session_id} 
		=> {'x-aswat-token' => $session->{session_token}}
);
$t->request_ok($tx)->status_is(200);



done_testing();


# my $tx = $t->ua->build_json_tx('/user/99' => {name => 'sri'});
# $tx->req->method('PUT');
# $t->request_ok($tx)
#   ->status_is(200)
#   ->json_is('/message' => 'User has been replaced.');