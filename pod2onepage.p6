use v6;

use Base64;
use Pod::To::BigPage;

PROCESS::<$SCHEDULER> = ThreadPoolScheduler.new(initial_threads => 0, max_threads => %*ENV<THREADS>.?Int // 2);

my &verbose := &note;

my $source-dir = '../../doc/doc/';
my $cache-dir = 'tmp/';

sub MAIN () {
	setup();
	put compose-before-content;
	put await do start { .&parse-pod-file } for sort find-pod-files $source-dir;
	put compose-toc() ~ compose-after-content;
}

sub find-pod-files ($dir) {
	gather for dir($dir) {
		take .Str if .extension ~~ rx:i/pod$/;
		take slip find-pod-files $_ if .d;
	}
}

sub parse-pod-file ($f) {
	my $io = $f.IO;

	# We have to deal with special chars in a files path (.. / case insensiblility on NTFS etc) to store it in a cache. Instead of fiddeling with those chars, we just turn the entire path into base64.

	my $cached-path = $cache-dir ~ encode-base64($f, :str);
	my $cached-io = $cached-path.IO;

	if $cached-io.e && $cached-io.modified >= $io.modified {
		verbose "cached $f as $cached-path";
		return $cached-io.slurp;
	}else{
		verbose "processing $f as $cached-path";
		my $pod = (EVAL ($io.slurp ~ "\n\$=pod"));
		my $html = $pod>>.&handle();
		$cached-io.spurt($html);
		return $html;
	}
}
