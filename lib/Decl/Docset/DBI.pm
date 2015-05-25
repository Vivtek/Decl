package Decl::Docset::DBI;

use 5.006;
use strict;
use warnings;
use File::Org;
use Data::Dumper;
use DBI;
use Carp;

use base "Decl::Docset";

=head1 NAME

Decl::Docset::DBI - Provides a docset based on a database table

=head1 VERSION

Version 0.20

=cut

our $VERSION = '0.20';


=head1 SYNOPSIS

The base docset class isn't terribly interesting, as it just gives us the ability to create a "docset" consisting
of a single document in a string. Decl::Docset::DBI does something more normal: it allows us to create a docset
that uses a database table as the source of our code text.

=head1 METHODS

=head2 new

Defines a new docset. For a database docset, the parameters include a dbh (or a filename if you want to default to
SQLite - or no filename if you want to default to SQLite in a default file in the current directory), the table
name, and the names of the columns that contain the id, type, and contents of each document.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    my $p = {@_};
    if ($p->{dbh}) {
        $self->{dbh} = $p->{dbh};
    } elsif ($p->{file}) {
        $self->{dbh} = DBI->connect('dbi:SQLite:dbname=' . $p->{file});
    } else {
        $self->{dbh} = DBI->connect('dbi:SQLite:dbname=decl.sqld');
    }

    $self->{table} = $p->{table} || 'code';
    $self->{idcol} = $p->{idcol} || 'id';
    $self->{type} = $p->{type};
    if (not $self->{type}) {
        $self->{typecol} = $p->{typecol} || 'type';
    }
    $self->{contentcol} = $p->{contentcol} || 'content';
    return $self;
}

=head2 list

Lists the documents in the docset, by ID. For the file docset, the IDs are just sequential
numbers in order of their encounter in the fileorg, so this is not terribly exciting.

=cut

sub list {
    my $self = shift;
    my $index = 0;

    my $sth = $self->{dbh}->prepare (sprintf "select %s from %s order by %s", $self->{idcol}, $self->{table}, $self->{idcol});
    my $id;
    $sth->bind_columns(\$id);
    $sth->execute();
    return sub {
        return undef unless $sth->fetch;
        return $id;
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
    my $sth = $self->{dbh}->prepare (sprintf "select * from %s where %s=?", $self->{table}, $self->{idcol});
    $sth->execute($id);
    my $hash = $sth->fetchrow_hashref;
    return undef unless defined $hash;
    $hash->{type} = $self->{type} if $self->{type};
    if (defined $field) {
        return $hash->{$field};
    }
    return $hash;
}

=head2 text (id)

Returns the text of the document in the form of either an iterator of lines
or a filehandle. (I.e. as an iterable set of lines, either way.)

=cut

sub text {
    my $self = shift;
    my $id = shift;
    my $sth = $self->{dbh}->prepare (sprintf "select %s from %s where %s=?", $self->{contentcol}, $self->{table}, $self->{idcol});
    $sth->execute($id);
    my $string;
    $sth->bind_columns (\$string);
    return undef unless $sth->fetch;
    my @list = (split /\n/, $string);
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

1; # End of Decl::Docset::DBI
