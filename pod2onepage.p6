use v6;

use Base64;

PROCESS::<$SCHEDULER> = ThreadPoolScheduler.new(initial_threads => 0, max_threads => 2);
my $source-dir = '../../doc/doc/';
my $cache-dir = 'tmp/';

sub MAIN () {
	put await do start { .&parse-pod-file } for sort find-pod-files $source-dir;
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

#	my $cache-path = $cache-dir ~ encode-base64($f, :str);
#	my $cache-io = $cache-path.IO;

	# if $cache-io.f && $cache-io.modified >= $io.modified {
	# 	put "cached $f as $cache-path";
	# 	return EVAL $cache-io.slurp;
	# }else{
		put "processing $f"; # as $cache-path";
		my $pod = (EVAL ($io.slurp ~ "\n\$=pod"));
	#	$cache-io.spurt($pod.perl);
		return $pod;
	# }
}
