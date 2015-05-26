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
#    ./start.pl <PRODUCT_FILE_NAME> <LISTING_FILE_NAME> <OUTPUT_FILENAME> 
# --------------------------------------------

usage();

my $REMOVE_DUPS = 1; # remove duplicates in input files? 1 for yes, 0 for no
my ($product_file, $listing_file, $outputfile ) = @ARGV;

my $REMOVE_DUPS = 0; # set to 1 if you want script to detect and remove duplicate lines in the input files.

my $productsref = load_products($ARGV[0]);
my $pricesref = load_prices($ARGV[1]);

my @price_product_map = (); # Example $price_product_map[3] = [ 25, 88 ]; # means price listing #25 and #88 belong to product list line # 3.
# The '3' is line # 3 in product file, 25 and 88 are line numbers in listings file.

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

foreach my $product (0..$#{$productsref})
{
	my $price_list_ref = $price_product_map[$product];
	
	if($price_list_ref)
	{
		# if we have one or more price listings for this product...
		$jason_perl_object = { "product_name" => $productsref->[$product][1], "listings" => $price_list_ref };
		print O $outputjason->encode($jason_perl_object)."\n";
	}	
}

close(O);
exit(0);

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

        # Given this price listing (current one given by $list_entry), let's attempt to locate this
        # in the product list
	$found = 0;

        foreach my $product_index (0..$#{$productsref})
        {    
            # 'MANUFACTURER' == [0] 
            # 'PRODUCT_NAME' == [1] 
            # 'MODEL'     == [2]
            # 'FAMILY'      == [3] 
          
	    # requirements specified false negatives were much more prefered than false positives,
            # thus, we'll demand that all 3 match -- manufacturer, model and family.
		
	    # compare - case insenstive - manufacturer
	    # 6888 found when case IN-sensitve match on manufacturer
 	    # when same match was done with case sensitive, matching dropped to 5789.

	    if($price_entry_manufacturer !~ m/^$productsref->[$product_index][0]$/i)
            {
                # manufacturer doesn't match, avoid false positives, try next product list
                next;
            }

	    # below - the ^|\s - means must be delimited by start of string or space
	    # $|\s - means delimited by either end of string or space	

	    # [2] = MODEL                    
	    # compare - case insenstive - model

            if($price_entry_title !~ m/(^|\s)$productsref->[$product_index][2]($|\s)/i)
            {
                # no, the current price list item's title does not contain the model mentioned
                # the currently looked at product    
                next;
            }         
                
	    # [3] = FAMILY
	    # compare - case insenstive - family

            if($price_entry_title !~ m/(^|\s)$productsref->[$product_index][3]($|\s)/i)
            {  
                # no, it doesn't, move on
                next;
            }
       	 
            # found match 

	    push @{$price_product_map[$product_index]}, $pricesref->[$listing_index];

	    # 'last out' of loop - we found a match between this price list line and products file, no need to keep looking,
            # since we limit the number of matches a price list entry can have to 1 product only.
	    $num_found++;
	    last;
        }

	if(!$found)
	{
		#print "not found: $price_entry_manufacturer / $price_entry_title\n";
	}
    }

    print 'found '.$num_found."\n";
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
        $line = normalize($line);        
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
    my @product_specs = ();
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

        push @product_specs,
                    [ 
                        normalize($obj->{'manufacturer'}),
                        normalize($obj->{'product_name'}),
                        normalize($obj->{'model'}),
                        normalize($obj->{'family'})
                    ];        	
    }

    close(F);
    return \@product_specs;    
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

        $line =~ tr/-/ /;
        $line =~ tr/_/ /;

        # let's trim useless leading and trailing spaces...

        $line =~ s/^\s*(.+?)\s*$/$1/;

        return $line;
}
