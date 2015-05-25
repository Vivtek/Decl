package Decl::Docset::Files;

use 5.006;
use strict;
use warnings;
use File::Org;
use Data::Dumper;
use Carp;

use base "Decl::Docset";

=head1 NAME

Decl::Docset::Files - Provides a docset based on a set of files

=head1 VERSION

Version 0.20

=cut

our $VERSION = '0.20';


=head1 SYNOPSIS

The base docset class isn't terribly interesting, as it just gives us the ability to create a "docset" consisting
of a single document in a string. Decl::Docset::Files does something more normal: it allows us to create a docset
that reads the contents of a directory and treats those files as the documents in question.

Using the magic of L<File::Org>, it can also assign different types to the different files based on arbitrary
criteria, drill down into subdirectories, and so on.

=head1 METHODS

=head2 new

Defines a new docset. For a file docset, the first and only parameter is the File::Org specification, either as
an existing File::Org object, as the series of hashref parameters that File::Org interprets, or (later) as a Decl
string encoding a File::Org.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    if (@_ == 1) {
        my $p = shift;
        croak "Can't support string initializer for a Docset::Files yet" unless ref $p;
        if ($p->can('scan')) {
            $self->{scanner} = $p;
        } else {
            croak "Don't know how to initialize from a " . ref $p;
        }
    } else {
        $self->{scanner} = File::Org->new(@_);
    }
    $self->scan;
    return $self;
}

=head2 scan

Runs through the scanner provided to cache the results. (This is to provide the convenient file-at-a-time docset
retrieval functionality.) File IDs are assigned during this scan that remain valid for the session, to be used to
index the docset.

=cut

sub scan {
    my $self = shift;
    $self->{data} = {};
    $self->{count} = 0;
    my $scanner = $self->{scanner}->scan;
    while (my $entry = $scanner->()) {
        last unless defined $entry;
        next unless $entry->[1]; # Only include typed files in the list (this should be covered by the spec, but doesn't work yet)
        $self->{data}->{$self->{count}} = { type => $entry->[1],
                                            name => $entry->[2],
                                            path => $entry->[3],
                                            valu => $entry->[5],
                                            stat => $entry->[6]
                                          };
        $self->{count} += 1;
    }
    return $self->{count}; # Might as well return *something*.
}

=head2 list

Lists the documents in the docset, by ID. For the file docset, the IDs are just sequential
numbers in order of their encounter in the fileorg, so this is not terribly exciting.

=cut

sub list {
    my $self = shift;
    my $index = 0;
    return sub {
        return undef if $index >= $self->{count};
        $index += 1;
        return $index - 1; # This turned out rather inelegant.
    };
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
    return undef unless $id < $self->{count};
    if (defined $field) {
        return $self->{data}->{$id}->{$field};
    }
    return $self->{data}->{$id};
}

=head2 text (id)

Returns the text of the document in the form of either an iterator of lines
or a filehandle. (I.e. as an iterable set of lines, either way.)

=cut

sub text {
    my $self = shift;
    my $id = shift;
    return undef unless $id < $self->{count};
    open (my $input, '<', $self->{data}->{$id}->{path});
    return $input;
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

1; # End of Decl::Docset::Files
