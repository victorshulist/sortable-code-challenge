#!/usr/bin/perl
use strict;
use JSON;

# --------------------------------------------
#
# Script for 'http://sortable.com/challenge/'
# Victor Shulist
# 6910 Viola St, North Gower (GTA)
# K0A 2T0
# 613-489-1354
# vtshulist@gmail.com
# victor.shulist@icloud.com 
#
# Install :
#   1. install CPAN
#   2. use cpan to install JSON parser
#   3. chmod 500 ./start.pl
#   4. run with 
#      ./sortable-code-challenge.pl <PRODUCT_FILE_NAME> <LISTING_FILE_NAME> <OUTPUT_FILENAME> 
# --------------------------------------------

usage();

my $REMOVE_DUPS = 1; # remove duplicates in input files? 1 for yes, 0 for no
my ($product_file, $listing_file, $outputfile ) = @ARGV;

my $REMOVE_DUPS = 0; # set to 1 if you want script to detect and remove duplicate lines in the input files.

my $productsref = load_products($ARGV[0]);
my $pricesref = load_prices($ARGV[1]);

my %price_product_map = (); 

if($#{$pricesref} == 0 ) 
{
    exit(0);
}

process(0, $#{$pricesref});

if(!open(O, ">$outputfile"))
{
	print "\n\n** ERR: unable to open output file '$outputfile'\n";
	exit(1);
}

my $outputjason = JSON->new();
my $jason_perl_object;

foreach my $product (keys %price_product_map)
{
	my $outputjsonstring = '';

	if(@{$price_product_map{$product}})
	{
		$outputjsonstring = '{"product_name":"'.esc_quote($product).'","listings":[';
		
		foreach my $pricelisting (@{$price_product_map{$product}})
		{
			$outputjsonstring .= '{"title":"'.esc_quote($pricelisting->{'title'}).'","manufacturer":"'.esc_quote($pricelisting->{'manufacturer'}).'","currency":"'.esc_quote($pricelisting->{'currency'}).'","price":"'.esc_quote($pricelisting->{'price'}).'"},';
		}

		chop($outputjsonstring);
		$outputjsonstring .= ']}';
	}
	print O $outputjsonstring."\n";
}

close(O);
exit(0);

sub esc_quote
{
	my ($in ) = @_;
	my $out = $in;
	$out =~ s!"!\\\"!g;
	return $out;
}

sub process
{
    my ($firstindex, $lastindex) = @_;
    my $json = JSON->new();
    my $num_found = 0; # number of price list lines found in products file.
    my $found = 0;

    foreach my $listing_index ($firstindex..$lastindex)
    {
        my $price_entry_manufacturer = $pricesref->[$listing_index]->{'manufacturer'};
        my $price_entry_title = $pricesref->[$listing_index]->{'title'};

	# instead of dealing with spaces sometimes, dashes sometimes, and hypens, just confirm to spaces before compare...
	# that's what the "normalized_" variables do.

	my $normalized_price_entry_title = normalize($price_entry_title);

        # Given this price listing (current one given by $list_entry), let's attempt to locate this
        # in the product list
	$found = 0;
      
	my $product_ref_obj = $productsref->{normalize($price_entry_manufacturer)};
    
	foreach my $price_list_item_ref (@{$product_ref_obj})
	{ 
        	# PRODUCT_NAME [0] 
        	# MODEL        [1]
        	# FAMILY       [2] 

		my $product_name = $price_list_item_ref->[0];
		my $product_model = $price_list_item_ref->[1];
		my $product_family = $price_list_item_ref->[2];

		my $normalized_product_model = normalize($product_model);
		my $normalized_product_family = normalize($product_family);

		# case-insensitive model match...

                if($normalized_price_entry_title !~ m/(^|\s)$normalized_product_model($|\s)/i)
                {
                	# no, the current price list item's title does not contain the model mentioned
                	# the currently looked at product
                	next;
            	}

                # compare - case insenstive - family

                if($normalized_price_entry_title !~ m/(^|\s)$normalized_product_family($|\s)/i)
                {
                	# no, it doesn't, move on
                	next;
                }
	
	       push @{$price_product_map{$product_name}}, $pricesref->[$listing_index];

               # 'last out' of loop - we found a match between this price list line and products file, no need to keep looking,
               # since we limit the number of matches a price list entry can have to 1 product only.

               last;
         } 
     }
}

sub load_prices
{
    my ($file ) = @_;
    my $json = JSON->new();
    my %dups = (); # used to remove duplicate lines

    my @prices = ();

    if(!open(F, "<$file"))
    {
                print "\n\n**ERR: can't load '$file'\n";
                exit(1);
    }

    my $line = '';
    my @lines = <F>;
    close(F);

    my $numlines = @lines;

    foreach $line (@lines)
    {  
        next if($line =~ m/^\s*$/); # ignore compleletly blank lines

	if($REMOVE_DUPS)
	{
		if($dups{$line})
		{
			next; # already saw this line, ignore
		}
		else
		{
			$dups{$line} = 1; # record that we saw this line, so we ignore if encounter again.
		}
	}

        my $obj = decode_json($line);
        push @prices, $obj;        
    }

    close(F);
    return \@prices;
}

sub load_products
{
    my ($file ) = @_;

    my %dups = (); # for duplication removal
    my %product_specs = ();
    my $json = JSON->new();
    
    # From filename passed in, load the JSON object string

    if(!open(F, "<$file"))
    {
        print "\n\n**ERR: can't load '$file'\n";
        exit(1);
    }

    my $line = '';
    
    while($line = <F>)
    {
        # for each line of file, create a JSON object, add to list '@list'
        chomp($line); # remove trailing new line

        next if($line =~ m/^\s*$/); # ignore compleletly blank lines

	if($REMOVE_DUPS)
	{
		if($dups{$line})
		{
			# already saw identical line, skip
			next;
		}
		else
		{
	 		$dups{$line} = 1;
		}
	}

        my $obj = decode_json($line);

        push @{$product_specs{normalize($obj->{'manufacturer'})}},
                    [ 
                        $obj->{'product_name'},
                        $obj->{'model'},
                        $obj->{'family'},
                    ];        	
    }

    close(F);
    return \%product_specs;    
}

sub usage
{
    # if user doesn't provide all required command line arguments, tell them how to use the script...

    if(!(@ARGV[2]))
    {
        print "Usage: $0 <PRODUCT_FILE_NAME> <LISTING_FILE_NAME> <OUTPUT_FILENAME>\n";
        exit(1);
    }
}

sub normalize
{
        my ($inline ) = @_;
        my $line = $inline;

        # sometimes we have spaces, other times we have dashes (-), other times we have (_),
        # to make matching eaiser, let's go with only spaces -- convert all dashes, underscores to
        # spaces

	# testing did confirm this function adds more matches.

        $line =~ tr/-/ /;
        $line =~ tr/_/ /;

        # let's trim useless leading and trailing spaces...

	$line =~ s/\s{2,}/ /g;
        $line =~ s/^\s*(.+?)\s*$/$1/;

        return $line;
}


