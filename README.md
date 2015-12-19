# Pod::To::BigPage

Render many Pod6 files into one big file and build a TOC.

It's ment as a tool to check many POD files in a more or less convenient way. It's fast before correct -- use at your own risk.

# SYNOPSIS

Make one big pod file and have threads from a pool for each root node.

    find doc/ -iname '*.pod' | xargs -n 1 cat >> big-podfile.pod
    THREADS=4 perl6 --doc=BigPage -I ./lib/goes/here big-podfile.pod > your-html.html

Let it find the `*.pod` for you and have a thread per file.

	perl6 -I ./lib/goes/here pod2onepage.p6 -v --source-path=./doc/ > tmp/html.html

