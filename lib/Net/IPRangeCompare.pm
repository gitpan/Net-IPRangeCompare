
package Net::IPRangeCompare;

=head1 Net::IPRangeCompare

Net::IPRangeCompare - Perl module IP Range Comparison

=head1 SYNOPSIS

	use Net::IPRangeCompare;
	my $obj=Net::IPRangeCompare::Simple->new;

	$obj->add_range('Tom','10.0.0.2 - 10.0.0.11');
	$obj->add_range('Tom','10.0.0.32 - 10.0.0.66');
	$obj->add_range('Tom','11/32');

	$obj->add_range('Sally','10.0.0.7 - 10.0.0.12');
	$obj->add_range('Sally','172.16/255.255.255');

	$obj->add_range('Harry','192.168.2');
	$obj->add_range('Harry','10.0.0.128/30');

	$obj->compare_ranges; # optional

        while(my ($common,%row)=$obj->get_row) {
                print "\nCommon Range: ",$common,"\n";
                my $tom=$row{Tom};
                my $sally=$row{Sally};
                my $harry=$row{Harry};
                print "Tom: ",$tom
                        ,' '
                        ,($tom->missing ? 'not used' : 'in use')
                        ,"\n";

                print "Sally: ",$sally
                        ,' '
                        , ($sally->missing ? 'not used' : 'in use')
                        ,"\n";

                print "Harry: ",$harry,
                        ' '
                        ,($harry->missing ? 'not used' : 'in use')
                        ,"\n";
        }


	Output: 

	Common Range: 10.0.0.2 - 10.0.0.6
	Tom: 10.0.0.2 - 10.0.0.11 in use
	Sally: 10.0.0.2 - 10.0.0.6 not used
	Harry: 10.0.0.2 - 10.0.0.127 not used

	Common Range: 10.0.0.7 - 10.0.0.11
	Tom: 10.0.0.2 - 10.0.0.11 in use
	Sally: 10.0.0.7 - 10.0.0.12 in use
	Harry: 10.0.0.2 - 10.0.0.127 not used

	Common Range: 10.0.0.12 - 10.0.0.12
	Tom: 10.0.0.12 - 10.0.0.31 not used
	Sally: 10.0.0.7 - 10.0.0.12 in use
	Harry: 10.0.0.2 - 10.0.0.127 not used

	Common Range: 10.0.0.32 - 10.0.0.66
	Tom: 10.0.0.32 - 10.0.0.66 in use
	Sally: 10.0.0.13 - 172.15.255.255 not used
	Harry: 10.0.0.2 - 10.0.0.127 not used

	Common Range: 10.0.0.128 - 10.0.0.131
	Tom: 10.0.0.67 - 10.255.255.255 not used
	Sally: 10.0.0.13 - 172.15.255.255 not used
	Harry: 10.0.0.128 - 10.0.0.131 in use

	Common Range: 11.0.0.0 - 11.0.0.0
	Tom: 11.0.0.0 - 11.0.0.0 in use
	Sally: 10.0.0.13 - 172.15.255.255 not used
	Harry: 10.0.0.132 - 192.168.1.255 not used

	Common Range: 172.16.0.0 - 172.16.0.255
	Tom: 11.0.0.1 - 192.168.2.0 not used
	Sally: 172.16.0.0 - 172.16.0.255 in use
	Harry: 10.0.0.132 - 192.168.1.255 not used

	Common Range: 172.16.1.0 - 192.168.1.255
	Tom: 11.0.0.1 - 192.168.2.0 not used
	Sally: 172.16.1.0 - 192.168.2.0 not used
	Harry: 10.0.0.132 - 192.168.1.255 not used

	Common Range: 192.168.2.0 - 192.168.2.0
	Tom: 11.0.0.1 - 192.168.2.0 not used
	Sally: 172.16.1.0 - 192.168.2.0 not used
	Harry: 192.168.2.0 - 192.168.2.0 in use

=head1 DESCRIPTION

Fast Scalable ip range aggregation and summary tool kit.

Although similar in functionality to Net::Netmask and NetAddr::IP, Net::IPRangeCompare is a completely range driven ip management and evaluation tool, allowing more flexibility and scalability when dealing with the some what organic nature of IP-Ranges.

If you have a large number of ipv4 ranges and need to inventory lists of ranges for overlaps, this is the Module for you!

=cut


#use strict; # Commented out for release
#use warnings; # commented out for release
use Scalar::Util qw(blessed);
use vars qw($package_name $error $VERSION @ISA @EXPORT_OK);
require Exporter;
@ISA=qw(Exporter);

@EXPORT_OK=qw(
	hostmask
	cidr_to_int
	get_common_range
	sort_largest_first_int_first
	sort_smallest_last_int_first
	range_start_end_fill
	sort_ranges 
	sort_largest_last_int_first 
	sort_smallest_first_int_first
	get_overlapping_range
	consolidate_ranges
	fill_missing_ranges
	ip_to_int
	int_to_ip
	range_compare
	);

=head2 Export list

The following functions are optionally exported by Net::IPRangeCompare.

	hostmask
        ip_to_int
        int_to_ip
        cidr_to_int

        get_common_range
        get_overlapping_range

        sort_ranges
        sort_largest_first_int_first
        sort_smallest_last_int_first
        sort_largest_last_int_first
        sort_smallest_first_int_first

        consolidate_ranges
        fill_missing_ranges
        range_start_end_fill
        range_compare
=cut


use Scalar::Util qw(looks_like_number);
use overload
        '""' => \&notation
	,'fallback' => 1;

$VERSION=.003;
use constant key_start_ip =>0;
use constant key_end_ip =>1;
use constant key_generated=>2;
use constant key_missing=>3;
use constant key_data=>4;
use constant ALL_BITS=>0xffffffff;

$package_name=sub { (caller())[0] }->();


=head2 OO Methods

This section defines the OO interfaces.

=over 4

=item * my $obj=Net::IPRangeCompare->parse_new_range('10/32');

Creates a new Net::IPRangeCompare object.

	Examples:
	$obj=$package_name->parse_new_range('10');
	$obj=$package_name->parse_new_range('10.0.0.0 - 10.0.0.0');
	$obj=$package_name->parse_new_range('10/32');
	$obj=$package_name->parse_new_range('10/255.255.255');
	$obj=$package_name->parse_new_range('10.0.0.0','10.0.0.0');

	All of the above will parse the same range: 
		10.0.0.0 - 10.0.0.0
	Notes:
		When using a list syntax: start and end range are
		assumed.  Using a 2 arguments will not work as 
		expected when the list consists of ip and cidr.
	Example:
		$obj=$package_name->parse_new_range('10.0.0.0',32);
		Returns: 10.0.0.0 - 32.0.0.0

		$obj=$package_name->parse_new_range(
			'10.0.0.0'
			,'255.255.255.255
		);
		Returns: 10.0.0.0 - 32.0.0.0

		If you wish to create an object from cidr boundaries
		Pass the argument as a single string.
	Example:
		$obj=$package_name->parse_new_range(
			'10.0.0.0'.'/'.32
		);
		Returns: 10.0.0.0 - 10.0.0.0
	Example: 
		$obj=$package_name->parse_new_range(
			'10.0.0.0'
			.'/'
			.'255.255.255.255
		);
		Returns: 10.0.0.0 - 10.0.0.0

=cut

sub parse_new_range {
	my ($s,@sources)=@_;
	my $source;
	if($#sources==0) {
		$source=$sources[0];
	} else {
		my ($ip,$mask)=@sources;
		$source=join ' - ',$ip,$mask;
		return $s->new_from_range($source);
	}

	if(ref($source)) {
		# may be an existing oo object
		my $class=blessed($source);
		if($class) {
			return $source if $class eq $package_name;
			$source=join '',$source;
		} else {
			$error="reference passed for parsing";
			return undef;
		}
	}
	return $s->new_from_cidr($source) if $source=~ /\//;
	return $s->new_from_range($source) if $source=~ /-/;
	return $s->new_from_ip($source);

}

=item * my $obj=Net::IPRangeCompare->new(0,1);

Creates a new Net::IPRangeCompare object from 2 integers.  See: Net::IPRangeCompare->parse_new_range for a more useful OO constructor.

=cut

sub new($$) {
	my ($package,$key_start_ip,$key_end_ip)=@_;

	unless(defined($key_start_ip) and defined($key_end_ip)) {
		$error="Start and End Ip need to be defined";
		return undef;
	}
	unless(
		looks_like_number($key_start_ip) 
		and 
		looks_like_number($key_end_ip)
		) {
		
		$error="First or last ip do not look like numbers";
		return undef;
	}
	if($key_start_ip>$key_end_ip) {
		$error="Start ip needs to be less than or equal to End Ip";
		return undef;
	}
	bless [$key_start_ip,$key_end_ip],$package;
}

##########################################################
#
# OO Stubs

=item * my $int=$obj->first_int;

Returns the integer that represents the start of the ip range

=cut

sub first_int () { $_[0]->[key_start_ip] }

=item * my $int=$obj->last_int;

Returns the integer that represents the end of the ip range

=cut

sub last_int () { $_[0]->[key_end_ip] }

=item * my $first_ip=$obj->first_ip;

Returns the first ip in the range.

=cut

sub first_ip () { int_to_ip($_[0]->[key_start_ip]) }

=item * my $last_ip=$obj->last_ip;

Returns the last ip in the range;

=cut

sub last_ip () { int_to_ip($_[0]->[key_end_ip]) }

=item * if($obj->missing) { .. do something } else { .. do something else }

If the value is true, this range is a filler representing an ip range that
was not found.

=cut

sub missing () {$_[0]->[key_missing] }

=item * if($obj->generated) { .. do something } else { .. do something else }

If the value is true, this range was created internally by one of the following functions: fill_missing_ranges, range_start_end_fill, consolidate_ranges.  

When a range is $obj->generated but not $obj->missing it represents a collection of overlapping ranges.

=cut

sub generated () {$_[0]->[key_generated] }

=item * my $last_error=$obj->error;

Returns the last error

=cut

sub error () { $error }

##########################################################
#

=item * my $total_ips=$obj->size;

Returns the total number of ipv4 addresses in this range.

=cut

sub size () {
	my ($s)=@_;
	return 1+$s->last_int - $s->first_int;
}

##########################################################
#

=item * $obj->data->{some_tag}=$some_data; # sets the data

=item * my $some_data=$obj->data->{some_tag}; # gets the data

Returns an anonymous hash that can be used to tag this block with your data.  

=cut

sub data () {
	my ($s)=@_;

	# always return the data ref if it exists
	return $s->[key_data] if ref($s->[key_data]);

	$s->[key_data]={};

	$s->[key_data]
}

##########################################################
#

=item * my $notation=$obj->notation;

Returns the ip range in the standard "x.x.x.x - x.x.x.x" notation.

Simply calling the Net::IPRangeCompare object in a string context will return the same output as using the $obj->notation Method.
Example:

	my $obj=Net::IPRangeCompare->parse_new_range('10.0.0.1/255');
	print $obj,"\n";
	print $obj->notation,"\n";

	Output:

	10.0.0.0 - 10.255.255.255
	10.0.0.0 - 10.255.255.255

=cut

sub notation () {
	my ($s)=@_;

	join ' - '
		,int_to_ip($s->first_int)
		,int_to_ip($s->last_int)
}

############################################
#

=item * my $cidr_notation=$obj->get_cidr_notation;

Returns string representing all the cidrs in a given range.

	Example a:

		$obj=Net::IPRangeCompare->parse_new_range('10/32');
		print $obj->get_cidr_notation,"\n"

		Output:
		10.0.0.0/32


	Example b:
		$obj=Net::IPRangeCompare->parse_new_range(
			'10.0.0.0 10.0.0.4'
		);
		print $obj->get_cidr_notation,"\n"

		Output:
		10.0.0.0/30, 10.0.0.4/32

=cut

sub get_cidr_notation () {
	my ($s)=@_;
	my $n=$s;
	my $return_ref=[];
	my ($range,$cidr);
	while($n) {
		($range,$cidr,$n)=$n->get_first_cidr;
		push @$return_ref,$cidr;
	}
	join(', ',@$return_ref);

}

##########################################################
#

=item * if($obj->overlap('10/32') { }

Returns true if the 2 ranges overlap.  Strings are auto converted to Net::IPRangeCompare Objects on the fly.

=cut

sub overlap ($) {
	my ($range_a,$range_b)=@_;
	$range_b=$package_name->parse_new_range($range_b);

	# return true if range_b's start range is contained by range_a
	return 1 if 
			$range_a->first_int <=$range_b->first_int 
				&&
			$range_a->last_int >=$range_b->first_int;

	# return true if range_b's end range is contained by range_a
	return 1 if 
			$range_a->first_int <=$range_b->last_int 
				&&
			$range_a->last_int >=$range_b->last_int;

	return 1 if 
			$range_b->first_int <=$range_a->first_int 
				&&
			$range_b->last_int >=$range_a->first_int;

	# return true if range_b's end range is contained by range_a
	return 1 if 
			$range_b->first_int <=$range_a->last_int 
				&&
			$range_b->last_int >=$range_a->last_int;

	# return undef by default
	undef
}

=item * my $int=$obj->next_first_int;

Fetches the starting integer for the next range;

=cut

sub next_first_int () { $_[0]->last_int + 1 }

=item * my $int=$obj->previous_last_int;

Fetches the end of the previous range

=cut

sub previous_last_int () { $_[0]->first_int -1 }

=item * my ($range,$cidr_nota,$next)=$obj->get_first_cidr;

Iterator function:

	Returns the following
	$range
		First range on a cidr boundary in $obj
	$cidr_ntoa
		String containing the cidr format
	$next
		Next Range to process, undef when complete
	Example:

		my $obj=Net::IPRangeCompare->parse_new_range(
			'10.0.0.0 10.0.0.4'
		);
		my ($first,$cidr_note,$next)=$obj->get_first_cidr;
	Example:
		# this gets every range
		my $obj=Net::IPRangeCompare->parse_new_range(
			'10.0.0.0 10.0.0.4'
		);
		my ($first,$cidr,$next);
		$next=$obj;
		while($next) {
			($first,$cidr,$next)=$obj->get_first_cidr;
			print "Range Notation: ",$first,"\n";
			print "Cidr Notation : ",$cidr,"\n";
		}
		Output:
		Range Notation: 10.0.0.0 - 10.0.0.3
		Cidr Notation : 10.0.0.0/30
		Range Notation: 10.0.0.4 - 10.0.0.4
		Cidr Notation : 10.0.0.4/32

=cut

sub get_first_cidr () {
	my ($s)=@_;
	my $first_cidr;
	my $output_cidr;
	for(my $cidr=32;$cidr>-1;--$cidr) {
		my $mask=ALL_BITS & (ALL_BITS << $cidr);
		$mask=0 if $cidr==32;

		my $hostmask=hostmask($mask);
		my $size=$hostmask +1;

		next if $s->first_int % $size;


		my $last_int=$s->first_int + $hostmask;
		next if $last_int>$s->last_int;

		$output_cidr=32 - $cidr;
		$first_cidr=$package_name->new(
			$s->first_int
			,$last_int
		);

		last;
	}
	my $cidr_string=join(
		'/'
		,int_to_ip($first_cidr->first_int)
		,$output_cidr
	);

	if($first_cidr->last_int==$s->last_int) {
		return ( $first_cidr ,$cidr_string);
	} else {
		return ( 
			$first_cidr 
			,$cidr_string
			,$package_name->new(
				$first_cidr->next_first_int
				,$s->last_int
			)
		);
	}

}

###########################################
#

=item * my $sub=$obj->enumerate(1-32);
=item * my $sub=$obj->enumerate;

Returns an anonymous subroutine that can be used to iterate through the entire range.  The iterator can be used to safely walk any range even 0/0.  Each iteration of $sub returns a new Net::IPRangeCompare object or undef on completion.

The default cidr to iterate by is "32".


Example:

	my $obj=Net::IPRangeCompare->parse_new_range('10/30');
	while(my $range=$sub->()) {
		print $range,"\n"
	}
	Output:
	10.0.0.0
	10.0.0.1
	10.0.0.2
	10.0.0.3

=cut

sub enumerate {
	my ($s,$cidr)=@_;
	$cidr=32 unless $cidr;
	my $mask=cidr_to_int($cidr);
	my $hostmask=hostmask($mask);
	my $n=$s;
	sub {
		return undef unless $n;
		my $cidr_end=($n->first_int & $mask) + $hostmask;
		my $return_ref;
		if($cidr_end >=$n->last_int) {
			$return_ref=$n;
			$n=undef;
		} else {
			$return_ref=$package_name->new(
				$n->first_int
				,$cidr_end
			);
			$n=$package_name->new(
				$return_ref->next_first_int
				,$n->last_int
			);
		}
		$return_ref;
	}
}

###########################################
#

=pod

=back


=head2 Helper functions

=over 4

=item * my $integer=ip_to_int('0.0.0.0');

Converts an ipv4 address to an integer usable by perl

=cut

sub ip_to_int ($) { unpack('N',pack('C4',split(/\./,$_[0]))) }

###########################################
#

=item * my $ipv4=int_to_ip(11);

Converts integers to ipv4 notation

=cut

sub int_to_ip ($) { join '.',unpack('C4',(pack('N',$_[0]))) }

###########################################
#

=item * my $obj=get_overlapping_range([$range_a,$range_b,$range_c]);

Given a list reference of Net::IPRangeCompare objects: returns a range that will overlap with all the ranges in the list.  

=cut

sub get_overlapping_range ($) {
	my ($ranges)=@_;
	my ($first_int)=sort sort_smallest_first_int_first @$ranges;
	my ($last_int)=sort sort_largest_last_int_first @$ranges;
	my $obj=$package_name->new($first_int->first_int,$last_int->last_int);
	$obj->[key_generated]=1;
	$obj;
}

###########################################
#

=item * my $hostmask=hostmask($netmask);

Given a netmask( as an integer) returns the corrisponding hostmask

=cut

sub hostmask ($) {
	my ($mask)=@_;
	(~(ALL_BITS & $mask))
}

###########################################
#

=item * my $netmask=cidr_to_int(32);

Given a cidr(0 - 32) return the netmask as an integer.

=cut

sub cidr_to_int ($) {
	my ($cidr)=@_;
	my $shift=32 -$cidr;
	return undef if $cidr>32 or $cidr<0;
	return 0 if $shift==32;
	ALL_BITS & (ALL_BITS << $shift)
}

############################################
#

=item * my $obj=get_common_range([$range_a,$range_b]);

Returns the shared overlapping range give a list reference of Net::IPRangeCompare
objects:  Returns undef if no overlapping range is found.

=cut

sub get_common_range ($) {
	my ($ranges)=@_;
	my ($first_int)=sort sort_largest_first_int_first @$ranges;
	my ($last_int)=sort sort_smallest_last_int_first @$ranges;
	$package_name->new(
		$first_int->first_int
		,$last_int->last_int
	);
}

=pod

=back

=cut

###########################################
#
# Sort mechanism for all internal code.

=head2 Sort Functions

	sort_largest_last_int_first
		Sorts by $obj->last_int in descending order

	sort_smallest_first_int_first
		Sorts by $obj->first_int in ascending order

	sort_smallest_last_int_first
		Sorts by $obj->last_int in ascending order

	sort_largest_first_int_first
		Sorts by $obj->first_int in descending order

	sort_ranges
		Sorts by 
			$obj->first_int in ascending order
			or
			$obj->last_int in descending order
	Example: 
		my @list=sort 
			sort_largest_last_int_first 
			@netiprangecomapre_objects;

=cut


sub sort_ranges ($$) {
	my ($range_a,$range_b)=@_;

	# smallest start
	$range_a->first_int <=> $range_b->first_int
	||
	# largest end
	$range_b->last_int <=> $range_a->last_int

}

sub sort_largest_last_int_first ($$) {
	my ($range_a,$range_b)=@_;
	$range_b->last_int <=> $range_a->last_int

}

sub sort_smallest_first_int_first ($$) {
	my ($range_a,$range_b)=@_;
	$range_a->first_int <=> $range_b->first_int
}

sub sort_smallest_last_int_first ($$) {
	my ($range_a,$range_b)=@_;
	$range_a->last_int <=> $range_b->last_int
}

sub sort_largest_first_int_first ($$) {
	my ($range_a,$range_b)=@_;
	$range_b->first_int <=> $range_a->first_int
}

############################################
#
sub new_from_ip ($) {
	my ($s,$ip)=@_;
	unless(defined($ip)) {
		$error='ip not defined';
		return undef;
	}
	$s->new(
		ip_to_int($ip)
		,ip_to_int($ip)
	);
}

############################################
#
sub new_from_range ($) {
	my ($s,$range)=@_;
	unless(defined($range)) {
		$error='range not defined';
		return undef;
	}

	# lop off start and end spaces
	$range=~ s/(^\s+|\s+$)//g;

	unless($range=~ /
			^\d{1,3}(\.\d{1,3}){0,3}
			\s*-\s*
			\d{1,3}(\.\d{1,3}){0,3}$
		/x) {
		$error="not a valid range notation format";
		return undef;
	}
	my ($start,$end)=split /\s*-\s*/,$range;
	$s->new(
		ip_to_int($start)
		,ip_to_int($end)
	);
	
}

sub new_from_cidr ($) {
	my ($s,$notation)=@_;
	$notation=~ s/(^\s+|\s+$)//g;
	unless($notation=~ /
			^\d{1,3}(\.\d{1,3}){0,3}
			\s*\/\s*
			\d{1,3}(\.\d{1,3}){0,3}$
		/x) {
		$error="not a valid cidr notation format";
		return undef;
	}

	my ($ip,$mask)=split /\s*\/\s*/,$notation;
	my $ip_int=ip_to_int($ip);
	my $mask_int;

	if($mask=~ /\./) {
		# we know its quad notation
		$mask_int=ip_to_int($mask);
	} elsif($mask>=0 && $mask<=32) {
		$mask_int=cidr_to_int($mask);
	} else {
		$mask_int=ip_to_int($mask);
	}
	my $first_int=$ip_int & $mask_int;
	my $last_int= $first_int + (~ (ALL_BITS & $mask_int));


	$s->new($first_int,$last_int);


}

###########################################
#

=head2 Net::IPRangeCompare list processing functions

This section covers how to use the List and list of list processing functions that do the actual comparison work.

=over 4

=cut

###########################################
#

=item * my $list_ref=consolidate_ranges(\@list_of_netiprangeobjects);

Given a list reference of Net::IPRangeCompare Objects: Returns consolidated list reference to the input ranges.  The list input reference is depleted during the consolidation process.  If you want to keep the original list of ranges, make a copy of the list before passing it to consolidate_ranges.

Example:

	my $list=[];
	push @$list,Net::IPRangeCompare->parse_new_range('10/32');
	push @$list,Net::IPRangeCompare->parse_new_range('10/32');
	push @$list,Net::IPRangeCompare->parse_new_range('10/30');
	push @$list,Net::IPRangeCompare->parse_new_range('10/24');
	push @$list,Net::IPRangeCompare->parse_new_range('8/24');

	my $list=consolidate_ranges($list);

	while(my $range=shift @$list) {
		print $range,"\n";
	}

	OUTPUT
	8.0.0.0 - 8.0.0.255
	10.0.0.0 - 10.0.0.255

=cut

sub consolidate_ranges ($) {
	my ($ranges)=@_;
	@$ranges=sort sort_ranges @$ranges;
	my $cmp=shift @$ranges;
	my $return_ref=[];
	while( my $next=shift @$ranges) {
		if($cmp->overlap($next)) {
			my $overlap=get_overlapping_range([$cmp,$next]);
			$cmp=$overlap;

		} else {
			push @$return_ref,$cmp;
			$cmp=$next;
		}
	
	}
	push @$return_ref,$cmp;

	$return_ref;
}

###########################################
#
# my $ranges=fill_missing_ranges([$range_a,$range_b,$range_c]);

=item * my $ranges=fill_missing_ranges(\@consolidated_list);

Given a consolidated list of Net::IPRangeCompare objects, it returns a contiguous list of ranges.  All ranges generated by the fill_missing_ranges are $obj->missing==true and $obj->generated==true.

Example:

	my $list=[];
	push @$list,Net::IPRangeCompare->parse_new_range('10/32');
	push @$list,Net::IPRangeCompare->parse_new_range('10/32');
	push @$list,Net::IPRangeCompare->parse_new_range('10/30');
	push @$list,Net::IPRangeCompare->parse_new_range('10/24');
	push @$list,Net::IPRangeCompare->parse_new_range('8/24');

	my $list=consolidate_ranges($list);
	$list=fill_missing_ranges($list);

	while(my $range=shift @$list) {
		print $range,"\n";
	}

	OUTPUT
	8.0.0.0 - 8.0.0.255
	8.0.1.0 - 9.255.255.255
	10.0.0.0 - 10.0.0.255

Notes:

	This function expects a consolidated list for input.  If you 
	get strange results, make sure you consolidate your input 
	list first.

=cut

sub fill_missing_ranges ($) {
	my ($ranges)=@_;
	
	# first we have to consolidate the ranges
	$ranges=consolidate_ranges($ranges);
	my $return_ref=[];

	my $cmp=shift @$ranges;
	while(my $next=shift @$ranges) {
		push @$return_ref,$cmp;
		unless($cmp->next_first_int==$next->first_int) {
			my $missing=$package_name->new(
				$cmp->next_first_int
				,$next->previous_last_int);
			$missing->[key_missing]=1;
			push @$return_ref,$missing;
		}
		$cmp=$next;
	}

	push @$return_ref,$cmp;

	$return_ref;
}

############################################
#

=item * my $list=range_start_end_fill([$list_a,$list_b]);

Given a list of lists of Net::IPRangeCompare objects returns a list of list objects with the same start and end ranges.

Example:

	my $list_a=[];
	my $list_b=[];

	push @$list_a,Net::IPRangeCompare->parse_new_range('10/24');
	push @$list_a,Net::IPRangeCompare->parse_new_range('10/25');
	push @$list_a,Net::IPRangeCompare->parse_new_range('11/24');

	push @$list_b,Net::IPRangeCompare->parse_new_range('7/24');
	push @$list_b,Net::IPRangeCompare->parse_new_range('8/24');

	#to prevent strange results always consolidate first
	$list_a=consolidate_ranges($list_a);
	$list_b=consolidate_ranges($list_b);

	my $list_of_lists=range_start_end_fill([$list_a,$list_b]);
	while(my $row=shift @$list_of_lists) {
		my ($col_a,$col_b)=@$row;
		print $col_a,"\t",$col_b,"\n";
	}

	Output:
	7.0.0.0 - 7.0.0.255	7.0.0.0	- 9.255.255.255
	8.0.0.0 - 8.0.0.255	10.0.0.0 - 10.0.0.255
	8.0.1.0 - 11.0.0.255	11.0.0.0 - 11.0.0.255

Notes:

	To prevent strange results make sure each list is 
	consolidated first.

=cut

sub range_start_end_fill ($) {
	my ($ranges)=@_;
	my ($first_int)=sort sort_smallest_first_int_first
		map { $_->[0] } @$ranges;
	$first_int=$first_int->first_int;
	my ($last_int)=sort sort_largest_last_int_first
		map { $_->[$#{$_}] } @$ranges;
	$last_int=$last_int->last_int;
	
	foreach my $ref (@$ranges) {
		my $first_range=$ref->[0];
		my $last_range=$ref->[$#{$ref}];

		if($first_range->first_int!=$first_int) {
			my $new_range=$package_name->new(
					$first_int
					,$first_range->previous_last_int
			);
			unshift @$ref,$new_range;
			$new_range->[key_missing]=1;
			$new_range->[key_generated]=1;
		}

		if($last_range->last_int!=$last_int) {
			my $new_range=$package_name->new(
				$last_range->next_first_int
				,$last_int
			);
			push @$ref,$new_range;
			$new_range->[key_missing]=1;
			$new_range->[key_generated]=1;
		}
	}


	$ranges;
}

############################################
#

=item * my $sub=range_compare([$list_a,$list_b,$list_c]);

Compares a list of lists of Net::IPRangeCompare objects

Example:

	my $list_a=[];
	my $list_b=[];
	my $list_c=[];

	push @$list_a, Net::IPRangeCompare->parse_new_range(
		'10.0.0.0 - 10.0.0.1'
		);
	push @$list_a, Net::IPRangeCompare->parse_new_range(
		'10.0.0.2 - 10.0.0.5'
		);


	push @$list_b, Net::IPRangeCompare->parse_new_range(
		'10.0.0.0 - 10.0.0.1'
		);
	push @$list_b, Net::IPRangeCompare->parse_new_range(
		'10.0.0.3 - 10.0.0.4'
		);
	push @$list_b, Net::IPRangeCompare->parse_new_range(
		'10.0.0.4 - 10.0.0.5'
		);

	push @$list_c, Net::IPRangeCompare->parse_new_range(
		'10.0.0.0 - 10.0.0.1'
		);
	push @$list_c, Net::IPRangeCompare->parse_new_range(
		'10.0.0.3 - 10.0.0.3'
		);
	push @$list_c, Net::IPRangeCompare->parse_new_range(
		'10.0.0.4 - 10.0.0.5'
		);

	my $sub=range_compare([	$list_a,$list_b,$list_c] );

	while(my ($common,$range_a,$range_b,$range_c)=$sub->()) {
		print "\nCommon Range: ",$common,"\n";
		print 'a: ',$range_a
			,' '
			,($range_a->missing ? 'not used' : 'in use')
			,"\n";
		print 'b: ',$range_b
			,' '
			,($range_b->missing ? 'not used' : 'in use')
			,"\n";
		print 'c: ',$range_c
			,' '
			,($range_c->missing ? 'not used' : 'in use')
			,"\n";
	}

	Output:

	Common Range: 10.0.0.0 - 10.0.0.1
	a: 10.0.0.0 - 10.0.0.1 in use
	b: 10.0.0.0 - 10.0.0.1 in use
	c: 10.0.0.0 - 10.0.0.1 in use

	Common Range: 10.0.0.2 - 10.0.0.2
	a: 10.0.0.2 - 10.0.0.5 in use
	b: 10.0.0.2 - 10.0.0.2 not used
	c: 10.0.0.2 - 10.0.0.2 not used

	Common Range: 10.0.0.3 - 10.0.0.3
	a: 10.0.0.2 - 10.0.0.5 in use
	b: 10.0.0.3 - 10.0.0.5 in use
	c: 10.0.0.3 - 10.0.0.3 in use

	Common Range: 10.0.0.4 - 10.0.0.5
	a: 10.0.0.2 - 10.0.0.5 in use
	b: 10.0.0.3 - 10.0.0.5 in use
	c: 10.0.0.4 - 10.0.0.5 in use

=cut

sub range_compare ($) {
	my ($list_of_ranges)=@_;
	{
		my $ref=[];
		while(my $ranges=shift @$list_of_ranges) {
			$ranges=consolidate_ranges($ranges);
			$ranges=fill_missing_ranges($ranges);
			push @$ref,$ranges;
		}
		$list_of_ranges=$ref;
	}
	$list_of_ranges=range_start_end_fill($list_of_ranges);
	#print((map { join(', ',@$_),"\n" } @$list_of_ranges),"\n");
	my @columns;
	my $active_cols=0;
	my $column_count=0;
	my $missing_count=0;
	foreach my $column (@$list_of_ranges) {
		push @columns,shift @$column;
		++$active_cols if $#{$column}!=-1;
		++$column_count;
		++$missing_count if $columns[$#columns]->missing;
	}
	
	my $row_id=0;
	# oo iterator
	sub {
		# handler for single set
		return (get_common_range(\@columns),@columns)
			if $row_id++==0 and $active_cols==0;

		return () if $active_cols==0;
		my @return_row=(get_common_range(\@columns),@columns);


		while(1) {
			$missing_count=0;
			my ($smallest_last_int)=sort 
				sort_smallest_last_int_first 
				@columns;
			$smallest_last_int=$smallest_last_int->last_int;


			$active_cols=0;
			for(my $id=0;$id<=$#{$list_of_ranges};++$id) {
				my $cmp=$columns[$id];

				if($#{$list_of_ranges->[$id]}!=-1) {
					++$active_cols 
				} else {
					next
				}

				$columns[$id]=shift @{$list_of_ranges->[$id]}
				 	if $cmp->last_int==$smallest_last_int;

				++$missing_count if $columns[$id]->missing;
			}
			# stop if not all rows are missing
			last if $missing_count!=$column_count;

			# stop if we have no data to walk
			last if $active_cols==0;
		}
		
		@return_row;
	}
}

=pod

=back

=cut

############################################
#
# End of the package
1;

############################################
#
# Helper package
package Net::IPRangeCompare::Simple;

=head1 Net::IPRangeCompare::Simple

Helper Class that wraps the features of Net::IPRangeCompare into a single easy to use OO instance.

=over 4

=cut

use strict;
use warnings;
use Carp;

use constant key_sources=>0;
use constant key_columns=>1;
use constant key_compare=>2;

############################################
#

=item * my $obj=Net::IPRangeCompare::Simple->new;

Creates new instance of Net::IPRangeCompare::Simple->new;

=cut

sub new () {
	my ($class)=@_;
	my $ref=[];
	$ref->[key_sources]={};
	$ref->[key_columns]=[];
	$ref->[key_compare]=undef;

	bless $ref,$class;
}


############################################
#

=item * $obj->add_range(key,range);

Adds a new "range" to the "key". The command will croak if the key is undef or the range cannot be parsed.

Example:

	$obj->add_range('Tom','10.0.0.2 - 10.0.0.11');

=cut

sub add_range ($$) {
	my ($s,$key,$range)=@_;
	croak "Key is not defined" unless defined($key);
	croak "Range is not defined" unless defined($range);

	my $obj=Net::IPRangeCompare->parse_new_range($range);
	croak "Could not parse: $range" unless $obj;

	my $list;

	if(exists $s->[key_sources]->{$key}) {
		$list=$s->[key_sources]->{$key};
	} else {
		$s->[key_sources]->{$key}=[];
		$list=$s->[key_sources]->{$key};
	}
	push @$list,$obj;
	$obj
}

############################################
#

=item * $obj->get_ranges_by_key(key);

Given a key, return the list reference.  Returns undef if the key does not exist. Carp::croak is called if the key is undef.

=cut

sub get_ranges_by_key ($) {
	my ($s,$key)=@_;
	croak "key was not defined" unless defined($key);

	return $s->[key_sources]->{$key}
		if exists $s->[key_sources]->{$key};
	
	return undef;
}

############################################
#

=item * $obj->compare_ranges;
=item * $obj->compare_ranges(key,key,key);

Used to initialize or re-initialize the compare process. When called a key or a list of keys: The compare process excludes those columns.

Example:

	Given ranges from: Tom, Sally, Harry, Bob

	$obj->compare_ranges(qw(Bob Sally));

	The resulting %row from $obj->get_row would only contain keys for
	Tom and Harry.

Notes:
	If %row would be empty during $obj->get_row function call will 
	croak.

=cut

sub compare_ranges {
	my ($s,@keys)=@_;
	my %exclude=map { ($_,1) } @keys;
	croak "no ranges defined" unless keys %{$s->[key_sources]};
	
	my $columns=$s->[key_columns];
	@$columns=();
	my $compare_ref=[];
	while(my ($key,$ranges)=each %{$s->[key_sources]}) {
		next if exists $exclude{$key};
		push @$columns,$key;
		push @$compare_ref,[@$ranges];

	}
	croak "no ranges defined" if $#$columns==-1;

	$s->[key_compare]=Net::IPRangeCompare::range_compare($compare_ref);

	1
}


############################################
#

=item * while(my ($common,%row)=$obj->get_row) { do something }

Returns the current row of the compare process.

	$common
		Represents the common range between all of the
		source ranges in the current row.

	%row
		Represents the consolidated range from the 
		relative source "key".

Notes:

	This function will croak if no ranges have been
	added to the Net::IPRangeCompare::Simple object.

=cut

sub get_row () {
	my ($s)=@_;

	croak "no ranges defined" unless keys %{$s->[key_sources]};

	#make sure we have something to compare
	$s->compare_ranges
		unless  $s->[key_compare];
	my %row;
	my (@cols)=$s->[key_compare]->();
	return () unless @cols;
	my $common;

	($common,@row{@{$s->[key_columns]}})=@cols;

	$common,%row

}

############################################
#

=item * my @keys=$s->get_keys;

Returns the list of keys in this instance.

=cut

sub get_keys () {
	keys %{$_[0]->[key_sources]}
}

############################################
#
# End of the package
1;

__END__

=pod

=back

=head1 AUTHOR

Michael Shipper 

=head1 COPYRIGHT

Copyright 2010 Michael Shipper.  All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

Net::Netmask, NetAddr::IP, Carp

=cut


