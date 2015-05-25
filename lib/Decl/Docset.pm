package Decl::Docset;

use 5.006;
use strict;
use warnings;
use Data::Dumper;
use Carp;

=head1 NAME

Decl::Docset - Organizes the documents that make up a Decl environment

=head1 VERSION

Version 0.20

=cut

our $VERSION = '0.20';


=head1 SYNOPSIS

A docset is nothing more than a list of documents that define a Decl system.
In the very simplest case, that's just a single file or string, but more often
it's a directory or a database containing a series of textual definitions.

Each document in a docset is a textual asset that (depending on its type) can be
parsed to yield a series of syntactic objects.

This specific class is a base class that defines a degenerate "docset" consisting
of a single document provided in a string. That allows the smallest dependency
footprint possible.

=head1 METHODS

=head2 new

Defines a new docset. For a string docset, the first parameter is the string. By default,
we consider it to be of type 'tag'. If there's a second parameter, that will be the
type.

=cut

sub new {
    my ($class, $string, $type) = @_;
    my $self = bless {}, $class;
    $self->{string} = $string;
    $self->{type} = $type || 'tag';
    return $self;
}

=head2 list

Lists the documents in the docset, by ID. This is an iterator, but obviously pretty
boring for this base class.

=cut

sub list {
    my $self = shift;
    my @list = ('*');
    return sub { shift @list; };
}

=head2 info (id, [field])

Returns a hashref of information about the document or, if a field name is given, returns
the value of that field. Returns undef if the document doesn't exist or if the field
isn't defined.

The minimum information known about a document it is id, tag, and type. (This list
can be expected to change as I get some experience.)

=cut

sub info {
    my $self = shift;
    my $id = shift;
    my $field = shift;
    return undef unless $id eq '*';
    my $info = {
        id => '*',
        tag => '',
        type => $self->{type},
    };
    if (defined $field) {
        return $info->{$field};
    }
    return $info;
}

=head2 text (id)

Returns the text of the document in the form of either an iterator of lines
or a filehandle. (I.e. as an iterable set of lines, either way.)

=cut

sub text {
    my $self = shift;
    my $id = shift;
    return undef unless $id eq '*';
    my @list = (split /\n/, $self->{string});
    return sub { shift @list; };
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

1; # End of Decl::Docset
