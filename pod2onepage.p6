use v6;

use Base64;
use Pod::To::BigPage;
use MONKEY-SEE-NO-EVAL;

PROCESS::<$SCHEDULER> = ThreadPoolScheduler.new(initial_threads => 0, max_threads => %*ENV<THREADS>.?Int // 2);

my &verbose = sub (|c) {};

my $source-dir;
my $cache-dir = './tmp/';

my @toc;

sub next-part-index () {
	state $lock = Lock.new;
	state $global-part-index = -1;
	my $clone;
	$lock.protect: {
		$clone = $global-part-index++;
	}
	$clone
}

sub MAIN (:v(:verbose($v)), :$source-path) {
	$source-dir = $source-path // './doc/';
	&verbose = &note if $v;
	setup();
	set-foreign-toc(@toc);
	put compose-before-content;
	put await do start { .&parse-pod-file(next-part-index) } for sort find-pod-files $source-dir;
	# put do { .&parse-pod-file(next-part-index) } for sort find-pod-files $source-dir;
	put compose-left-side-menu() ~ compose-after-content();
}

sub find-pod-files ($dir) {
	gather for dir($dir) {
		take .Str if .extension ~~ rx:i/pod$/;
		take slip sort find-pod-files $_ if .d;
	}
}

sub parse-pod-file ($f, $part-number) {
	my $io = $f.IO;

	# We have to deal with special chars in a files path (.. / case insensiblility on NTFS etc) to store it in a cache. Instead of fiddeling with those chars, we just turn the entire path into base64.

#	my $cached-path = $cache-dir ~ encode-base64($f, :str);
#	my $cached-io = $cached-path.IO;

#	if $cached-io.e && $cached-io.modified >= $io.modified {
#		verbose "cached $f as $cached-path";
#		return $cached-io.slurp;
#	}else{
		verbose "processing $f "; # as $cached-path";
		my $pod = (EVAL ($io.slurp ~ "\n\$=pod"));
		my $html = $pod>>.&handle(part-number => $part-number, toc-counter => TOC-Counter.new.set-part-number($part-number), part-config => {:head1(:numbered(True)),:head2(:numbered(True)),:head3(:numbered(True)),:head4(:numbered(True))});
#		$cached-io.spurt($html);
		return $html;
#	}
}
