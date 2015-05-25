#!perl -T
use strict;
use warnings;
use Decl::Syntax;
use Data::Dumper;

use Test::More;

# Exercise the line parser.

sub testtok {
	my @tok = Decl::Syntax::tokpost(Decl::Syntax::toktag(shift));
	\@tok;
}

#goto BIG_SKIP;
my $tok;
$tok = testtok (   'A "quoted thing\'\\"# or two" in it. #comment with "q"');
ok (scalar @$tok == 5);
ok ($tok->[0]->[2] eq '');
ok ($tok->[0]->[3] eq 'A');
ok ($tok->[4]->[0] == 35);
ok ($tok->[4]->[1] == 16);
ok ($tok->[4]->[2] eq '#');
ok (Decl::Syntax::_sigil ($tok) eq '');

$tok = testtok (   'this (has parens) [bob="your uncle", "q", k=v=v]');
#print STDERR Decl::Syntax::tokdebug ($tok);
ok (scalar @$tok == 3);
ok ($tok->[1]->[2] eq ')', 'closed parens');
ok (ref $tok->[1]->[3] eq 'ARRAY');
ok ($tok->[1]->[3]->[0]->[0] == 5);
ok ($tok->[1]->[3]->[0]->[3] eq 'has parens');
ok ($tok->[2]->[2] eq ']', 'closed brackets');
ok ($tok->[2]->[3]->[0]->[2] eq '=');
ok ($tok->[2]->[3]->[0]->[3]->[1]->[0] == 23);
ok ($tok->[2]->[3]->[0]->[3]->[1]->[2] eq '"');
ok ($tok->[2]->[3]->[0]->[3]->[1]->[3] eq 'your uncle');
ok (Decl::Syntax::_sigil ($tok) eq '');

my @p = Decl::Syntax::_parameters ($tok);
is_deeply (\@p, [['this', '', undef],
	             ['has parens', ')', undef],
                 ['bob', ']', 'your uncle'],
                 ['q', ']', undef],
                 ['k', ']', 'v=v']
	            ]);

$tok = testtok (   'field celsius [x, y] { $^fahrenheit = "something"; }');
is_deeply ($tok, [[0, 5, '', 'field'],
	              [6, 7, '', 'celsius'],
	              [14, 4, ']', [[14, 1, '', 'x'],
	                            [17, 1, '', 'y']
	                           ]],
	              [21, 30, '}', ' $^fahrenheit = "something"; ']
	             ]);
ok (Decl::Syntax::_sigil ($tok) eq '');

@p = Decl::Syntax::_parameters ($tok);
is_deeply (\@p, [['field', '', undef],
	             ['celsius', '', undef],
	             ['x', ']', undef],
	             ['y', ']', undef],
	             ['}', '}', ' $^fahrenheit = "something"; ']]);

$tok = testtok (   'set table <select a, b from other_table where a < 10>');
is_deeply ($tok, [[0,3,'','set'],
	              [4,5,'','table'],
	              [10,42,'>','select a, b from other_table where a < 10']
	             ]);

$tok = testtok (   'set table <insert into table (id) values ("92")>');
is_deeply ($tok, [[0,3,'','set'],
	              [4,5,'','table'],
	              [10,37,'>','insert into table (id) values ("92")']
	             ]);

$tok = testtok (   'intro to code {     # comment');
is_deeply ($tok, [[0,5,'','intro'],
	              [6,2,'','to'],
	              [9,4,'','code'],
	              [14,0,'{', ''],
	              [20,8,'#',' comment']
	             ]);
ok (Decl::Syntax::_sigil ($tok) eq '{');

$tok = testtok (   'text:?{}          # comment with "quotes"');
ok (Decl::Syntax::_sigil ($tok) eq ':?{}');
is_deeply ($tok, [[0,4,'','text'],
	              [4,3,':','?{}'],
	              [18,23,'.','# comment with "quotes"']
	             ]);

$tok = testtok (   'text: text starts here');
ok (Decl::Syntax::_sigil ($tok) eq ':');
is_deeply ($tok, [[0,4,'','text'],
	              [4,0,':',''],
	              [6,16,'.','text starts here']
	             ]);

$tok = testtok (   'text: { this is text in brackets }');
ok (Decl::Syntax::_sigil ($tok) eq ':');
is_deeply ($tok, [[0,4,'','text'],
	              [4,0,':',''],
	              [6,28,'.','{ this is text in brackets }']
	             ]);

$tok = testtok (   'lisp (');
ok (Decl::Syntax::_sigil ($tok) eq '(');
#diag Decl::Syntax::tokdebug ($tok);
is_deeply ($tok, [[0,4,'','lisp'],
	              [5,0,'(',''],
	             ]);


# Now some full syntax.
my $decl1 = <<'EOF';

# This is our very first file of Decl 2.0, and it should illuminate some of the
  basics of the language (that is, the *syntax*). It is in 'tag' format.

; This could be an alternate
  comment format.

text: testing here

dialog (xsize=250, ysize=110) "Wx::Declarative dialog sample"
   # comment here?
   field celsius (size=100, x=20, y=20) "0"
   button celsius (x=130, y=20) "Celsius" { $^fahrenheit = ($^celsius / 100.0) * 180 + 32; }
   field fahrenheit (size=100, x=20, y=50) "32"
   button fahrenheit (x=130, y=50) "Fahrenheit" { $^celsius = (($^fahrenheit - 32) / 180.0) * 100; }

EOF

my $d = Decl::Syntax->load(\$decl1, 'tag');
isa_ok ($d, 'Decl::Syntax');

ok ($d->{what} eq 'source');
ok ($d->{type} eq 'string');
my $c = $d->{children};
ok (@$c == 4);
ok ($c->[0]->{what} eq 'comment');
ok ($c->[1]->{what} eq 'tag');
ok ($c->[1]->{tag}  eq ';');
ok ($c->[1]->sigil  eq '');
ok ($c->[2]->{tag}  eq 'text');
ok ($c->[2]->sigil  eq ':');
ok ($c->[2]->{lineno} == 8);
ok ($c->[2]->{indent} == 0);
ok ($c->[3]->{tag}  eq 'dialog');

ok (not defined $c->[3]->linecode);



$d = $c->[3]; # Let's look at the dialog.
$c = $d->{children};
ok (@$c == 5);
ok ($c->[2]->{tag} eq 'button');

@p = $c->[2]->parameters();
is_deeply (\@p, [['celsius', '', undef],
	             ['x', ')', '130'],
                 ['y', ')', '20'],
                 ['"', '"', 'Celsius'],
                 ['}', '}', ' $^fahrenheit = ($^celsius / 100.0) * 180 + 32; ']]);

@p = $c->[2]->parmnames(')');
is_deeply (\@p, ['x', 'y']);

ok ($c->[2]->getparm ('x') == 130);
ok ($c->[2]->linecode eq ' $^fahrenheit = ($^celsius / 100.0) * 180 + 32; ');
ok ($c->[2]->linecodetype eq '}');


# Now we test some different special cases of tags.
$decl1 = <<'EOF';
text:
  This is a normal
  multiline text body.

  It skips a line.

code {
	# There could be code here.
}

   addendum: But there's a subordinate tag after it.

text:~
  This multiline text body
  stops at the first blank line.

  more-info: Then it has a tag after it.

: Testing a sigil-only tag.
  It is multi-lined, but pushed up after the sigil.

tag

EOF
$d = Decl::Syntax->load(\$decl1, 'tag');
isa_ok ($d, 'Decl::Syntax');
#diag $d->dump_tree;

my @tags = map { $_->{tag}} $d->children;
is_deeply (\@tags, ['text', 'code', 'text', '', 'tag']);
my @test = map { $_->hastext} $d->children;
is_deeply (\@test, [1, 0, 1, 1, 0]);
@test = map { $_->hascode} $d->children;
is_deeply (\@test, ['', '{', '', '', '']);
@test = map { $_->haschildren} $d->children;
is_deeply (\@test, [0, 1, 1, 0, 0]);

my $text = $d->{children}->[0];
ok ($text->gettext eq "This is a normal\nmultiline text body.\n\nIt skips a line.");
ok (not $text->getcode);
my $code = $d->{children}->[1];
ok (not $code->gettext);
ok ($code->getcode eq "# There could be code here.");
ok ($code->hascode eq '{');
my $addendum = $code->{children}->[0];
ok ($addendum->{tag} eq 'addendum');
ok ($addendum->hastext);
ok ($addendum->gettext eq 'But there\'s a subordinate tag after it.');

$text = $d->{children}->[2];
ok ($text->gettext eq "This multiline text body\nstops at the first blank line.");

my $sigiled = $d->{children}->[3];
ok ($sigiled->tag eq '');
ok ($sigiled->{sigil} eq ':');
ok ($sigiled->hastext);
ok ($sigiled->gettext eq "Testing a sigil-only tag.\nIt is multi-lined, but pushed up after the sigil.");


$decl1 = <<'EOF';
[oob tag]: This is just
           some OOB commentary text

EOF
$d = Decl::Syntax->load(\$decl1, 'tag');
isa_ok ($d, 'Decl::Syntax');
$c = $d->{children}->[0];
ok ($c->tag, '[oob tag]');
ok ($c->hastext);
ok ($c->gettext, "This is just\nsome OOB commentary text");
#diag $d->dump_tree;


$decl1 = <<'EOF';
This is a sample of a text-plus mode Decl input.
Note that it is organized into text that in turn contains tag-based nodes.

" This textual tag can be used for quoting items.
  It gently preserves indentation without being ostentatious about it.

"But if I just quote text without a separating space, it stays text."
We can easily embed code, too:

+dialog (xsize=250, ysize=110) "Wx::Declarative dialog sample"
   # comment here
   field celsius (size=100, x=20, y=20) "0"

After the code, we're back to text, and so it goes. This is a lightweight,
very expressive syntax for building code on the fly during discussion
of its motivations; in conjunction with relatively slim tangling code,
we have a very powerful "literate programming markdown".
EOF

$d = Decl::Syntax->load(\$decl1, 'textplus');
isa_ok ($d, 'Decl::Syntax');
my @c = $d->children;
ok (scalar @c == 5);
@test = map {ref $_} @c;
is_deeply (\@test, ['ARRAY', 'Decl::Syntax', 'ARRAY', 'Decl::Syntax', 'ARRAY']);

$d = $d->{children}->[3];
ok ($d->tag eq 'dialog');
ok ($d->getparm('ysize') == 110);
@c = $d->children;
ok (scalar @c == 2);
ok ($d->{children}->[1]->tag eq 'field');

$decl1 = <<'EOF';
tag blah blah
   <insertion point>

<insertion point>: Text here.

EOF
$d = Decl::Syntax->load(\$decl1, 'tag');
isa_ok ($d, 'Decl::Syntax');
$c = $d->{children}->[1];
ok ($c->tag eq '<insertion point>');
ok ($c->hastext);
ok ($c->gettext eq "Text here.");


BIG_SKIP:

$decl1 = <<'EOF';
code <angle code>
code <
   more angle code
>
code {curly code}
code {
	more curly code
}
code (
	lispy code
)
code [
	brackety code
]
EOF

$d = Decl::Syntax->load(\$decl1, 'tag');
@test = map {$_->hascode} $d->children;
is_deeply (\@test, ['<', '<', '{', '{', '(', '[']);

done_testing();