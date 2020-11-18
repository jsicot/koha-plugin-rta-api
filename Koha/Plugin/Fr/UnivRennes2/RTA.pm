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

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    
    my $template = $self->get_template({ file => 'templates/configure.tt' });
    if ( $cgi->param('save') ) {
        my $myconf;
        $myconf->{rta_branches} = join(",", $cgi->multi_param('rta_branches'));
        $myconf->{rta_locations} = join(",", $cgi->multi_param('rta_locations'));
        $myconf->{rta_itemtypes} = join(",", $cgi->multi_param('rta_itemtypes'));
        $myconf->{rta_notforloan} = join(",", $cgi->multi_param('rta_notforloan'));
        if ( $myconf ) {
            $self->store_data($myconf);
            $template->param( 'config_success' => 'La configuration du plugin a été enregistrée avec succès !' );
        }
    }

    my @rta_branches;
    if (my $wlib = $self->retrieve_data('rta_branches')) {
        @rta_branches = split(',', $wlib);
    }
    my $branches = Koha::Libraries->search( {}, { order_by => ['branchname'] } )->unblessed;

    my @rta_locations;
    if (my $wloc = $self->retrieve_data('rta_locations')) {
        @rta_locations = split(',', $wloc);
    }
    my $locations = { map { ( $_->{authorised_value} => $_->{lib} ) } Koha::AuthorisedValues->get_descriptions_by_koha_field( { frameworkcode => '', kohafield => 'items.location' }, { order_by => ['description'] } ) };
    my @locations;
	foreach (sort keys %$locations) {
		push @locations, { code => $_, description => "$_ - " . $locations->{$_} };
	}

	my @rta_itemtypes;
    if (my $wit = $self->retrieve_data('rta_itemtypes')) {
        @rta_itemtypes = split(',', $wit);
    }
	my $itemtypes = Koha::ItemTypes->search_with_localization;
    my %itemtypes = map { $_->{itemtype} => $_ } @{ $itemtypes->unblessed };

    my @rta_notforloan;
    if (my $wnfl = $self->retrieve_data('rta_notforloan')) {
        @rta_notforloan = split(',', $wnfl);
    }
    my $notforloan= { map { ( $_->{authorised_value} => $_->{lib} ) } Koha::AuthorisedValues->get_descriptions_by_koha_field( { frameworkcode => '', kohafield => 'items.notforloan' }, { order_by => ['description'] } ) };
    my @notforloan ;
	foreach (sort keys %$notforloan ) {
		push @notforloan , { code => $_, description => $notforloan->{$_} };
	}

    $template->param(
        'rta_branches' => \@rta_branches,
        'branches' => $branches,
        'rta_locations' => \@rta_locations,
        'locations' => \@locations,
        'rta_itemtypes' => \@rta_itemtypes,
        'itemtypes' => $itemtypes,
        'rta_notforloan' => \@rta_notforloan,
        'notforloan' => \@notforloan
    );
    $self->output_html( $template->output() );
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
