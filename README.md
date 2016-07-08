# Pod::To::BigPage

Render many Pod6 files into one big file and build a TOC.

It's ment as a tool to check many POD files in a more or less convenient way. It's fast before correct -- use at your own risk.

# SYNOPSIS

Let it find the `*.pod` for you and have a thread per file.

    THREADS=2 perl6 -I ./lib pod2onepage.p6 -v --source-path=../../perl6-doc/ --exclude=404.pod6,/.git,/precompiled > tmp/html.html

