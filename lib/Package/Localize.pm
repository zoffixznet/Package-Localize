package Package::Localize;

use strict;
use warnings;

# VERSION

use Data::GUID;
use List::AllUtils qw/uniq/;
use Package::Stash;
use Data::COW;

sub new {
    my $class = shift;
    my $module = shift;

    eval "require $module";
    my $id = Data::GUID->new->as_hex;
    my $root_stash   = Package::Stash->new($module);
    my $handle_stash = Package::Stash->new($module . '::' . $id );

    my $sym = $root_stash->get_all_symbols('CODE');
    $handle_stash->add_symbol('&' . $_, $sym->{$_} ) for keys %$sym;

    $sym = $root_stash->get_all_symbols('SCALAR');
    $handle_stash->add_symbol('$' . $_, ${$sym->{$_}} )
        for keys %$sym;

    $sym = $root_stash->get_all_symbols('ARRAY');
    $handle_stash->add_symbol('@' . $_, make_cow_ref $sym->{$_} )
        for keys %$sym;

    $sym = $root_stash->get_all_symbols('HASH');
    delete @$sym{ grep /::/, keys %$sym };
    $handle_stash->add_symbol('%' . $_, make_cow_ref $sym->{$_} )
        for keys %$sym;

    return bless { id => $id, module => $module,
        eval => join ';',
            map "local \*${module}::$_ = \*${module}::${id}::$_",
                uniq map $root_stash->list_all_symbols($_),
                    qw/SCALAR ARRAY HASH/,
        }, $class;
}

sub AUTOLOAD {
    my $self = shift;
    our $AUTOLOAD; my $method = (split /::/, $AUTOLOAD)[-1];
    return if $method eq 'DESTROY';

    eval "$self->{eval}; $self->{module}::$self->{id}::$method(\@_);";
}

sub name {
    my $self = shift;
    return "$self->{module}::$self->{id}";
}

1;

__END__

=encoding utf8

=for stopwords Znet Zoffix

=head1 NAME

Package::Localize - localize package variables in other packages

=head1 SYNOPSIS

Say you've got this pesky package someone wrote that decided to use globals:

=for pod_spiffy start code section

    package Foo;
    our $var = 42;
    sub inc { $var++ }

=for pod_spiffy end code section

Whenever you call C<Foo::inc()>,
it'll always be increasing that C<$var>, even if
you call it from different places. C<Package::Localize> to the rescue:

=for pod_spiffy start code section

    my $p1 = Package::Localize->new('Foo');
    my $p2 = Package::Localize->new('Foo');

    say $p1->inc; # prints 42
    say $p1->inc; # prints 43

    say $p2->inc; # prints 42

=for pod_spiffy end code section

=head1 DESCRIPTION

This module allows you to use multple instances of packages that have
package variables operated by the functions the module offers.

Currently there is no support for OO modules; functions only.

=head1 METHODS

=head2 C<new>

    my $p1 = Package::Localize->new('Foo');

Takes one mandatory argument which is the name of the package you want to
localize.

Returns an object. Call functions from your original package as methods
on this object to operate on localizes package variables only.

=head2 C<name>

    my $name = $p1->name;
    no strict 'refs';
    my $p1_var = ${"$name::var"};

Returns the name of the localized package.

=head1 BUGS AND CAVEATS

Currently there is no support for OO modules; functions only.
Patches are definitely welcome though.

=head1 SEE ALSO

L<Package::Stash>

=for pod_spiffy hr

=head1 REPOSITORY

=for pod_spiffy start github section

Fork this module on GitHub:
L<https://github.com/zoffixznet/Package-Localize>

=for pod_spiffy end github section

=head1 BUGS

=for pod_spiffy start bugs section

To report bugs or request features, please use
L<https://github.com/zoffixznet/Package-Localize/issues>

If you can't access GitHub, you can email your request
to C<bug-Package-Localize at rt.cpan.org>

=for pod_spiffy end bugs section

=head1 AUTHOR

=for pod_spiffy start author section

=for pod_spiffy author ZOFFIX

=for pod_spiffy end author section

=head1 LICENSE

You can use and distribute this module under the same terms as Perl itself.
See the C<LICENSE> file included in this distribution for complete
details.

=cut