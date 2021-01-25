#!/usr/bin/env perl

# Parse author quotes from GoodReads to make fortune cookies. Yum!
#
# Requires: w3m or lynx, strfile, and a GoodReads URL
# Optional: GNU iconv for UTF-8 to alternate codepage transliteration
#

# TODO
# * other sites with quotes 
# * better text formatting (w3m/lynx hard wrap at 72)
# * some quotes appear mangled - source bad? parsing bad?

use strict; 
use warnings;
use Getopt::Std;
my $webcmd;
my $webargs;
my $iconvcmd;
my $iconvargs;
my $lynx;
my $strfilecmd;
my $grurl;
my $pagecount;
my @fortunes;
our %opts;

sub binarycheck($)
# check for helper binaries
{
   # either w3m or lynx
   $webcmd=`which w3m`;
   if ($webcmd) {
      chomp($webcmd);
      $webargs='-dump -M -s -T text/html ';
   } else { 
      $webcmd=`which lynx`; 
      if ($webcmd) {
         chomp($webcmd);
         $webargs='-dump -nonumbers -hiddenlinks=ignore -nomargins -cfg=/tmp/.lynxcfg ';
         $lynx=1;
      } else {
         print "Neither w3m nor lynx could be located.\n";
         print "One of these is required.\n";
         exit 1;
      }
   }
   # strfile for building the cookies
   $strfilecmd=`which strfile`;
   if ($strfilecmd) {
      chomp($strfilecmd);
   } else {
      print "strfile is needed to build the fortune cookie, but\n";
      print "it cannot be found.\n";
      exit 1;
   }
}

sub webcheck($)
# SSL support
{
   my $webssl;
   if ($lynx == 1) {
      $webssl=`$webcmd -version | grep OpenSSL`;
   } else {
      $webssl=`$webcmd -version | grep ssl`;
   }
   if (! $webssl) {
      print "$webcmd appears to lack SSL support. This will make extracting data\n";
      print "from the webpage(s) impossible. Please use w3m or lynx compiled with SSL\n";
      print "support.\n";
      exit 1;
   }
}

sub usage($)
{
   my $exit = shift;

   print <<END_OF_HELP;

$0 
    Create fortune cookies from GoodReads author quotes

Usage: $0 [ -f FILENAME ] [ -h ] [ -r NUMBER ] [ -t CODEPAGE ] [ -u URL ]

    -f   Fortune file name

    -h   This help

    -r   (Re)start at a given page number

    -t   Also create a non-UTF-8 version. Use iconv to transliterate 
         UTF-8 to a different code page (eg: ISO-8859-1) (YMMV!)

    -u   The GoodReads URL for the authors quotes
         Example: https://www.goodreads.com/author/quotes/1654.Terry_Pratchett
         Example: https://www.goodreads.com/author/quotes/1244.Mark_Twain

         Google search: https://www.google.com/search?&q=goodreads+frank+herbert+quotes

END_OF_HELP
   exit($exit);
}

sub parseHTML(@)
# Parse the HTML and output a text version of the fortune
{
   my $line;
   my $quotestart=0;
   my @formattedpage;

   foreach (@_) {
      $line = $_; 
      chomp($line);
      if ($line =~/^“/) {
         if ($quotestart == 0) {
            push(@formattedpage,'%'); 
            $quotestart = 1;
         }
      }
      if ($quotestart == 1) {
         push(@formattedpage,$line); 
      }
      if ($line =~/^―/) {
         $quotestart = 0;
      }
   }
   return @formattedpage;
}

sub lynxcfg($)
# lynx ignores the utf-8 arguments so lets create a temporary config file
{
   my $flag = shift; 
   my $filename='/tmp/.lynxcfg';
   if ($flag eq 'set') {
      print "Creating temporary lynx configuration file in $filename\n";
      open(my $fh, '>', $filename) or die "Fatal error: could not open file '$filename' $!";
      print $fh "CHARACTER_SET:utf-8\n";
      close $fh;
   } elsif ($flag eq 'remove') {
      print "Removing temporary lynx configuration file $filename\n";
      unlink $filename;
   }   
}

sub dumppage($)
# dump a webpage for parsing
{
   my $url = shift; 
   my @webpage=`$webcmd $webargs $url`;
   if (!@webpage) {
      print "Web page download failed; continuing.\n";
      return;
   }
   return @webpage;
}

sub writecookie($)
# write formatted text to the cookie file
{
   my $filename="$opts{f}";
   my $fh;
   print "\n";
   print "Finished downloading and parsing; writing to the file: $filename\n";
   # append mode for resume
   if ($opts{r}) {
      open($fh, '>>', $filename) or die "Fatal error: could not open file '$filename' $!";
   } else {
      open($fh, '>', $filename) or die "Fatal error: could not open file '$filename' $!";
   }
   foreach (@fortunes) {
      $_ =~ s/^―/   ―/;
      print $fh "$_\n";
   }
   close $fh;

   # write the transliterated version of the fortune file attempting to skip fortunes
   # that result in iconv errors
   if ($opts{t}) {
      my $filename="${opts{f}}.$opts{t}";
      my $fh;
      my $fortunestart;
      my $translitstring;
      my $transfail;
      my @translitfortune;
      open($fh, '>>', $filename) or die "Fatal error: could not open file '$filename' $!";
      foreach (@fortunes) {
         if($_ =~ /^%/) { 
            # a new fortune: reset failures, write out the one we have, then null the array
            $transfail = '';
            push(@translitfortune,"$_\n");
            next;
         }
         # push it through iconv and check return
         $translitstring = transliterate($_);
         if (!$translitstring) {
            $transfail = 'yes';
         }
         # if iconv failed skip pushing to array until a new fortune (%)
         if ($transfail eq 'yes') {
            @translitfortune=();
         } else {
            push(@translitfortune,$translitstring);
         }
         foreach (@translitfortune) {
            print $fh "$_";
         }
         @translitfortune=();
      }
      close $fh;
   }
}

sub transliterate($)
{
   my $iconverror;
   $_ =~ s/\"/##/g;
   $_ =~ s/\'/==/g;
   $_ =~ s/\`/__/g;
   my $string = `echo "$_" | $iconvcmd $iconvargs 2>&1`;
   $string =~ s/##/\"/g;
   $string =~ s/==/\'/g;
   $string =~ s/__/\'/g;
   if ($string =~ /.*cannot convert.*/) {
      print "iconv ran into an error with this string: $_\n";
      print "Skipping to the next fortune\n";
      $iconverror = 1;
   } 
   if (!$iconverror) {
      return $string;
   } 
}

sub strcookie($)
# create a strfile processed version
{
   print "Creating fortune dat file\n";
   print "\n";
   my $filename;
   my $version=shift;
   my $verified='no';
   if ($version eq 'base') {
      $filename="$opts{f}";
   } elsif ($version eq 'transliterate') {
      $filename="${opts{f}}.$opts{t}";
   } else {
      return
   }
   my @result=`$strfilecmd -c % $filename $filename.dat`;
   foreach (@result) {
      if ($_ =~ /created/) {
         $verified='yes';
      }
   }   
   if ($verified eq 'yes') {
      foreach (@result) {
         print "$_";
      }
      print "\n";
      print "Fortune dat file creation succeeded. You can test the fortune cookie like this:\n";
      print "\~\$ fortune $filename\n";
      print "\n";
   } else {
      print "\n";
      print "Fortune dat file creation failed. Please try it manually with:\n";
      print "$strfilecmd -c % $filename ${filename}.dat\n";
      print "\n";
      exit 1; 
   }
}

getopts("f:hr:t:u:", \%opts);
usage(0) if ($opts{h} || !$opts{u} || !$opts{f} || !%opts);
if ($opts{t}) {
   $iconvcmd=`which iconv`; 
   if ($iconvcmd) {
      chomp($iconvcmd);
      $iconvargs=" -f UTF-8 -t ${opts{t}}//TRANSLIT ";
      chomp($iconvargs); 
      my $gnucheck=`$iconvcmd --help 2>&1 | grep gnu.org`;
      if ($gnucheck !~ /gnu.org/) {
         print "\n";
         print "Warning: GNU iconv not found; //TRANSLIT feature unavailable. Conversion from\n";
         print "UTF-8 to another code page will almost certainly produce unexpected results.\n";
         print "\n";
      }
   } else {
      print "iconv conversion requested but binary cannot be located.\n";
      exit 1;
   }
}

#helper binary check
binarycheck(0);

#url sanity check
$grurl = $opts{u};
if ($grurl !~/goodreads.com\/author\/quotes\/\d+\.\S+/) {
   print "\n";
   print "The specified URL: $grurl should match the help example.\n";
   print "\n";
   usage(0);
}
chomp($grurl);

# if we're using lynx create the config file
if ($lynx) {
   lynxcfg('set');
}

# start by getting the page count and guessing at the Author's name
my $authorname = $grurl;
$authorname =~ /(?:\d+.*)\.(.*)/;
$authorname = $1;
$authorname =~ tr/_/ /;

print "Checking the total number of pages of quotes for: $authorname\n";
my @temphtml = dumppage($grurl);

# parse the first page to find the total number of pages
foreach (@temphtml) {
   if ($_ =~ /next »/) {
      $pagecount=(split(' ',(split(' next', $_))[0]))[-1];
   }
}
if (!$pagecount || $pagecount !~ /^[0-9,.E]+$/) {
   print "Error getting the number of pages. Please check that the page content\n";
   print "resembles that of one of the example URLs.\n";
   usage(0);
}

print "Found $pagecount pages of quotes. \n";

# check to see if we are resuming
if ($opts{r}) {
   if ($opts{r} > $pagecount) {
      print "Cannot resume from a higher page number \($opts{r}\) than exists \($pagecount\)\n";
      exit 1;
   }
   print "Resuming from page $opts{r}\n";
}
   
# now push them all into an array 
my @tempfortunes = parseHTML(@temphtml);
foreach (@tempfortunes) {
   push(@fortunes,$_);
}

# We should start at page two unless resuming
my $currentpage;
if ($opts{r}) {
   $currentpage = $opts{r};
} else {
   $currentpage = 2;
}

# set manually to limit number of pages for debugging
# $pagecount = 3;

# pull the pages one at a time with a 2 second
# pause and push them directly into memory
while ($currentpage <= $pagecount) {
   my $pageurl=($grurl."?page=$currentpage");
   #print "Downloading page $currentpage\n";
   print "\rDownloading page $currentpage of $pagecount";
   my @temphtml = dumppage($pageurl);
   if (@temphtml) {
      my @tempfortunes = parseHTML(@temphtml);
      foreach (@tempfortunes) {
         push(@fortunes,$_);
      }
   }
   $currentpage++;
   sleep 2;
}

# write the array to a file and transliterate if requested
writecookie(0);

# strfile the fortune cookie for great justice
strcookie('base');

# strfile
if ($opts{t}) {
   strcookie('transliterate');
}

# remove lynx config file before exiting
if ($lynx) {
   lynxcfg('remove');
}
