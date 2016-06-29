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

my @exclude;

sub MAIN (Bool :v(:verbose($v)), Str :$source-path, Str :$exclude) {
	@exclude = $exclude.split: ',';
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
		take .Str if .Str.ends-with(none @exclude) && .extension ~~ rx:i/pod$/;
		take slip sort find-pod-files $_ if .d;
	}
}

sub parse-pod-file ($f, $part-number) {
	my $io = $f.IO;

	my $pod; 
	{
		use nqp;
		my $precomp-store = CompUnit::PrecompilationStore::File.new(prefix => ((%*ENV<TEMP> // '/tmp') ~ '/PodToBigfile-precomp').IO );
		my $precomp = CompUnit::PrecompilationRepository::Default.new(store => $precomp-store);

		# $pod = (EVAL ($io.slurp ~ "\n\$=pod"));
		
		my $id = nqp::sha1($f);
		my $handle = $precomp.load($id,:since($f.IO.modified))[0];

		my $cached = "(cached)";

		if not $handle {
			$precomp.precompile($f.IO, $id);
			$handle = $precomp.load($id)[0];
			$cached = "";
		}
	
		verbose "processed $f $cached";
		$pod = nqp::atkey($handle.unit,'$=pod')[0];
	}	
	my $html = $pod>>.&handle(part-number => $part-number, toc-counter => TOC-Counter.new.set-part-number($part-number), part-config => {:head1(:numbered(True)),:head2(:numbered(True)),:head3(:numbered(True)),:head4(:numbered(True))});
	return $html;
}
