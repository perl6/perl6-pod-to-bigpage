unit class Pod::To::BigPage;

PROCESS::<$SCHEDULER> = ThreadPoolScheduler.new(initial_threads => 0, max_threads => %*ENV<THREADS>.?Int // 2);

# my $*SCHEDULER =  ThreadPoolScheduler.new(initial_threads => 0, max_threads => %*ENV<THREADS>.?Int // 2);

our $html-header;
our $html-before-content;
our $html-after-content;

my @toc;
my %register;

constant NL = "\n";

class TOC-Counter is export { 
	has Int @!counters is default(0);
	method Str () { @!counters>>.Str.join: '.' }
	method inc ($level) { 
		@!counters[$level - 1]++;
		@!counters.splice($level);
#		dd @!counters;
		self
	}
	method set-part-number ($part-number) { 
		@!counters[0] = $part-number; 
		self 
	}
}

sub setup () is export {
	$html-header = q:to/EOH/;
		<title>Untitled</title>
		<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
		<style type="text/css">
			body { margin-left: 4em; margin-right: 4em; }
			div.pod-content { padding-left: 20em; }
			div.marginale { float: right; margin-right: -4em; width: 18em; font-size: 66%; text-align: left; }
			h1.title { font-size: 200%; }
			h1 { font-size: 160%; }
			h2 { font-size: 140%; }
			h3 { font-size: 120%; }
			h4 { font-size: 100%; }
			h5 { font-size: 100%; }
			h6 { font-size: 100%; }
			h7 { font-size: 100%; }
			pre { padding-left: 2em; }
			ul.toc { list-style-type: none; padding-left: 0; margin-left: 0 }
			ul.toc ul { list-style-type: none; }
			ul.toc ul { margin-left: 0; padding-left: 1em; }
			ul.toc li { margin-left: 0; padding-left: 0em; }
			ul.toc li.toc-level-1 { padding-left: 1em; }
			ul.toc li.toc-level-2 { padding-left: 1em; }
			ul.toc li.toc-level-3 { padding-left: 1em; }
			ul.toc li.toc-level-4 { padding-left: 1em; }
			ul.toc li.toc-level-5 { padding-left: 1em; }
			ul.toc li.toc-level-6 { padding-left: 1em; }
			ul.toc li.toc-level-7 { padding-left: 1em; }
			ul.toc li.toc-level-8 { padding-left: 1em; }
			ul.toc li.toc-level-9 { padding-left: 1em; }
			ul.toc li.toc-level-10{ padding-left: 1em; }
			#toc { width: 20em; margin-left: -22em; float: left; position: fixed; top: 0; overflow: scroll; height: 100%; padding: 0; white-space: nowrap; }
			.code { font-family: monospace; }
		</style>
		<link href="pod-to-bigpage.css" rel="stylesheet" type="text/css" />
		EOH
	$html-before-content = '';
	$html-after-content = '';
}

sub set-foreign-toc (\toc) is export {
	@toc := toc;
}

sub register-index-entry(*@a) {
	state $lock = Lock.new;
	state $global-index-counter;
	my $clone;
	$lock.protect: {
		$clone = ++$global-index-counter;
		%register{@a} = $clone xx *;
	}
	'r' ~ $clone
}

sub register-toc-entry($level, $text, $part-toc-counter, :$hide) {
	state $lock = Lock.new;
	my $clone;
	$lock.protect: {
		$part-toc-counter.inc($level+1);
		$clone = $part-toc-counter.Str;
		@toc.push: $clone => $text => $level unless $hide;
	}
	$clone
}

sub compose-toc (:$toc = @toc) is export {
	'<div id="toc"><ul class="toc">' ~ NL ~
	@toc\
		.sort({$_.key.subst(/(\d+)/, -> $/ { 0 ~ $0.chars.chr ~ $0 }, :g)})\
		.map({ Q:c (<a href="#t{$_.key}"><li class="toc-level toc-level-{$_.value.value}"><span class="toc-number">{$_.key}</span> {$_.value.key}</li></a>) }).join(NL) ~
	'</ul></div>'
}

sub compose-before-content () is export {
	'<?xml version="1.0" encoding="utf-8" ?>' ~
	'<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">' ~
	'<html xmlns="http://www.w3.org/1999/xhtml">' ~
	'<head>' ~
	('  ' xx *) Z $html-header.split("\n") ~
	'</head>' ~
	qq{<body>$html-before-content\n  <div class="pod-content">} 
}

sub compose-after-content () is export {
	qq{  </div>$html-after-content\n</body>} ~
	'</html>'
}

method render ($pod:) is export {
#	return '' if $++;
	setup();
	
	compose-before-content ~
	await do start { handle($_) } for $pod.flat ~
	compose-toc() ~ compose-after-content
}

my enum Context ( None => 0, Index => 1 , Heading => 2, HTML => 3, Raw => 4);

my proto sub handle ($node, Context $context = None, :$part-number?, :$toc-counter?, :%part-config?) is export {
	{*}
}

multi sub handle (Pod::Block::Code $node, :$part-number?, :$toc-counter?, :%part-config?) is export {
	my $additional-class = $node.config && $node.config<class> ?? ' ' ~ $node.config<class> !! '';
	Q:c (<pre class="code{$additional-class}">{$node.contents>>.&handle()}</pre>) ~ NL;
}

multi sub handle (Pod::Block::Comment $node, :$part-number?, :$toc-counter?, :%part-config?) is export {
	$node.contents>>.&handle();
}

multi sub handle (Pod::Block::Declarator $node, :$part-number?, :$toc-counter?) is export {
 	$node.contents>>.&handle();
}

multi sub handle (Pod::Block::Named $node, :$part-number?, :$toc-counter?, :%part-config) is export {
	$node.contents>>.&handle(:$part-number, :$toc-counter, :%part-config);
}

multi sub handle (Pod::Block::Named $node where $node.name eq 'TITLE', :$part-number?, :$toc-counter, :%part-config) is export {
	my $additional-class = $node.config && $node.config<class> ?? ' ' ~ $node.config<class> !! '';
	my $text = $node.contents[0].contents[0].Str;
	my $anchor = register-toc-entry(0, $text, $toc-counter);
	Q:c (<a name="t{$anchor}"><h1 class="title{$additional-class}">{$anchor} {$text}</h1></a>) 
}

multi sub handle (Pod::Block::Named $node where $node.name eq 'SUBTITLE', :$part-number?, :$toc-counter?, :%part-config) is export {
	my $additional-class = $node.config && $node.config<class> ?? ' ' ~ $node.config<class> !! '';
	my $text = $node.contents[0].contents[0].Str;
	Q:c (<p class="subtitle{$additional-class}">{$text}</p></a>) 
}

multi sub handle (Pod::Block::Named $node where $node.name eq 'Html', :$part-number?, :$toc-counter?, :%part-config) is export {
	$node.contents>>.&handle(HTML);
}

multi sub handle (Pod::Block::Para $node, $context = None, :$part-number?, :$toc-counter?, :%part-config) is export {
	my $class = $node.config && $node.config<class> ?? ' class = "' ~ $node.config<class> ~ '"' !! '';
	"<p$class>" ~ $node.contents>>.&handle($context, :$part-number) ~ '</p>' ~ NL;
}

multi sub handle (Pod::Block::Para $node, $context where * != None, :$part-number?, :$toc-counter?) is export {
	$node.contents>>.&handle($context);
}

multi sub handle (Pod::Block::Table $node, :$part-number?, :$toc-counter?, :%part-config?) is export {
	my $class = $node.config && $node.config<class> ?? ' class = "' ~ $node.config<class> ~ '"' !! '';
	"<table$class>" ~ NL ~
	($node.caption ?? '<caption>' ~ $node.caption.&handle() ~ '</caption>>' !! '' ) ~
	($node.headers ?? '<tr>' ~ do for $node.headers -> $cell { '<th>' ~ $cell.&handle() ~ '</th>' } ~ '</tr>' ~ NL !! '' ) ~
	do for $node.contents -> @row { 
		'<tr>' ~ do for @row -> $cell { '<td>' ~ $cell.&handle() ~ '</td>' } ~ '</tr>' ~ NL 
	} ~ 
	'</table>'
}

multi sub handle (Pod::Config $node, :$part-number?, :$toc-counter?, :%part-config) is export {
	%part-config<<{$node.type.Str}>> = $node.config;
	'<!-- ' ~ $node.type ~ '=' ~ $node.config.perl ~ '-->'
}

multi sub handle (Pod::FormattingCode $node, $context where * == Raw, :$part-number?, :$toc-counter?) is export {
	$node.contents>>.&handle($context);
}

multi sub handle (Pod::FormattingCode $node where .type eq 'B', $context = None, :$part-number?, :$toc-counter?) is export {
	my $class = $node.config && $node.config<class> ?? ' class = "' ~ $node.config<class> ~ '"' !! '';
	"<b$class>" ~ $node.contents>>.&handle($context) ~ '</b>';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'C', $context = None, :$part-number?, :$toc-counter?) is export {
	my $additional-class = $node.config && $node.config<class> ?? ' ' ~ $node.config<class> !! '';
	Q:c (<span class="code{$additional-class}">{$node.contents>>.&handle($context)} </span>);
}

multi sub handle (Pod::FormattingCode $node where .type eq 'C', $context where * ~~ Index = None, :$part-number?, :$toc-counter?) is export {
	'C<' ~ $node.contents>>.&handle() ~ '>';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'E', $context = None, :$part-number?, :$toc-counter?) is export {
	$node.meta.fmt('&%s;').join 
}

multi sub handle (Pod::FormattingCode $node where .type eq 'L', $context = None, :$part-number?, :$toc-counter?) is export {
	my $class = $node.config && $node.config<class> ?? ' class = "' ~ $node.config<class> ~ '"' !! '';
	my $content = $node.contents>>.&handle($context);
	my $link-target = $node.meta eqv [] | [""] ?? $content !! $node.meta;
	$link-target = '#' ~ $part-number ~ '-' ~ $link-target.substr(1) if $link-target.substr(0,1) eq '#';
	Q:c (<a href="{$link-target}"{$class}>{$content}</a>)
}

multi sub handle (Pod::FormattingCode $node where .type eq 'I', $context = None, :$part-number?, :$toc-counter?) is export {
	my $class = $node.config && $node.config<class> ?? ' class = "' ~ $node.config<class> ~ '"' !! '';
	"<i$class>" ~ $node.contents>>.&handle($context) ~ '</i>';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'N', $context = None, :$part-number?, :$toc-counter?) is export {
	my $additional-class = $node.config && $node.config<class> ?? ' ' ~ $node.config<class> !! '';
	Q:c (<div class="marginale">{$node.contents>>.&handle($context)}</div>);
}

multi sub handle (Pod::FormattingCode $node where .type eq 'R', $context = None, :$part-number?, :$toc-counter?) is export {
	'R<' ~ $node.contents>>.&handle($context) ~ '>';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'Z', $context = None, :$part-number?, :$toc-counter?) is export {
	'<!-- ' ~ $node.contents>>.&handle($context) ~ ' -->';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'X', $context = None, :$part-number?, :$toc-counter?) is export {
	my $additional-class = $node.config && $node.config<class> ?? ' ' ~ $node.config<class> !! '';
	my $index-display= $node.contents>>.&handle($context).Str;
	my $index-target = $node.meta;
	my $anchor = register-index-entry($node.meta.flat);
	Q:c (<span class="indexed$additional-class"><a name="{$anchor}">{$index-display}</a></span>);
}

multi sub handle (Pod::FormattingCode $node where .type eq 'X', $context where * == Heading, :$part-number?, :$toc-counter?) is export {
	my $index-display= $node.contents>>.&handle($context).Str;
	my $index-target = $node.meta;
	my $anchor = register-index-entry($node.meta.flat);
	$index-display
}

multi sub handle (Pod::Heading $node, :$part-number?, :$toc-counter, :%part-config) is export {
	my $class = $node.config && $node.config<class> ?? ' class = "' ~ $node.config<class> ~ '"' !! '';
	my $l = $node.level;
	my $text = $node.contents>>.&handle(Heading).Str;
	my $raw-text = $node.contents>>.&handle(Raw).List.flat.join;
	my $id = $part-number ~ '-' ~ $raw-text.subst(' ', '_', :g);
	if $node.config<numbered> || %part-config{'head' ~ $node.level}<numbered>.?Int {
		my $anchor = register-toc-entry($l, $text, $toc-counter);
		return Q:c (<a name="t{$anchor}"$class><h{$l} id="{$id}">{$anchor} {$text}</h{$l}></a>) ~ NL
	} else {
		my $anchor = register-toc-entry($l, $text, $toc-counter, :hide);	
		return Q:c (<a name="t{$anchor}"$class><h{$l} id="{$id}">{$text}</h{$l}></a>) ~ NL
	}
}

multi sub handle (Pod::Item $node, :$part-number?, :$toc-counter?, :%part-config?) is export {
	my $class = $node.config && $node.config<class> ?? ' class = "' ~ $node.config<class> ~ '"' !! '';
	"<ul><li$class>" x $node.level ~ $node.contents>>.&handle() ~ '</li></ul>' x $node.level
}

multi sub handle (Pod::Raw $node, :$part-number?, :$toc-counter?) is export {
	$node.contents>>.&handle()
}

# NYI
# multi sub handle (Pod::Block::Ambient $node) {
# 	$node.perl.say;
# 	$node.contents>>.&handle();
# }

multi sub handle (Str $node, Context $context?, :$part-number?, :$toc-counter?) is export {
	$node.subst('&', '&amp;', :g).subst('<', '&lt;', :g);
}

multi sub handle (Str $node, Context $context where * == HTML, :$part-number?, :$toc-counter?) is export {
	$node.Str;
}

multi sub handle (Nil, :$part-number?, :$toc-counter?) is export {
	die 'Nil';
}

