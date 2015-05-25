#!perl -T
use strict;
use warnings;
use Decl::Node;
use Data::Dumper;

use Test::More;

my @log = ();
sub test_indexer {
	my ($docid, $tag, $name, $level, $path) = @_;
    push @log, [$docid, $tag, $name, $level, $path];
}

my $decl = <<'EOF';
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

my $d = Decl::Node->new(\$decl, undef, {type=>'textplus', indexer=>\&test_indexer, docid=>'3'});
isa_ok ($d, 'Decl::Node');
isa_ok ($d->{syntax}, 'Decl::Syntax');
ok (@{$d->{children}} == 1);

my $c = $d->{children}->[0];
my $dialog_tag = $c;   # Used for logical testing below
ok ($c->tag eq 'dialog');
ok ($c->name eq '');
ok ($c->inparm('xsize') == 250);
ok ($c->inparm('ysize') == 110);
ok ($c->string eq "Wx::Declarative dialog sample");

ok (@{$c->{children}} == 1);

$c = $c->{children}->[0];
ok ($c->tag eq 'field');
ok ($c->name eq 'celsius');
ok ($c->inparm('size') == 100);
ok ($c->string eq '0');
ok ($c->inparm_n(0) eq 'size');
ok ($c->inparm_n(2) eq 'y');

is_deeply (\@log, [['3', 'dialog', '', 1, '.dialog'], ['3', 'field', 'celsius', 2, '.dialog.field']]);
# Note: this is wrong and will change, but it's a start.

ok ($dialog_tag->match ({tag => 'dialog'}));
ok (not $dialog_tag->match ({tag => 'something else'}));
ok ($dialog_tag->match ({not => {tag => 'something else'}}));
ok ($dialog_tag->match ({tag => qr/^dia/}));
ok (not $dialog_tag->match ({tag => qr/^blah/}));

ok ($dialog_tag->match ({string => qr/sample/}));
ok ($dialog_tag->match ({tag => 'dialog', string => qr/sample/}));

my $ffield = $d->first({tag => 'field'});
ok ($ffield->tag eq 'field');
ok ($ffield->name eq 'celsius');

my @fields = $d->all({tag => 'field'});
ok (@fields == 1);
ok ($fields[0]->name eq 'celsius');

done_testing();