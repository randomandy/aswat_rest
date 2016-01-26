use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);

my $t = Test::Mojo->new('AswatShop');

# Test POST /sessions without AUTH -> 401 expected
$t->post_ok('/api/v1/sessions')->status_is(401, 'POST sessions');

done_testing();
