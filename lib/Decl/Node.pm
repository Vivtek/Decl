package Decl::Node;

use 5.006;
use strict;
use warnings;
use Decl::Syntax;
use Data::Dumper;
use Carp;

=head1 NAME

Decl::Node - Represents a semantic map node in a Decl structure

=head1 VERSION

Version 0.20

=cut

our $VERSION = '0.20';


=head1 SYNOPSIS

Once Decl has parsed a document that describes a set of objects or actions, it then interprets
the syntactic structure. This is where that happens. A Node is a semantic node that encapsulates
a unit of meaning. It maps a part of the syntactic structure to a part of the eventual output.

Eventually, a Node will be able to work the other way as well; it will be able to look at
an output that falls into its class and derive the Decl syntactic expression that expresses
that output. I think we can safely say that's going to take a while, though.

Nodes I<extract> information from the syntactic structure during the process of, appropriately
enough, I<extraction>. The node then maps each syntactic tag onto a handler class using
the vocabulary established for the context.

=head1 CREATION AND LOADING



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

1; # End of Decl::Node
