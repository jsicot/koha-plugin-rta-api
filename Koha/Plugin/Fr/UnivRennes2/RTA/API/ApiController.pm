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
use C4::Biblio;
use C4::CourseReserves qw(GetItemCourseReservesInfo);
use C4::Acquisition qw(GetOrdersByBiblionumber);
use C4::Serials;    #uses getsubscriptionfrom biblionumber
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
    
    my $marcflavour      = C4::Context->preference("marcflavour");

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
		    
		    my $record = $biblio->metadata->record;

		    if( $record->field('099')->subfield('t') eq 'REVUE' ) {
			
				#coping with subscriptions
				my $subscriptionsnumber = CountSubscriptionFromBiblionumber($biblionumber);
				my @subscriptions       = SearchSubscriptions({ biblionumber => $biblionumber, orderby => 'title' });
				
				@subscriptions = map { _sub_to_api( $_ ) } @subscriptions;
				
				
			    # Serial Collection
				my @sc_fields = $record->field(955);
				my @sup_fields = $record->field(956);
				my @idx_fields = $record->field(957);
				my @lac_fields = $record->field(959);
				my @lc_fields = $marcflavour eq 'UNIMARC'
				    ? $record->field(930)
				    : $record->field(852);
				my @serialcollections = ();
				
				foreach my $sc_field (@sc_fields) {
				    my %row_data;
				
				    $row_data{text}    = $sc_field->subfield('r');
 				    my $rcr  = substr($sc_field->subfield('5'), 0, 9);
 				     my $branchcode = $rcr
				      ? Koha::AuthorisedValues->find(
				        {
				            category         => 'RCR',
				            authorised_value => $rcr,
				        }
				      )->lib
				      : undef;
				    $row_data{branch}    =  Koha::Libraries->find( $branchcode )->branchname;
				    foreach my $idx_field (@idx_fields) {
				        $row_data{index} = $idx_field->subfield('r')
				            if ($sc_field->subfield('5') eq $idx_field->subfield('5'));
				    }
				    foreach my $sup_field (@sup_fields) {
				        $row_data{supplement} = $sup_field->subfield('r')
				            if ($sc_field->subfield('5') eq $sup_field->subfield('5'));
				    }
				    foreach my $lac_field (@lac_fields) {
				        $row_data{lacunes} = $lac_field->subfield('r')
				            if ($sc_field->subfield('5') eq $lac_field->subfield('5'));
				    }
				    foreach my $lc_field (@lc_fields) {
				        $row_data{itemcallnumber} = $marcflavour eq 'UNIMARC'
				            ? $lc_field->subfield('a') # 930$a
				            : $lc_field->subfield('h') # 852$h
				            if ($sc_field->subfield('5') eq $lc_field->subfield('5'));
				         $row_data{location} = $lc_field->subfield('c')
				         	 if ($sc_field->subfield('5') eq $lc_field->subfield('5'));
				    }
				
				    if ($row_data{branch}) { 
				        push (@serialcollections, \%row_data);
				    }
				}
				
# 				if (scalar(@serialcollections) > 0) {
				my $serials = _serial_to_api(\@serialcollections,\@subscriptions);
				return $c->render( status => 200, openapi =>  $serials );
   
			} else {
				
				my @items = Koha::Items->search($criterias);
			    
			    
			    @items = map { _item_to_api( $_ ) } @items;
			    
			    unless (@items) {
				    
					# Get acquisition details
				    my @orders = Koha::Acquisition::Orders->search(
				        { biblionumber => $biblionumber },
				        {
				            join => 'basketno',
				            order_by => 'basketno.booksellerid'
				        }
				    );    # GetHistory sorted by aqbooksellerid, but does it make sense?
					   @orders = map { _order_to_api( $_ ) } @orders;
			    	   return $c->render( status => 200, openapi =>  \@orders );
				}
				
				return $c->render( status => 200, openapi =>  \@items );
				
			}

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
    
    my $branch = Koha::Libraries->find( $item->homebranch );
    my $branchrank = $branch->branchnotes;
    
    my $item_obj = {
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
    
    if ( C4::Context->preference('UseCourseReserves') ) {
        $item_obj->{'course_reserves'}  = GetItemCourseReservesInfo( itemnumber => $item->itemnumber );
    }
    
    
    return $item_obj;
}

sub _order_to_api {
    my ($order) = @_;

    my $status = 'ordered' if ($order->datereceived eq "");
    my $item_obj = {
        "status" => $status,
        "order_date" => Koha::Template::Plugin::KohaDates->filter($order->entrydate),
		"order_status" => $order->orderstatus,
		"order_quantity" => $order->quantity,
		"order_quantityreceived" => $order->quantityreceived
    };
    
    return $item_obj;
}

sub _sub_to_api {
    my ($subscription) = @_;
    
    my $serials_to_display = $subscription->{opacdisplaycount};
	$serials_to_display = C4::Context->preference('OPACSerialIssueDisplayCount') unless $serials_to_display;
	
    my $item_obj = {
        "subscriptionid" => $subscription->{subscriptionid},
		"subscriptionnotes" => $subscription->{internalnotes},
		"missinglist" => $subscription->{missinglist},
		"librariannote" => $subscription->{librariannote},
		"branchcode" => $subscription->{branchcode},
		"hasalert" => $subscription->{hasalert},
		"callnumber" => $subscription->{callnumber},
		"location" => Koha::AuthorisedValues->find_by_koha_field( { kohafield => 'items.location', authorised_value => $subscription->{location} } )->lib,
		"closed" => $subscription->{closed},
		"staffdisplaycount" => $serials_to_display,
    };
    
    $item_obj->{'latestserials'}  = GetLatestSerials( $subscription->{subscriptionid}, $serials_to_display );

    
    return $item_obj;
}

sub _serial_to_api {
    
	my @serialcollections = @{$_[0]};
	my @subscriptions = @{$_[1]};
	
    my $status = 'is_serial';
	
    my $item_obj = {
        "status" => $status
    };
    
    $item_obj->{'serial_collections'}  = \@serialcollections;
     $item_obj->{'subscription'}  = \@subscriptions;

    
    return $item_obj;
}

1;