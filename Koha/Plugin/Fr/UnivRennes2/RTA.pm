package Koha::Plugin::Fr::UnivRennes2::RTA;

use utf8;
use Modern::Perl;
use base qw(Koha::Plugins::Base);

use Mojo::JSON qw(decode_json encode_json);
use C4::Auth;
use Date::Calc qw(Date_to_Days);
use C4::Output;
use C4::Context;
use C4::Koha; #GetItemTypes
use Koha::AuthorisedValue;
use Koha::AuthorisedValues;
use Koha::AuthorisedValueCategory;
use Koha::AuthorisedValueCategories;
use Koha::Biblios;
use Koha::Database;
use Koha::DateUtils;
use Koha::Items;

## Here we set our plugin version
our $VERSION = '0.1';

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'RTA (Real Time Availability) API',
    author          => 'Julien Sicot',
    date_authored   => '2020-11-18',
    date_updated    => '2020-11-18',
    minimum_version => '18.110000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'Provides real-time availability statuses for Koha Items',
};

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;
    my $self = $class->SUPER::new($args);
    return $self;
}

sub install {
    my ( $self, $args ) = @_;
}

sub uninstall() {
    my ( $self, $args ) = @_;

}

sub api_routes {
    my ( $self, $args ) = @_;
    
    my $spec_str = $self->mbf_read('API/openapi.json');
    my $spec     = decode_json($spec_str);
    
    return $spec;
}

sub api_namespace {
    my ( $self ) = @_;
    
    return 'rta';
}

1;
