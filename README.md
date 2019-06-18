
## Quote2Fortune

File under #stupidperltricks #imissmysunworkstation and #getoffmyunixlawn

./quote2fortune.pl 
    Create fortune cookies from GoodReads author quotes

Usage: ./quote2fortune.pl [ -f FILENAME ] [ -h ] [ -r NUMBER ] [ -t CODEPAGE ] [ -u URL ]

    -f   Fortune file name

    -h   This help

    -r   (Re)start at a given page number

    -t   Also create a non-UTF-8 version. Use iconv to transliterate
         UTF-8 to a different code page (eg: ISO-8859-1)

    -u   The GoodReads URL for the authors quotes
         Example: https://www.goodreads.com/author/quotes/1654.Terry_Pratchett
         Example: https://www.goodreads.com/author/quotes/1244.Mark_Twain

         Google search: https://www.google.com/search?&q=goodreads+frank+herbert+quotes

In an attempt to be a reasonable net citizen there is a 2 second delay between each
page pulled. 

## Quote2Fortune uses
* ~WYLD STALLYNS!~ ... I mean, uh, perl
* w3m or lynx (SSL support required)
* strfile
* GNU iconv (non-GNU will function but results will be .. poor)

## Sample output:

```bash
~$ ./quote2fortune.pl -f tolkien -t ascii -u https://www.goodreads.com/author/quotes/656983.J_R_R_Tolkien

Checking the total number of pages of quotes for: J R R Tolkien
Found 103 pages of quotes. 
Downloading page 11 of 103

(some time later)

Finished downloading and parsing; writing to the file: tolkien
Creating fortune dat file

"tolkien.dat" created
There were 3138 strings
Longest string: 3575 bytes
Shortest string: 28 bytes

Fortune dat file creation succeeded. You can test the fortune cookie like this:
~$ fortune tolkien

Rewriting UTF-8 fortune file to ascii
The transliterated file is: tolkien.ascii
Creating fortune dat file

"tolkien.ascii.dat" created
There were 3138 strings
Longest string: 3569 bytes
Shortest string: 22 bytes

Fortune dat file creation succeeded. You can test the fortune cookie like this:
~$ fortune tolkien.ascii
```

## Sample fortune

```
~$ fortune tolkien
“Elves seldom give unguarded advice, for advice is a dangerous gift, even from
the wise to the wise, and all courses may run ill.”
   ― J.R.R. Tolkien, The Fellowship of the Ring
```

## A note on transliteration

While it is likely that a great number of users have moved to using a UTF-8 locale (xx_XX.UTF-8) I realise 
that some may still use C, ISO-8859-XX, etc. Most of the fortunes on GoodReads are in English or European languages 
that transliterate from UTF-8 without issue. However, when a quote cannot be transliterated (example: UTF-8 Arabic 
-> ASCII) it will simply be skipped. Due to the nature of transliteration one should expect the best results to be
found using by the UTF-8 version of the data.

