#!perl -T
use strict;
use warnings;
use Decl::Docset;  # Base class
use Decl::Docset::Files;
use Decl::Docset::DBI;
use Data::Dumper;

use Test::More;

my $docset = Decl::Docset->new(<<EOF);
tag "this thing"
  test
EOF

isa_ok ($docset, 'Decl::Docset');
ok ($docset->info('*', 'type') eq 'tag');
my $i = $docset->info('*');
ok (ref($i), 'HASH');
ok ($i->{id} eq '*');

my $iter = $docset->list();
ok ($iter->() eq '*');
my $next = $iter->();
ok (not defined $next);


$docset = Decl::Docset::Files->new(
	scan => {
		start => 't/filetest',
	    type  => 'conlist',
    	contains => ['tag', 'textplus'],
	},
	items => { tag      => { type => 'file', ext => 'decl'},
	           textplus => { type => 'file', ext => 'docl'},
	         },
	return => ['tag', 'textplus'],
);

$iter = $docset->list();
ok ($iter->() eq '0');
ok ($iter->() eq '1');
$next = $iter->();
ok (not defined $next);

ok ($docset->info('0', 'type') eq 'tag');
ok ($docset->info('1', 'type') eq 'textplus');
ok ($docset->info('0', 'name') eq 'test1.decl');


$docset = Decl::Docset::DBI->new(
	file       => 't/sqltest.db',
	table      => 'code',
	idcol      => 'id',
	typecol    => 'type',
	contentcol => 'text',
);

$iter = $docset->list();
ok ($iter->() eq '1');
ok ($iter->() eq '2');
$next = $iter->();
ok (not defined $next);

ok ($docset->info('1', 'type') eq 'tag');
ok ($docset->info('2', 'type') eq 'textplus');




$docset = Decl::Docset::DBI->new(
	file       => 't/sqltest.db',
	table      => 'code',
	idcol      => 'id',
	type       => 'textplus',
	contentcol => 'text',
);

$iter = $docset->list();
ok ($iter->() eq '1');
ok ($iter->() eq '2');
$next = $iter->();
ok (not defined $next);

ok ($docset->info('1', 'type') eq 'textplus');
ok ($docset->info('2', 'type') eq 'textplus');

done_testing();