package Koha::Plugin::Fr::UnivRennes2::RTA::API::ApiController;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use CGI;
use C4::Context;
use Koha::AuthorisedValues;
use Koha::Items;
use Koha::Library;
use Koha::Plugin::Fr::UnivRennes2::RTA;
use Koha::DateUtils;
use Koha::Template::Plugin::KohaDates;
use Mojo::Base 'Mojolicious::Controller';


=head1 Koha::Plugin::Fr::UnivRennes2::RTA::API::ApiController

A class implementing the controller methods for retrieving real-time statuses for koha items by biblionumber

=head2 Class Methods

=head3 get_items

=cut
sub get_items {
    my $c = shift->openapi->valid_input or return;
    
    my $rta = Koha::Plugin::Fr::UnivRennes2::RTA->new();
        
    my $biblionumber = $c->validation->param('biblionumber');
    my $biblio = Koha::Biblios->find($biblionumber);

    	if ( $biblionumber ) {

                $biblio = Koha::Biblios->find($biblionumber);
                    unless ($biblio) {
				        return $c->render( status => 404, openapi => { error => "Object not found." } );
				    }
				my $criterias = {
			        biblionumber => $biblionumber,
			    };
			    my @items = Koha::Items->search($criterias);
			    @items = map { _item_to_api( $_ ) } @items;
			    return $c->render( status => 200, openapi =>  \@items );
            
   		}
     
   
   }

sub _item_to_api {
    my ($item) = @_;

    my $checkout = Koha::Checkouts->find({ itemnumber => $item->itemnumber });
    my $waiting_holds = Koha::Holds->count({ itemnumber => $item->itemnumber, found => { in => [ "W", "T" ] } } );
    my $transfers = Koha::Item::Transfers->count({ itemnumber => $item->itemnumber, datearrived => undef });
    
    my $wrm =Koha::Plugin::Fr::UnivRennes2::WRM->new();;
    my $ondemand = $wrm->item_is_requestable( $item->itemnumber, $item->biblionumber );


    my $status = 'on_shelf';
    $status = 'in_transfer' if $transfers;
    $status = 'on_demand' if ($ondemand > 0);
    $status = 'waiting_hold' if $waiting_holds;
    $status = 'checked_out' if $checkout;
    
#     my $rank = $item->homebranch
#       ? Koha::AuthorisedValues->find(
#         {
#             category         => 'RANK',
#             authorised_value => $item->homebranch,
#         }
#       )
#       : undef;
#     my $branchrank = $rank->unblessed if $rank;
    
    my $branch = Koha::Libraries->find( $item->homebranch );
    my $branchrank = $branch->branchnotes;
    
    

    my $obj = {
	    "itemnumber" => $item->itemnumber,
	    "itemlost" => $item->damaged,
	    "withdrawn" => $item->withdrawn,
	    "damaged" => $item->damaged,
	    "homebranch" => $item->home_branch->branchname,
	    "branchcode" => $item->homebranch,
        "holdingbranch" => $item->holding_branch->branchname,
        "location" => Koha::AuthorisedValues->find_by_koha_field( { kohafield => 'items.location', authorised_value => $item->location } )->lib,
        "itemtype" => Koha::ItemTypes->find( $item->effective_itemtype )->description,
        "itemcallnumber" => $item->itemcallnumber,
        "barcode" => $item->barcode,
        "onloan" => Koha::Template::Plugin::KohaDates->filter($item->onloan),
        "status" => $status,
        "itemnotes" => $item->itemnotes,
        "copynumber" => $item->copynumber,
        "branchrank" => $branchrank
    };
    
    return $obj;
}

1;