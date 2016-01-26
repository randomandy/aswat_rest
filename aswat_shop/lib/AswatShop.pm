package AswatShop;
use Mojo::Base 'Mojolicious';


# This method will run once at server start
sub startup {
	my $self = shift;

	my $config = $self->plugin(yaml_config => {
		file => 'conf/shop.yml',
	});

	# Documentation browser under "/perldoc"
	$self->plugin('PODRenderer');
	$self->plugin('basic_auth');
	$self->plugin('REST' => { prefix => 'api', version => 'v1' });

	# Router
	my $routes = $self->routes;

	$routes->rest_routes( name => 'Session' );

	# Installs following routes:

	# /api/v1/accounts             ....  GET     "Account::list_account()"    ^/api/v1/accounts(?:\.([^/]+)$)?
	# /api/v1/accounts             ....  POST    "Account::create_account()"  ^/api/v1/accounts(?:\.([^/]+)$)?
	# /api/v1/accounts/:accountId  ....  DELETE  "Account::delete_account()"  ^/api/v1/accounts/([^\/\.]+)(?:\.([^/]+)$)?
	# /api/v1/accounts/:accountId  ....  GET     "Account::read_account()"    ^/api/v1/accounts/([^\/\.]+)(?:\.([^/]+)$)?
	# /api/v1/accounts/:accountId  ....  PUT     "Account::update_account()"  ^/api/v1/accounts/([^\/\.]+)(?:\.([^/]+)$)?




	# Normal route to controller
	$routes->get('/')->to('example#welcome');
}

1;
