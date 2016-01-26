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

	$routes->rest_routes(name => 'Session');
	$routes->rest_routes(name => 'Product');
	$routes->rest_routes(name => 'Cart');
	$routes->rest_routes(name => 'User');

	# Normal route to controller
	$routes->get('/')->to('example#welcome');
}

1;
