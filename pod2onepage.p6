use v6;

use Pod::To::BigPage;
use MONKEY-SEE-NO-EVAL;

my &verbose = sub (|c) {};

my $source-dir;
my $cache-dir = './tmp/';
my Bool $disable-cache;

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

sub MAIN (Bool :v(:verbose($v)), Str :$source-path, Str :$exclude, :$no-cache = False, :$threads = %*ENV<THREADS>.?Int // 2) {
    @exclude = $exclude.split: ',';
    $source-dir = $source-path // './doc/';
    &verbose = &note if $v;
    $disable-cache = $no-cache;
    
    PROCESS::<$SCHEDULER> = ThreadPoolScheduler.new(initial_threads => 0, max_threads => $threads);
    
    setup();
    set-foreign-toc(@toc);
    put compose-before-content;
    # put await do start { .&parse-pod-file(next-part-index, .substr($source-path.chars) ) } for sort find-pod-files $source-dir;
    put do { .&parse-pod-file(next-part-index, .substr($source-path.chars) ) } for sort find-pod-files $source-dir;
    put compose-left-side-menu() ~ compose-after-content();
}

sub find-pod-files ($dir) {
    state $none-exclude = @exclude.none;
    gather for dir($dir) {
        take .Str if .Str.ends-with($none-exclude) && .extension ~~ rx:i/pod6$/;
        take slip sort find-pod-files $_ if .d && .Str.ends-with($none-exclude);
    }
}

my $precomp-store = CompUnit::PrecompilationStore::File.new(prefix => ((%*ENV<TEMP> // '/tmp') ~ '/PodToBigfile-precomp').IO );
my $precomp = CompUnit::PrecompilationRepository::Default.new(store => $precomp-store);

sub parse-pod-file ($f, $part-number, $pod-name is copy) {
    my $io = $f.IO;

    my $pod; 

    if $disable-cache {
        $pod = (EVAL ($io.slurp ~ "\n\$=pod"));
        verbose "processed $f";
    }else{
        use nqp;
        my $id = nqp::sha1(~$f);
        my $handle = $precomp.load($id, :since($io.modified))[0];

        my $cached = "(cached)";

        without $handle {
            $precomp.precompile($io, $id, :force);
            $handle = $precomp.load($id)[0] // fail("Could not precompile $f");
            $cached = "";
        }
    
        verbose "processed $f $cached";
        $pod = nqp::atkey($handle.unit,'$=pod')[0];
    }   
    
    $pod-name = $pod-name.subst('/Language/', '/language/').subst('/Type/', '/type/');
    my $html = $pod>>.&handle(:$pod-name, part-number => $part-number, toc-counter => TOC-Counter.new.set-part-number($part-number), part-config => {:head1(:numbered(True)),:head2(:numbered(True)),:head3(:numbered(True)),:head4(:numbered(True))});
    return Q:c[<!-- {$pod-name} --><div class="pod-body"><a id="{$pod-name.subst('/', '_', :g)}"></a>{$html}</div>];
}
