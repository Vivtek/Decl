package Decl::Syntax;

use 5.006;
use strict;
use warnings;
use Text::Tokenize::Indented;
use Iterator::Simple;
use Data::Dumper;
use Carp;

=head1 NAME

Decl::Syntax - Represents a syntactic node in a Decl structure

=head1 VERSION

Version 0.20

=cut

our $VERSION = '0.20';


=head1 SYNOPSIS

Since one of the core goals of Decl is homoiconicity, this module is both its
parser and its code output generator; a Decl::Syntax module represents a Decl
syntactic node.

Some things are already defined at the syntactic level in Decl, so a Decl::Syntax
object does know whether it's a tag, text, code expression, or whitespace/comment.
But beyond that, most meaning is assigned at the semantic level. What this means
in practice will have to wait until there's some practice.

Specific types of syntactic node are subclassed from Syntax, so we have e.g.
Decl::Syntax::Tag, Decl::Syntax::Text, and so on.  The different types of syntactic
node are tag, text, comment, X, S, code, transclusion, template, ... I think that's it.

=head1 CREATION AND LOADING

=head2 new

Creates a blank node that contains no syntax. If a string or an arrayref of lines
is passed, parses it so that we I<do> contain some syntax.  The node knows
its parent and (optionally) the parsing environment as well.  C<load> is used to
add text to a syntactic node, and can be either a string, an array of strings,
or an array of arrayrefs, each of which contains an indentation and a string.

=cut

sub new {
    my $class = shift;
    my $self = bless shift, ref $class ? ref $class : $class;
    $self->{children} = [];
    $self->{parent} = $class if ref $class;
    $self->{handler} = $self->find_handler;
    $self->{handler}->{start}->($self) if defined $self->{handler}->{start};
    $self;
}

sub _unpack { # Build a string from indentation tokens.
    my $indent = shift;
    my $string = '';
    foreach (@_) {
        if ($_->[0] < 0) {
            $string .= "\n";
            next;
        }
        my ($i, $text) = @$_;
        $string .= ' ' x ($i-$indent) . $text . "\n";
    }
    $string;
}

=head2 load

Loading accepts anything that L<Text::Tokenize::Indented> can treat as a set
of iterable lines.

=cut

sub load {
    my $class = shift;
    my $source = shift;
    my $mode = shift || 'tag';
    if (not ref $source) {
        return $class->load({type=>'file', file=>$source}, $mode);
    } elsif (ref $source eq 'SCALAR') {
        return $class->load({type=>'string', string=>$$source}, $mode);
    } elsif (ref $source ne 'HASH') {
        return $class->load({type=>'iter', iter=>$source}, $mode);
    }
    
    my $self;
    my $input;
    if ($source->{type} eq 'file') {
        open my $input, '<', $source->{file} or croak "Can't open '" . $source->{file} . "': $!";

        $self = $class->new({
            what=>'source',
            type=>'file',
            mode=>$mode,
            file=>$source->{file},
            current_input=>$self,
            blank_lines=>0,
            indent=>-1,
            post_indent=>0,
        });
        $self->_load ($input);
    } elsif ($source->{type} eq 'string') {
        $self = $class->new({
            what=>'source',
            type=>'string',
            mode=>$mode,
            current_input=>$self,
            blank_lines=>0,
            indent=>-1,
            post_indent=>0,
        });
        $self->_load ($source->{string});
    } elsif ($source->{type} eq 'iter') {
        $self = $class->new({
            what=>'source',
            type=>'iterator',
            mode=>$mode,
            current_input=>$self,
            blank_lines=>0,
            indent=>-1,
            post_indent=>0,
        });
        $self->_load ($source->{iter});
    } else {
        croak "I don't know how to load a " . $source->{type};
    }
    $self;
}

sub mode { $_[0]->{mode} || $_[0]->{what} || 'tag' }
        

sub _load {
    my $self = shift;
    my $input;
    if (@_ > 1 or $self->{type} eq 'iterator' or not Iterator::Simple::is_iterator($_[0])) {
        $input = Text::Tokenize::Indented->tokenize(@_);
    } else {
        $input = shift;
    }

    my $lineno = 0;
    while (1) {
        my $line = $input->();
        return unless defined $line;
        $lineno++;
        $self->_add_line ($line, $lineno);
    }
}

sub _add_line { # _add_line is always going to be called against the source node.
    my $self = shift;
    my $line = shift;
    my $lineno = shift;
    my ($indent, $text) = @$line;

    # Blank? Stash it for later.    
    if ($indent < 0) {
        $self->{blank_lines}++;
        return;
    }

    # TTI doesn't chomp unindented lines (TODO: fix that)
    chomp $text if defined $text and $text =~ /\n$/m;
    
    # If we have a current node consuming, give it first crack.
    TRY_AGAIN:
    $self->{current_input} = $self unless defined $self->{current_input};
    if ($self->{current_input}->_accept_line($indent, $text, $lineno, $self->{blank_lines})) {
        $self->{blank_lines} = 0;
        return;
    } else { # No? Then work up the tree.
        croak "Couldn't accept line" if $self->{current_input} == $self;
        $self->{current_input} = $self->{current_input}->{parent};
        goto TRY_AGAIN;
    }
}




=head1 LINE TOKENIZATION

=cut

sub find_initial {
    my ($self, $text) = @_;

    my ($initial, $post_indent, $rest);
    if ($text =~ /^([^\s:{\[<\(]+)(\s*)([\s:{\[<\(].*)$/) {
        $initial = $1;
        $post_indent = length($2) + length($initial);
        $rest = $3;
        if ($rest =~ /^(\s+)(.*)$/) {
            $post_indent += length($1);
            $rest = $2;
        }
        return ($initial, $post_indent, $rest);
    } elsif ($text =~ /^(\[[^\]]*\])(\s*)([\s:{\[<\(].*)$/) {
        $initial = $1;
        $post_indent = length($2) + length($initial);
        $rest = $3;
        if ($rest =~ /^(\s+)(.*)$/) {
            $post_indent += length($1);
            $rest = $2;
        }
        return ($initial, $post_indent, $rest);
    } elsif ($text =~ /^(<[^>]*>)(\s*)([\s:{\[<\(].*)$/) {
        $initial = $1;
        $post_indent = length($2) + length($initial);
        $rest = $3;
        if ($rest =~ /^(\s+)(.*)$/) {
            $post_indent += length($1);
            $rest = $2;
        }
        return ($initial, $post_indent, $rest);
    } elsif ($text =~ /^([^\s:{\[<\(]+)(\s*)$/) {
        # Tag on a line alone
        return ($text, 0, '');
    } else {
        # Anonymous sigil - treat this as a line with a blank tag.
        return ('', 0, $text);
    }
    return ($initial, $post_indent, $rest);
}

sub tag_starter {
    my $self = shift;
    
    # Here, we parse the line for the tag to produce the parameter list.
    # Parameter types are: '' for name, '"' or "'" for string, ')' or ']' for closed option lists,
    #                      '{', '<', '(', '[' for code sigils (the first two could be closed blocks),
    #                       ':' for sigil, '.' for post-sigil text, and '#' for comment.
    # Each parameter also has its line offset (just in case we ever want to do vertical alignment).
    # White space between parameters is reflected only in the line offsets.
    # The form of each token is thus [99, 99, 'x', 'string'], where the two numbers are the offset and
    # length of the token content, 'x' is the one-character type (empty for a bareword), and the 'string'
    # is the token content itself, still unprocessed.
    my @tokens = toktag ($self->{line});
    #print STDERR Dumper (@tokens);
    
    # In the second pass, each type of token can have its own post-processing done, again in priority order.
    # 1. '#', code sigils, and text remainders (anything that does 'rest of the line') have quoted content restored.
    # 2. Remaining strings are de-escaped.
    # 3. Code sigils are checked for closure and are converted to code blocks if they are closed on the line.
    # 4. Closed option lists are subdivided by commas, and their subdivisions are subdivided by equals signs
    #    to produce key-value pairs. Any embedded quotes are then restored to the lowest-level tokens.
    $self->{parmtoks} = [tokpost (@tokens)];

    # Some tags contain text, so we don't know our body indentation yet if that's the case.
    $self->{bodyindent} = 0;
    $self->{children} = [];
    $self->{lines} = [];

    # Finally, now that we've parsed the tag line, we use the sigil and the body map provided by the
    # handler to set the bodymode for the tag's content (if any).
    $self->{bodymode} = 'tag'; # Default.
    $self->{hastext} = 0;
    $self->{hascode} = '';
    $self->{post_sigil} = 0;

    my $linecode = $self->linecode;
    if ($linecode) {
        my $type = $self->linecodetype;
        $type =~ tr/>}\)\]/<{\(\[/;
        $self->{hascode} = $type;
        $self->{code} = [$linecode];
        return;
    }

    return unless $self->{handler};
    return unless $self->{handler}->{mbody};
    my $mbody = $self->{handler}->{mbody};
    my $sigil = $self->sigil;
    if (defined $self->{handler}->{mterm} and defined $self->{handler}->{mterm}->{$sigil}) {
        $self->{mterm} = $self->{handler}->{mterm}->{$sigil};
    }
    my $map = $mbody->{$sigil};
    #print STDERR "sigil is $sigil, map is $map\n";
    #print STDERR Dumper($self->{parmtoks});
    if (defined $map) {
        $self->{sigil} = $sigil;
        $self->{bodymode} = $map;
        $self->_handle_postsigil;
        return;
    }
    return unless length $sigil > 1;
    my @schars = split //, $sigil;
    my $sstart = shift @schars;
    foreach my $srest (@schars) {
        $map = $mbody->{$sstart . $srest};
        if (defined $map) {
            $self->{sigil} = $sstart . $srest;
            $self->{bodymode} = $map;
            $self->_handle_postsigil;
            return;
        }
        last if $srest eq '?';
    }
}

sub _handle_postsigil {  # Deal with text appearing on the line after the sigil, for text-type bodies.
    my $self = shift;

    my @p = $self->parameters ('.');
    #print STDERR Dumper($self->{parmtoks});
    #print STDERR Dumper(\@p);
    return unless @p;

    my $p = shift @p;
    return if $p->[0] eq '';
    $self->{post_sigil} = $self->{indent} + $p->[2];
    $self->{lines} = [$p->[0]];
    $self->{bodyindent} = 0;
    if ($self->{bodymode} eq 'code') {
        $self->{hascode} = $self->linecodetype;
    } else {
        $self->{hastext} = 1;
    }
}

sub tokdebug {
    my $tok = shift;
    my $ret = '';
    foreach my $t (@$tok) {
        if (ref $t->[3] eq 'ARRAY') {
            $ret .= sprintf "%2d %2d %1s\n", @$t;
            foreach my $tt (@{$t->[3]}) {
                if (ref $tt->[3] eq 'ARRAY') {
                    $ret .= sprintf "      %2d %2d %1s\n", @$tt;
                    foreach my $ttt (@{$tt->[3]}) {
                        $ret .= sprintf "            %2d %2d %1s %s\n", @$ttt;
                    }
                } else {
                    $ret .= sprintf "      %2d %2d %1s %s\n", @$tt;
                }
            }
        } else {
            $ret .= sprintf "%2d %2d %1s %s\n", @$t;
        }
    }
    $ret;
}

sub tokpost {
    my @final = ();
    my $t = shift @_;
    while (defined $t) {
        # Put quote and paren tokens back into end-of-line tokens that contain them
        if (@_ and ($t->[2] eq '{' || $t->[2] eq '<' || $t->[2] eq '(' || $t->[2] eq '[' || $t->[2] eq '#' || $t->[2] eq '.')) {
            my $offset = 1;
            $offset = 0 if $t->[2] eq '.';
            while (@_ and ($_[0]->[2] eq '"' or $_[0]->[2] eq "'" or $_[0]->[2] eq ")" or $_[0]->[2] eq "]")
                      and $_[0]->[0] + $_[0]->[1] <= $t->[0] + $t->[1]) {
                my $string = shift @_;
                my $start = $string->[0] - $t->[0];
                substr($t->[3], $start-$offset, 1) = $string->[2] eq ')' ? '(' : $string->[2] eq ']' ? '[' : $string->[2];
                substr($t->[3], $start-$offset + $string->[1]+1, 1) = $string->[2];
                substr($t->[3], $start-$offset+1, $string->[1]) = $string->[3];
            }
        }
        
        # De-escape quote tokens.
        if ($t->[2] eq '"' or $t->[2] eq "'") {
            $t->[3] =~ s/\\(['"])/$1/g;
            $t->[3] =~ s/\\\\/\\/g;
            $t->[3] =~ s/\\n/\n/g;
            $t->[3] =~ s/\\t/\t/g;
        }
        
        # Convert closed code blocks from sigiled text to block text.
        if ($t->[2] eq '{' or $t->[2] eq '<') {
            my $match = '}';
            $match = '>' if $t->[2] eq '<';
            if ($t->[3] =~ s/$match$//) {
                $t->[2] = $match;
            }
        }
        
        # Do sub-parsing of closed paren and bracket blocks
        if ($t->[2] eq ')' or $t->[2] eq ']') {
            my @parts = ();
            my $indent = 0;
            foreach my $p (split /,/, $t->[3]) {
                my ($key, $value) = split /=/, $p, 2;
                if (not defined $value) {
                    my $indinc = length ($p) + 1;
                    my $myind = $t->[0] + $indent;
                    $p =~ s/ *$//;
                    if ($p =~ s/^( +)//) {
                        $myind += length($1);
                    }
                    push @parts, [$myind, length($p), '', $p];
                    $indent += $indinc;
                } else {
                    my $keyind = $t->[0] + $indent;
                    my $valind = $t->[0] + $indent + length($key) + 1;
                    $key =~ s/ *$//;
                    $value =~ s/ *$//;
                    if ($key =~ s/^( +)//) {
                        $keyind += length($1);
                    }
                    if ($value =~ s/^( +)//) {
                        $valind += length($1);
                    }
                    push @parts, [$t->[0] + $indent, length($p), '=', [
                       [$keyind, length($key),   '', $key],
                       [$valind, length($value), '', $value]
                    ]];
                    $indent += length ($p) + 1;
                }
            }
            $t->[3] = \@parts;
            
            # Put quoted values back into the value tree if there are any
            while (@_ and ($_[0]->[2] eq '"' or $_[0]->[2] eq "'")
                      and $_[0]->[0] + $_[0]->[1] <= $t->[0] + $t->[1]) {
                my $string = shift @_;
                foreach my $p (reverse @{$t->[3]}) {
                    if ($p->[0] <= $string->[0]) { # this value contains the quoted token
                        my $target = $p;
                        if ($target->[2]) { # key/value pair
                            my $kvp = $target->[3];
                            $target = $kvp->[1];
                            if ($target->[0] > $string->[0]) { # value does not contain quoted token
                                $target = $kvp->[0];
                            }
                        }
                        # Now $target is pointing to the bare parameter, key, or value that contains the quote.
                        if ($target->[1] == 0) { # if there was nothing *but* the quote,
                            $target->[0] = $string->[0];
                            $target->[1] = $string->[1];
                            $target->[2] = $string->[2];
                            $target->[3] = $string->[3]; # take its identity!
                        } else {
                            # merge the value with the quote in the normal manner, except we have to escape it.
                            # Also, no offset, since none of our tokens contains a delimiter.
                            my $start = $string->[0] - $target->[0];
                            my $value = $string->[3];
                            $value =~ s/($string->[2])/\\$1/g;
                            $value =~ s/\\/\\\\/g;
                            $value =~ s/\n/\\n/g;
                            $value =~ s/\t/\\t/g;
                            substr($target->[3], $start, 1) = $string->[2];
                            substr($target->[3], $start + $string->[1]+1, 1) = $string->[2];
                            substr($target->[3], $start+1, $string->[1]) = $string->[3];
                        }
                        last; # Skip the rest of the tokens in the parameters, of course.
                    }
                }
            }
        }
        
        push @final, $t;
        $t = shift @_;
    }
    @final;
}
    
sub toktag {
    my $text = shift || '';
    
    my @toks = ();
    my @line = split /('(?:\\.|[^'])*'|\"(?:\\.|[^\"])*\")/, $text;
    $text = '';
    my $indent = 0;
    foreach my $t (@line) {
        my $first = substr($t,0,1);
        if ($first eq '"' or $first eq "'") {
            push @toks, [$indent, length($t)-2, $first, substr($t, 1, -1)];
            $text .= ' ' x length($t);
            $indent += length($t);
        } else {
            $text .= $t;
            $indent += length($t);
        }
    }
    
    my $sigil;
    my @bits;
    my $line;
    my $comment;
    
    ($line, $sigil, @bits) = split /(:[[:punct:]]* *)/, $text, 3;
    if (defined $sigil) {
        my $comment = join('', @bits);
        my $slen = length($sigil);
        $sigil =~ s/ *$//;
        push @toks, [length($line),       length($sigil)-1,  ':', substr($sigil,1)];
        push @toks, [length($line)+$slen, length ($comment), '.', $comment];
        $line =~ s/ *$//;
        $text = $line;
    }

    
    ($line, $comment) = split /#/, $text;
    if (defined $comment) {
        push @toks, [length($line), length($comment), '#', $comment];
        $line =~ s/ *$//;
        $text = $line;
    }
    
    # Enclosing option parens/brackets come next.
    @line = split /(\([^\)]*\)|\[[^\]]*\])/, $text;
    $text = '';
    $indent = 0;
    foreach my $t (@line) {
        my $first = substr($t,0,1);
        my $last = substr($t,-1,1);
        if (($first eq '(' and $last eq ')') or ($first eq '[' and $last eq ']')) {
            push @toks, [$indent, length($t)-2, $first eq '(' ? ')' : ']', substr($t, 1, -1)];
            $text .= ' ' x length($t);
            $indent += length($t);
        } else {
            $text .= $t;
            $indent += length($t);
        }
    }

    # A code sigil without a matching end can only occur once on the line, and has to be final.
    # Matched parens/brackets will be taken for options, matched curly and angle brackets can appear on the line.
    ($line, $sigil, @bits) = split /({|<|\[|\()/, $text, 3;
    if (defined $sigil) {
        my $comment = join('', @bits);
        push @toks, [length($line), length($comment), $sigil, $comment];
        $line =~ s/ *$//;
        $text = $line;
    }
    
    # Everything else, my dear, is a bareword.
    @line = split /( +)/, $text;
    $indent = 0;
    foreach my $t (@line) {
        push @toks, [$indent, length($t), '', $t] unless $t =~ m/ /;
        $indent += length ($t);
    }

    sort { $a->[0] <=> $b->[0] } @toks;
}

=head2 HANDLERS

=cut

sub normal_indent_handler {
    my ($self, $indent, $text) = @_;
    return 1 if $self->{mterm} and $indent == $self->{indent} and substr ($text,0,1) eq $self->{mterm};
    $indent > $self->{indent};
}

sub comment_starter {
    my ($self) = @_;

    if ($self->{indent} < 0) {
        $self->{lines} = [];
    } else {
        $self->{lines} = [$self->{line}];
        $self->{line} = '';
    }
}
    
sub comment_line_handler {
    my ($self, $indent, $text, $lineno, $blanks) = @_;

    # Let's stash this line, then.
    while ($blanks) {
        push @{$self->{lines}}, '';
        $blanks--;
    }
    $indent -= $self->{indent} + $self->{post_indent};
    $indent = 0 if $indent < 0;
    push @{$self->{lines}}, ' ' x $indent . $text;
}
sub textplus_starter {
    my $self = shift;

    if ($self->{indent} < 0) {
        $self->{children} = [];
    } else {
        $self->{children} = [[$self->{line}]];
        $self->{line} = '';
    }
}


sub textplus_line_handler {
    my ($self, $indent, $text, $lineno, $blanks) = @_;

    my ($initial, $post_indent, $rest) = $self->find_initial($text);
    my ($line_type, $tag) = $self->_identify_line($initial);

    # Find last thing in children list
    my $last = $self->{children}->[-1];
    
    # If text has to go into the last child, make sure it's a text child
    if (ref $last ne 'ARRAY' and ($blanks or not $line_type)) {
        $last = [];
        push @{$self->{children}}, $last;
    }

    # Stash any blank lines that need to go into text storage.
    while ($blanks) {
        push @$last, '';
        $blanks--;
    }
    
    # If our line type is a non-text line type, then let's build that puppy.
    if ($line_type) {
        # Where's the root of the tree?
        my $root = $self->{root};
        $root = $self unless defined $root;

        # Make that a new tag, with the root the parent.
        my $new_thing = $self->new({
            what=>$line_type,
            tag=>$tag,
            indent=>$indent,
            post_indent=>$post_indent,
            line=>$rest,
            root=>$root,
            lineno=>$lineno
        });
        push @{$self->{children}}, $new_thing;
        $root->{current_input} = $new_thing;
    } else {
        # Normalize indentation, just in case.
        $indent -= $self->{indent} < 0 ? 0 : $self->{indent};
        $indent += $self->{post_indent};
        $indent = 0 if $indent < 0;
        push @$last, ' ' x $indent . $text;
   }

}

sub text_line_handler {
    my ($self, $indent, $text, $lineno, $blanks) = @_;

    if ($self->{bodyindent} == 0 and $self->{post_sigil} <= $indent) {
        $self->{bodyindent} = $self->{post_sigil};
    } elsif ($self->{bodyindent} == 0 and $self->{post_sigil} > 0) {
        $self->{bodyindent} = $indent;
        $self->{lines}->[0] = ($self->{post_sigil} - $indent) x ' ' . $self->{lines}->[0];
    }
    if (not @{$self->{lines}}) {
        $self->{bodyindent} = $indent;
    }
    while ($blanks) {
        push @{$self->{lines}}, '';
        $blanks--;
    }
    $indent -= $self->{indent} + $self->{bodyindent};
    $indent = 0 if $indent < 0;
    push @{$self->{lines}}, ' ' x $indent . $text;
    $self->{hastext} = 1;
}

sub code_line_handler {
    my ($self, $indent, $text, $lineno, $blanks) = @_;

    if ($self->{bodyindent} == 0 and $self->{post_sigil} <= $indent) {
        $self->{bodyindent} = $self->{post_sigil};
    } elsif ($self->{bodyindent} == 0 and $self->{post_sigil} > 0) {
        $self->{bodyindent} = $indent;
        $self->{lines}->[0] = ($self->{post_sigil} - $indent) x ' ' . $self->{lines}->[0];
    }
    if (not @{$self->{lines}}) {
        $self->{bodyindent} = $indent;
    }
    while ($blanks) {
        push @{$self->{lines}}, '';
        $blanks--;
    }
    $indent -= $self->{indent} + $self->{bodyindent};
    if ($indent < 0 and $self->{mterm} and substr($text,0,1) eq $self->{mterm}) {
        $self->{codeterm} = $text;
        $self->{bodymode} = 'tag';
    } else {
        $indent = 0 if $indent < 0;
        push @{$self->{lines}}, ' ' x $indent . $text;
        $self->{hascode} = $self->sigil unless $self->{hascode};
    }
}

sub ttag_line_handler {
    my ($self, $indent, $text, $lineno, $blanks) = @_;

    if (not @{$self->{lines}}) {
        $self->{bodyindent} = $indent;
    } elsif ($blanks) {
        $self->{bodymode} = 'tag';
        return tag_line_handler (@_);
    }
    while ($blanks) {  # There can be blanks before the first line of text, but not thereafter.
        push @{$self->{lines}}, '';
        $blanks--;
    }
    $indent -= $self->{indent} + $self->{bodyindent};
    $indent = 0 if $indent < 0;
    push @{$self->{lines}}, ' ' x $indent . $text;
    $self->{hastext} = 1;
}

sub tag_line_handler {
    my ($self, $indent, $text, $lineno, $blanks) = @_;

    # Do we have an alternate body mode in force? Hand off to the appropriate handler if so.
    return text_line_handler(@_)     if $self->{bodymode} eq 'text';
    return code_line_handler(@_)     if $self->{bodymode} eq 'code';
    return ttag_line_handler(@_)     if $self->{bodymode} eq 'ttag';
    return textplus_line_handler(@_) if $self->{bodymode} eq 'textplus';

    # Source or tag:
    # We've got a vanilla line (we're in tag mode). Find the tag.
    my ($initial, $post_indent, $rest) = $self->find_initial($text);
    
    # Find the line type from that.
    my ($line_type, $tag) = $self->_identify_line($initial);
    
    # Where's the root of the tree?
    my $root = $self->{root};
    $root = $self unless defined $root;

    # Make that a new tag, with the root the parent.
    my $new_thing = $self->new({
        what=>$line_type,
        tag=>$tag,
        indent=>$indent,
        post_indent=>$post_indent,
        line=>$rest,
        root=>$root,
        lineno=>$lineno
    });
    push @{$self->{children}}, $new_thing;
    $root->{current_input} = $new_thing;
}

our $handlers = {
    comment => {
        start  => \&comment_starter,
        indent => \&normal_indent_handler,
        line   => \&comment_line_handler,
    },
    tag => {
        start  => \&tag_starter,
        indent => \&normal_indent_handler,
        line   => \&tag_line_handler,
        mline  => { '#' => 'comment',
                    ''  => 'tag',
                  },
        mbody  => { ':'  => 'text',
                    '{'  => 'code',
                    '<'  => 'code',
                    '('  => 'code',
                    '['  => 'code',
                    ':~' => 'ttag',
                    ':#' => 'ttag',
                    ':+' => 'textplus',
                  },
        mterm => {
                    '{' => '}',
                    '(' => ')',
                    '[' => ']',
                    '<' => '>',
                 },
    },
    textplus => {
        start  => \&textplus_starter,
        indent => \&normal_indent_handler,
        line   => \&textplus_line_handler,
        mline  => { '#' => 'textplus',
                    '-' => 'textplus',
                    '~' => 'textplus',
                    '+' => 'textplus',
                    ':' => 'textplus',
                    '"' => 'textplus',
                  },
        flags  => {
                    '+' => ['tag', 1],
                  },
    }
};

sub find_handler {
    my $self = shift;
    my $handler = $handlers->{$self->mode} || $handlers->{tag};
}
sub handler {
    my $self = shift;
    return $self->{handler} if defined $self->{handler};
    $self->{handler} = $self->find_handler;
}

sub _accept_line {
    my ($self, $indent, $text, $lineno, $blanks) = @_;
    return 0 unless $self->handler->{indent}->($self, $indent, $text);
    return $self->handler->{line}->(@_);
}

# This will work from the context - for now it's just dumb, though.
sub _identify_line {
    my ($self, $tag) = @_;
    my $handler = $self->handler;
    FLAG_INDIRECTION:
    my $flag = $handler->{flags}->{substr($tag,0,1)};
    my $line_type = '';
    if (defined $flag) {
        $line_type = $flag->[0];
        if ($flag->[1] == 1) {
            $tag = substr($tag,1);
        }
        # Now we exercise the flag escape.
        $handler = $handlers->{$line_type} or die "flag " . $flag->[0] . " points to a non-existent handler";
        goto FLAG_INDIRECTION;
    }
    $line_type = $handler->{mline}->{$tag};
    return ($line_type, $tag, $handler->{mbody}) if defined $line_type;
    $line_type = $handler->{mline}->{''};
    return ($line_type, $tag, $handler->{mbody}) if defined $line_type;
    return ('', $tag, $handler->{mbody});
}

=head1 ACCESS

Here is where we have different ways of extracting information from a syntax structure.

=cut

sub dump_tree {
    my $self = shift;
    my $ret;
    if ($self->{what} eq 'source') {
        $ret = sprintf "Source: %s\n", $self->{file} ? $self->{file} : '<string>';
    } else {
        $ret = sprintf "%03d %s%s %s\n", $self->{lineno}, ' ' x $self->{indent}, $self->{what}, $self->{what} eq 'tag'? $self->{tag} : '';
    }
    foreach my $child (@{$self->{children}}) {
        $ret .= $child->dump_tree();
    }
    $ret;
}

sub debug_tree {
    my $self = shift;
    my $ret;
    
    if ($self->{what} eq 'source') {
        $ret = sprintf "Source: %s\n", $self->{file} ? $self->{file} : "<string>";
        $ret .= $self->extract_comment_text;
    } else {
        $ret = sprintf "Line %d: %s %s indented %d,%d\n", $self->{lineno}, $self->{what}, $self->{tag}, $self->{indent}, $self->{post_indent};

        if ($self->{what} eq 'comment') {
            $ret .= $self->extract_comment_text;
            $ret .= "\n";
        } else {
            $ret .= sprintf "  Text: %s\n", $self->{line};
        }
    }
    foreach my $child (@{$self->{children}}) {
        if (ref $child eq 'ARRAY') {
            $ret .= "(text)\n";
        } else {
            $ret .= $child->debug_tree();
        }
    }
    $ret;
}

sub extract_comment_text {
    my $self = shift;
    return '' unless defined $self->{lines};
    join ("\n", @{$self->{lines}}) . "\n";
}

=head2 sigil

Looks at parmtoks to get a tag's sigil.

=cut

sub sigil {
    my $self = shift;
    return '' unless $self->{parmtoks};
    _sigil ($self->{parmtoks}, @_);
}

sub _sigil {
    my $toks = shift;
    my $sigil = shift;
    foreach my $p (@$toks) {
        next unless $p->[2] =~ /[:\[\{\(\<]/;
        if ($sigil) {
            return $sigil eq $p->[2];
        }
        return $p->[2] . $p->[3] if $p->[2] eq ':';
        return $p->[2];
    }
    return '';
}

=head2 parameters

Returns a list of parameter specifications: name, flavor, and value for each. There are seven flavors
of parameter: "')]}> and barewords; the string flavors are "named" by their string quote " or ', and the code flavors
are "named" by their closing sigil } or >. The names of ) and ] parameters are those specified; if they
appear only as names (like 'x' in [x,y=1]) then the value is undef. Finally, barewords are "named" as the word,
with a flavor of '' and a value of undef.

If a parameter is specified, it will be treated as a flavor, and only parameters of that flavor
will be returned.

=cut

sub parameters {
    my $self = shift;
    #return @{$self->{parameters}} if defined $self->{parameters};
    return () unless $self->{parmtoks};
    _parameters ($self->{parmtoks}, @_);
    #$self->{parameters} = \@p;
    #@p;
}
sub _parameters {
    my $toks = shift;
    my $flavor = shift;
    my @ret = ();
    foreach my $p (@$toks) {
        if ($p->[2] =~ /['"\}\>]/ ) {
            push @ret, [$p->[2], $p->[2], $p->[3]] if not defined $flavor or $flavor eq $p->[2];
        } elsif ($p->[2] =~ /[\]\)]/) {
            foreach my $pp (@{$p->[3]}) {
                if ($pp->[2] eq '=') {
                    push @ret, [$pp->[3]->[0]->[3], $p->[2], defined ($pp->[3]->[1]) ? $pp->[3]->[1]->[3] : ''] if not defined $flavor or $flavor eq $p->[2];
                } else {
                    push @ret, [$pp->[3], $p->[2], undef] if not defined $flavor or $flavor eq $p->[2];
                }
            }
        } else {
            push @ret, [$p->[3], $p->[2], $p->[2] eq '.' ? $p->[0] : undef] if not defined $flavor or $flavor eq $p->[2];
        }
    }
    @ret;
}

=head2 parmnames

Returns a list of the parameters specified in the parmtoks structure, or those of a given flavor.

=cut

sub parmnames {
    my $self = shift;
    map { $_->[0] } $self->parameters(@_);
}

=head2 getparm

Returns the value of the first parameter that has the name specified. You want more power, you
can always look at the parameters structure directly, but usually this won't be necessary.

=cut

sub getparm {
    my $self = shift;
    my $parameter = shift;
    foreach my $p ($self->parameters) {
        return $p->[2] if $p->[0] eq $parameter;
    }
    return;
}

=head2 linecode

Returns the value of the first } or > parameter (there can only be one with the standard tokenizer,
but hey)

=cut

sub linecode {
    my $self = shift;
    foreach my $p ($self->parameters) {
        return $p->[2] if $p->[0] eq '>' or $p->[0] eq '}';
    }
    return;
}

=head2 linecodetype

Returns the flavor of the code parameter.

=cut

sub linecodetype {
    my $self = shift;
    foreach my $p ($self->parameters) {
        return $p->[0] if $p->[0] eq '>' or $p->[0] eq '}';
    }
    return;
}

=head2 hastext, hascode, haschildren

Checks for the presence of various bits and pieces of tags.

=cut

sub hastext { $_[0]->{hastext}; }
sub hascode { $_[0]->{hascode}; }
sub haschildren { scalar @{$_[0]->{children}}; }

=head2 tag, gettext, getcode, children

Actually retrieve the parts of the tag named.

=cut

sub tag { $_[0]->{tag}}
sub gettext {
    my $self = shift;
    return unless $self->hastext;
    join "\n", @{$self->{lines}};
}
sub getcode {
    my $self = shift;
    return unless $self->hascode;
    join "\n", @{$self->{lines}};
}

sub children { @{$_[0]->{children}}; }

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

1; # End of Decl::Syntax
