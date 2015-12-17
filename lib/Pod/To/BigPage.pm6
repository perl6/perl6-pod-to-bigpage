unit class Pod::To::BigPage;
use fatal;

PROCESS::<$SCHEDULER> = ThreadPoolScheduler.new(initial_threads => 0, max_threads => %*ENV<THREADS>.?Int // 2);

# my $*SCHEDULER =  ThreadPoolScheduler.new(initial_threads => 0, max_threads => %*ENV<THREADS>.?Int // 2);

our $html-header;
our $html-before-content;
our $html-after-content;

my @toc;
my %register;

constant NL = "\n";

sub setup () is export {
	$html-header = q:to/EOH/;
		<title>Untitled</title>
		<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
		<style type="text/css">
			body { margin-left: 4em; margin-right: 4em; }
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
			ul.toc { list-style-type: none; }
			ul.toc ul { list-style-type: none; }
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

sub register-toc-entry($level, $text) {
	state $lock = Lock.new;
	state Int $global-toc-counter = 0;
	my $clone;
	$lock.protect: {
		++$global-toc-counter;
		$clone = $global-toc-counter.clone;
		@toc.push: $level => $text => $clone;
	}
	't' ~ $clone
}

sub compose-toc (:$toc = @toc) is export {
	my $last-level = 0;
	'<ul class="toc" id="toc">' ~ NL ~
	do for @toc -> Pair $p (:$key, :$value) {
		my $text := $value.key;
		my $level = $key;
		my $target := $value.value;
		my $retval;
		
		$retval = 
		($last-level > $level ?? '  ' x $level ~ '</ul>' x ($last-level - $level) ~ NL !! '') ~ 
		($last-level < $level ?? '  ' x $last-level ~ '<ul>' x ($level - $last-level) ~ NL !! '') ~ 
		'  ' x $level ~ qq{<li><a href="#t$target">} ~ $text ~ '</a></li>' ~ '<!-- ' ~ $level ~ ' ' ~ $level - $last-level ~ ' -->' ~ NL;
		
		$last-level = $level;
		$retval
	} ~
	'</ul>'
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

my enum Context ( None => 0, Index => 1 , Heading => 2);

my proto sub handle ($node, Context $context = None) is export {
	{*}
}

multi sub handle (Pod::Block::Code $node) is export {
	'<pre class="code">' ~ $node.contents>>.&handle() ~ '</pre>' ~ NL;
}

multi sub handle (Pod::Block::Comment $node) is export {
	$node.contents>>.&handle();
}

multi sub handle (Pod::Block::Declarator $node) is export {
 	$node.contents>>.&handle();
}

multi sub handle (Pod::Block::Named $node) is export {
	$node.contents>>.&handle();
}

multi sub handle (Pod::Block::Named $node where $node.name eq 'TITLE') is export {
	my $text = $node.contents[0].contents[0].Str;
	my $anchor = register-toc-entry(0, $text);
	Q:c (<a name="{$anchor}"><h1 class="title">{$text}</h1></a>) 
}

multi sub handle (Pod::Block::Named $node where $node.name eq 'SUBTITLE') is export {
	my $text = $node.contents[0].contents[0].Str;
	Q:c (<p class="subtitle">{$text}</p></a>) 
}

multi sub handle (Pod::Block::Named $node where $node.name eq 'Html') is export {
	$node.contents>>.&handle();
}

multi sub handle (Pod::Block::Para $node, $context = None) is export {
	'<p>' ~ $node.contents>>.&handle($context) ~ '</p>' ~ NL;
}

multi sub handle (Pod::Block::Para $node, $context where * == Heading ) is export {
	$node.contents>>.&handle($context);
}

multi sub handle (Pod::Block::Table $node) is export {
	'<table>' ~ NL ~
	($node.caption ?? '<caption>' ~ $node.caption.&handle() ~ '</caption>>' !! '' ) ~
	($node.headers ?? '<tr>' ~ do for $node.headers -> $cell { '<th>' ~ $cell.&handle() ~ '</th>' } ~ '</tr>' ~ NL !! '' ) ~
	do for $node.contents -> @row { 
		'<tr>' ~ do for @row -> $cell { '<td>' ~ $cell.&handle() ~ '</td>' } ~ '</tr>' ~ NL 
	} ~ 
	'</table>'
}

multi sub handle (Pod::Config $node) is export {
	$node.contents>>.&handle();
}

multi sub handle (Pod::FormattingCode $node where .type eq 'B', $context = None) is export {
	'<b>' ~ $node.contents>>.&handle($context) ~ '</b>';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'C', $context = None) is export {
	'<span class="code">' ~ $node.contents>>.&handle($context) ~ '</span>';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'C', $context where * ~~ Index = None) is export {
	'C<' ~ $node.contents>>.&handle() ~ '>';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'L', $context = None) is export {
	my $link-target = $node.meta;
	qq{<a href="$link-target">} ~ $node.contents>>.&handle($context) ~ '</a>';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'I', $context = None) is export {
	'<i>' ~ $node.contents>>.&handle($context) ~ '</i>';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'N', $context = None) is export {
	'<div class="marginale">' ~ $node.contents>>.&handle($context) ~ '</div>';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'R', $context = None) is export {
	'R<' ~ $node.contents>>.&handle($context) ~ '>';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'Z', $context = None) is export {
	'<!-- ' ~ $node.contents>>.&handle($context) ~ ' -->';
}

multi sub handle (Pod::FormattingCode $node where .type eq 'X', $context = None) is export {
	my $index-display= $node.contents>>.&handle($context).Str;
	my $index-target = $node.meta;
	my $anchor = register-index-entry($node.meta.flat);
	Q:c (<span class="indexed"><a name="{$anchor}">{$index-display}</a></span>);
}

multi sub handle (Pod::FormattingCode $node where .type eq 'X', $context where * == Heading) is export {
	my $index-display= $node.contents>>.&handle($context).Str;
	my $index-target = $node.meta;
	my $anchor = register-index-entry($node.meta.flat);
	$index-display
}

multi sub handle (Pod::Heading $node) is export {
	my $l = $node.level;
	my $text = $node.contents>>.&handle(Heading).Str;
	my $anchor = register-toc-entry($l, $text);
	Q:c (<a name="{$anchor}"><h{$l}>{$text}</h{$l}></a>) ~ NL
}

multi sub handle (Pod::Item $node) is export {
	'<ul><li>' x $node.level ~ $node.contents>>.&handle() ~ '</li></ul>' x $node.level
}

multi sub handle (Pod::Raw $node) is export {
	$node.contents>>.&handle()
}

# NYI
# multi sub handle (Pod::Block::Ambient $node) {
# 	$node.perl.say;
# 	$node.contents>>.&handle();
# }

multi sub handle (Str $node, Context $context?) is export {
	$node.subst('&', '&amp;', :g).subst('<', '&lt;', :g);
}

multi sub handle (Nil) is export {
	die 'Nil';
}
