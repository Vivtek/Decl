package Decl::Node;

use 5.006;
use strict;
use warnings;
use Decl::Syntax;
use Data::Dumper;
use Scalar::Util 'blessed';
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

=head1 EXTRACTION

Decl's syntactic tolerance is actually very broad. Between the tag and the sigil (or the end
of the line if there's no sigil) we can have any combination of barewords, parenthetical or
bracketed parameters, and quoted strings as far as the raw syntax is concerned.

For the default tag structure, I rather arbitrarily restrict that to zero or one bareword (a name),
followed by any combination of parameters, followed by zero or one quoted tag. This is mostly
due to the fact that this was the syntax in the first round of Decl, and it feels natural.

Once extracted, a node can be enacted to create an arbitrary object or take an arbitrary action,
based on the vocabulary configured. It can also be indexed during construction if an indexer
callback is provided.

Each node is situated in a specific document in the document set, and knows its original location.
Each node also knows its location within the tag tree in that document. So we can derive a
unique identifier for each node that can be used to locate it or name it.

=cut

sub new {
    my $class = shift;
    my $syntax = shift;
    my $parent = shift;
    my $context = shift || {};
    if (not (blessed ($syntax) and $syntax->isa('Decl::Syntax'))) {
        $syntax = Decl::Syntax->load($syntax, $context->{type} ? $context->{type} : 'tag');
    }
    my $self = bless {
        tag      => $syntax->{tag},
        syntax   => $syntax,
        parent   => $parent,
        docid    => defined $context->{docid} ? $context->{docid} : '',
        level    => defined $parent ? $parent->level + 1 : 0,
        name     => '',
        inparm_list => [],
        inparms  => {},
        exparm_list => [],
        exparms  => {},
        string   => '',
        text     => '',
        code     => '',
        hastext  => 0,
        hascode  => 0,
        warnings => [],
        haswarnings => 0,
        children => [],
    }, $class;
    if ($parent) {
        my $offset = 0;
        foreach my $p ($syntax->parameters) { # TODO: This is the default - overridable
            $offset++;
            if ($p->[1] eq '') {
                if ($offset == 1) {
                    $self->{name} = $p->[0];
                } else {
                    push @{$self->{warnings}}, sprintf ("Name %s not in first position", $p->[0]);
                }
            } elsif ($p->[1] eq ')') {
                $self->{inparms}->{$p->[0]} = defined $p->[2] ? $p->[2] : 1;
                push @{$self->{inparm_list}}, $p->[0];
                push @{$self->{warnings}}, "Inparm after a string" if $self->{string};
            } elsif ($p->[1] eq ']') {
                $self->{exparms}->{$p->[0]} = defined $p->[2] ? $p->[2] : 1;
                push @{$self->{exparm_list}}, $p->[0];
                push @{$self->{warnings}}, "Exparm after a string" if $self->{string};
            } elsif ($p->[1] eq '"' or $p->[1] eq "'") {
                if ($self->{string}) {
                    push @{$self->{warnings}}, "More than one string";
                }
                $self->{string} = $p->[2];
            }
        }
        if ($syntax->hascode) {
            $self->{hascode} = 1;
            $self->{code} = $syntax->getcode; # TODO: postprocessing by vocab
        } elsif ($syntax->hastext) {
            $self->{hastext} = 1;
            $self->{text} = $syntax->gettext; # TODO: ALLLLLL the postprocessing
        }
        if ($context->{indexer}) {
            $context->{indexer}->($self->docid, $self->tag, $self->name, $self->level, $self->path, $self);
        }
    }
    foreach my $child ($syntax->children) {
        next if ref $child eq 'ARRAY'; # Skip any intervening text
        next if $child->{what} ne 'tag'; # Skip any non-tag children
        push @{$self->{children}}, $class->new($child, $self, $context);
    }
    $self;
}

=head2 ACCESS

=head1 tag, name, inparm(x), exparm(x), string, level

These access the different parts of the tag.

Both 'tag' and 'name' can be called as getters or testers; that is, $self->tag returns the tag but $self->tag('value') returns
the result of $self->tag eq 'value'. Just to save a little typing.

=cut

sub tag    {
    my ($self, $value) = @_;
    return $self->{tag} if not defined $value;
    $self->{tag} eq $value;
}
sub name   {
    my ($self, $value) = @_;
    return $self->{name} if not defined $value;
    $self->{name} eq $value;
}
sub string { $_[0]->{string} }
sub level  { $_[0]->{level} }
sub docid  { $_[0]->{docid} }
sub parent { $_[0]->{parent} }
sub warnings { @{$_[0]->{warnings}} }

sub inparm { $_[0]->{inparms}->{$_[1]} }
sub exparm { $_[0]->{exparms}->{$_[1]} }
sub inparm_n { $_[0]->{inparm_list}->[$_[1]] }
sub exparm_n { $_[0]->{exparm_list}->[$_[1]] }

sub children { @{$_[0]->{children}} }

=head1 LOCATION

Each tag knows its location within its document.

=head2 path

Returns the path locator of the tag within the document.

=cut

sub path {
    my $self = shift;
    if (not $self->parent) {
        return ''; #$self->tag;  # TODO: This is an oversimplification to get things off the ground.
    }
    return $self->parent->path . '.' . $self->tag;
}

=head2 location

This is the path with the docid in front.

=cut

sub location { '<' . $_[0]->docid . '>.' . $_[0]->path }

=head1 FINDING THINGS

Basic searches for elements in a tree returns either the first item that matches the search terms, or a list of them.
A search can also be limited by depth.
We can search on each of the elements in tags using a hashref passed in:

  {
     tag => 'literal', tag => /match/,
     name => 'literal', name => /match/,
     string => 'literal', string => /match/,
     inparm => 'literal', inparm => [name, value], inparm => [name, /match/],
     exparm => 'literal', exparm => [name, value], exparm => [name, /match/],
     depth => x
  }

Text and code content are not searchable (not yet, anyway) because they're hardly even implemented. The depth is optional and trims
the search if it's multi-level.

All these match as "and" - you can also specify a sub-or with:
  {
     or => { tag => 'literal', tag => 'literal'},
  }

=head2 match (match), match_or (match), match_not (match), match_nor (match)

Tests the current tag for equality with a match structure as shown above. The 'depth' specification is ignored.

=cut

sub match {
    my ($self, $match) = @_;
    my $r;
    return 0 unless ref($match) eq 'HASH';
    foreach my $e (['tag', \&tag],
                   ['name', \&name],
                   ['string', \&string],
                  ) {
        my ($thing, $get) = @$e;
        if (defined $match->{$thing}) {
            $r = ref($match->{$thing});
            return 0 if not $r and $match->{$thing} ne $get->($self);
            return 0 if $r eq 'Regexp' and $get->($self) !~ $match->{$thing};
        }
    }
    foreach my $e (['inparm', \&inparm],
                   ['exparm', \&exparm],
                  ) {
        my ($thing, $get) = @$e;
        if (defined $match->{$thing}) {
            $r = ref($match->{$thing});
            return 0 if not $r and not $get->($self, $match->{$thing});
            if ($r eq 'ARRAY') {
                my $value = $get->($self, $match->{$thing}->[0]);
                $r = ref($match->{$thing}->[1]);
                return 0 if not $r and $match->{$thing}->[1] ne $value;
                return 0 if $r eq 'Regexp' and $value !~ $match->{$thing}->[1];
            }
        }
    }
    if (defined $match->{or}) {
        return 0 unless $self->match_or ($match->{or});
    }
    return 1;
}
sub match_or {
    my ($self, $match) = @_;
    my $r;
    return 0 unless ref($match) eq 'HASH';
    foreach my $e (['tag', \&tag],
                   ['name', \&name],
                   ['string', \&string],
                  ) {
        my ($thing, $get) = @$_;
        if (defined $match->{$thing}) {
            $r = ref($match->{$thing});
            return 1 if not $r and $match->{$thing} eq $get->($self);
            return 1 if $r eq 'Regexp' and $get->($self) =~ $match->{$thing};
        }
    }
    foreach my $e (['inparm', \&inparm],
                   ['exparm', \&exparm],
                  ) {
        my ($thing, $get) = @$_;
        if (defined $match->{$thing}) {
            $r = ref($match->{$thing});
            return 1 if not $r and $get->($self, $match->{$thing});
            if ($r eq 'ARRAY') {
                my $value = $get->($self, $match->{$thing}->[0]);
                $r = ref($match->{$thing}->[1]);
                return 1 if not $r and $match->{$thing}->[1] eq $value;
                return 1 if $r eq 'Regexp' and $value =~ $match->{$thing}->[1];
            }
        }
    }
    if (defined $match->{and}) {
        return 1 if $self->match ($match->{and});
    }
    return 0;
}
sub match_not { return not $_[0]->match($_[1]); }
sub match_nor { return not $_[0]->match_or($_[1]); }


=head2 first (match, depth)

Finds the first descendant of the current tag that matches. Specify a depth if only e.g. the current tag's immediate children
should be searched (depth => 1). Depth can either be specified in the match or as an argument; if an argument, it will take
precedence over the match structure.

=cut

sub first {
    my ($self, $match, $depth) = @_;
    return undef unless ref $match eq 'HASH';
    $depth = $match->{depth} if not defined $depth;
    foreach my $child ($self->children) {
        my $check = $child->match($match);
        return $child if $check;
        next if defined $depth and $depth == 0;
        $check = $child->first($match, defined $depth ? $depth - 1 : undef);
        return $check if $check;
    }
    return undef;
}

=head2 all (match)

Returns a list of all descendants of the current tag that match. If 'depth' is specified it trims the levels of search; a depth of 0
returns an empty list, but a depth of undef is simply unrestricted. This is a quick-and-dirty way to get matching tags; if you have
a larger structure or need more information about each tag along the way, consider a walk.

=cut

sub all {
    my ($self, $match, $depth) = @_;
    my @return = ();
    return @return unless ref $match eq 'HASH';
    $depth = $match->{depth} if not defined $depth;
    foreach my $child ($self->children) {
        my $check = $child->match($match);
        push @return, $child if $check;
        next if defined $depth and $depth == 0;
        push @return, $child->all($match, defined $depth ? $depth - 1 : undef);
    }
    return @return;
}


=head1 WALKING THE TREE

The other way to work with trees is to walk them. This can be used to transform the tree or simply to deliver a list of results.

=head2 

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
