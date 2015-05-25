package Decl;

use 5.006;
use strict;
use warnings;
use DBI;
use Decl::Node;

=head1 NAME

Decl - a declarative programming language

=head1 VERSION

Version 0.20

=cut

our $VERSION = '0.20';


=head1 SYNOPSIS

Decl is a declarative programming language that focuses on the definition of structures instead of the specification of actions.
Its main distinguishing features are a rich syntax, document orientation instead of stream orientation, literate programming
techniques baked in from the start, programming language agnosticism, and a semantic approach instead of a syntactic approach.

It's still 90% handwaving, but that's an improvement over the 99% it's been in the past.

The base Decl object constitutes an instance. An instance has a docset (the set of source documents that define it), a lexicon
(the set of vocabularies that convert its syntax-level objects into semantic structure), a semantic machine (the interface
between the instance and the system it is controlling or with which it interacts), and an optional persistence mechanism
that allows its state to be preserved.

=head1 METHODS

=head2 new

This creates a new Decl instance. Right now, this simply takes the docset we'll be working from, plus a specification for
the persistence database (if any). Later I'll pull the persistence structure out into another set of classes, but I have
places to go this weekend.

=cut

sub new {
	my $class = shift;
	my $self = bless {}, $class;
    my $p = {@_};
    if ($p->{dbh}) {
    	$self->{dbh} = $p->{dbh};
    } elsif ($p->{dbfile}) {
        $self->{dbh} = DBI->connect('dbi:SQLite:dbname=' . $p->{dbfile});
    } else {
        $self->{dbh} = DBI->connect('dbi:SQLite:dbname=decl.sqld');
    }
    if ($p->{docset}) {
    	$self->{docset} = $p->{docset};
    	# Todo: some kind of simplifying default behavior.
    }
    return $self;
}

=head2 load

Loads all the code from the docset into the workspace.

=cut

sub load {
	my $self = shift;
	my $iter = $self->{docset}->list;
	$self->{ws} = {};
	my $indexer = sub {
		my ($docid, $tag, $name, $level, $path, $node) = @_;
		return unless $level == 1; # Top-level only (for now)
		push @{$self->{ws}->{$tag}->{list}}, [$name, $docid, $node];
		$self->{ws}->{$tag}->{names}->{$name} = $node;
	};

	while (my $next = $iter->()) {
		last if not defined $next; # Little paranoia here...
		my $i = $self->{docset}->info($next);
		my $content = $self->{docset}->text($next);
		my $d = Decl::Node->new($content, undef, {type=>$i->{type}, indexer=>$indexer, docid=>$next});
	}
}

=head2 extract (tag, coderef)

Walks through a loaded workspace looking for all instances of a specific tag. When one is found,
the coderef is called on it and the list of the returns of all the calls is returned from this method.

=cut

sub extract {
	my ($self, $tag, $coderef) = @_;

	map {$coderef->($_->[2])} @{$self->{ws}->{$tag}->{list}};
}

=head1 AUTHOR

Michael Roberts, C<< <michael at vivtek.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-decl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Decl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Decl


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Decl>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Decl>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Decl>

=item * Search CPAN

L<http://search.cpan.org/dist/Decl/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2015 Michael Roberts.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Decl
