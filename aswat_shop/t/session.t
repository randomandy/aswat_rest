use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);

my $t = Test::Mojo->new('AswatShop');

# Test POST /sessions without AUTH -> 401 expected
$t->post_ok('/api/v1/sessions')->status_is(401, 'POST sessions');


# Test POST /sessions with valid AUTH -> 200 expected
# Build AUTH URL for next request
my $url = $t->ua->server->url->userinfo('linustorvalds:ilovexbox')
	->path('/api/v1/sessions');
# Extract session data for later tests
my $session_json = $t->post_ok($url)->status_is(200)
	->json_message_has('session_token')
		->tx->res->content->asset->slurp;
my $session = decode_json($session_json);


# Test DELETE /sessions/ID
my $tx = $t->ua->build_tx(
	DELETE => '/api/v1/sessions/' . $session->{session_id} 
		=> {'x-aswat-token' => $session->{session_token}}
);
$t->request_ok($tx)->status_is(200);

done_testing();
