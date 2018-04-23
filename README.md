# Pod::To::BigPage
[![Build Status](https://travis-ci.org/perl6/perl6-pod-to-bigpage.svg?branch=master)](https://travis-ci.org/perl6/perl6-pod-to-bigpage)

Render many Pod6 files into one big file and build a TOC and index. The
provided CSS does support printing, as far as printing HTML goes.

## Install

Install it the usual way

    zef install --deps-only .
    
And test it 

    zef test
    

## SYNOPSIS

Let us find the `*.pod6` for you and run using two threads at a time.

    pod2onepage -v --threads=2 --source-path=../../perl6-doc/doc \
        --exclude=404.pod6,/.git,/precompiled > tmp/html.xhtml

You can use, for instance,

    perl6 -Ilib bin/pod2onepage -v --source-path=. --html >  tmp/pod2onepage.html
    
to generate a single page in HTML from [`README.pod6`](README.pod6)
included here. 
    
## Options

* `-v --verbose`

  verbose output

* `--source-path`

  Where to look for files ending in `.pod6`.

* `--exclude`

  Comma separated list of strings the processed files or paths shall not end with.

* `--no-cache`

  Don't use precompilation to cache `pod6` files.

* `--threads`

  Number of threads to use. Defaults to environment variable `THREADS` or 1.

* `--precomp-path`

  Sets the path where precompiled `pod6` files are created. Defaults to environment
  variable `TEMP`, `TMP` or `/tmp`.

* `--html`

  Generate HTML instead of the default XHTML
  
  
## Testing

To enable network tests to be run, set `ONLINE_TESTING` environment variable to a true value.
