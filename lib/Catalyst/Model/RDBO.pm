package Catalyst::Model::RDBO;

use strict;
use warnings;
use base 'Catalyst::Model';
use Carp;

our $VERSION = '0.01';

# uncomment this to see the SQL print on stderr
#$Rose::DB::Object::QueryBuilder::Debug = 1;

=head1 NAME

Catalyst::Model::RDBO - base class for Rose::DB::Object model

=head1 SYNOPSIS

 package MyApp::Model::Foo;
 use base qw( Catalyst::Model::RDBO );
 
 __PACKAGE__->config(name      => 'My::Rose::Class',
                    load_with => ['foo']);

 # assumes you also have a My::Rose::Class::Manager class

 1;
 
 # then in your controller
 
 my $object = $c->model('Foo')->fetch(id=>1);
 
 
=head1 DESCRIPTION

Catalyst Model base class.

=head1 METHODS

=cut

=head2 new

=cut

__PACKAGE__->mk_accessors(qw( context ));

sub ACCEPT_CONTEXT
{
    my ($self, $c, @args) = @_;

    my $new = bless({%$self}, ref $self);
    $new->context($c);
    return $new;
}

sub new
{
    my ($class, $c) = @_;
    my $self = $class->NEXT::new($c);
    $self->_setup;
    return $self;
}

sub _setup
{
    my $self = shift;
    my $name = $self->config->{name}
      or croak "need to configure a Rose class name";

    eval "require $name";
    croak $@ if $@;
    eval "require ${name}::Manager";
    croak $@ if $@;
}

=head2 name

Returns the C<name> value from config().

=cut

sub name
{
    my $self = shift;
    return $self->config->{name};
}

=head2 manager

Returns the C<name> value from config() with C<::Manager> appended.
This assumes the namespace convention of Rose::DB::Object::Manager,
so if you do not have a Manager class defined for you RDBO-subclass,
you should either create one in the expected namespace,
or override this method to return the actual Manager class name.

=cut 

sub manager
{
    my $self = shift;
    my $name = $self->name;
    return "${name}::Manager";
}

=head2 fetch( @params )

If present,
@I<params> is passed directly to name()'s new() method,
and is expected to be an array of key/value pairs. In addition,
the object's load() method is called with the speculative flag.

If not present, the new() object is simply returned.

All the methods called within fetch() are wrapped in an eval()
and sanity checked afterwards. If there are any errors,
the context's error() method is set with the error message.

Example:

 my $foo = $c->model('Foo')->fetch( id => 1234 );
 if (@{ $c->error })
 {
    # do something to deal with the error
 }

=cut

sub fetch
{
    my $self = shift;
    my %v    = (@_);

    my $name = $self->name;

    my $p;

    eval { $p = $name->new(%v) };

    if ($@ or !$p)
    {
        my $err = defined($p) ? $p->error : $@;
        my $msg = "can't create new $name object: $err";
        $self->context->log->error($msg);
        $self->context->error($msg);
        return;
    }

    if (%v)
    {

        my $ret;
        my @arg = (speculative => 1);
        if ($self->config->{load_with})
        {
            push(@arg, with => $self->config->{load_with});
        }
        eval { $ret = $p->load(@arg); };
        if ($@ or !$ret)
        {
            my $err = $@ . "\nno such object";
            $self->context->log->error($err);
            $self->context->error($err);
            return;
        }

        if ($v{id})
        {

            # stringify in case it's a char instead of int
            # as is the case with session ids
            my $pid = $p->id;
            $pid =~ s,\s+$,,;
            unless ($pid eq $v{id})
            {
                my $err =
                    "Error fetching correct id:\nfetched: $v{id} "
                  . length($v{id})
                  . "\nbut got: $pid"
                  . length($pid);
                $self->context->log->error($err);
                $self->context->error($err);
                return;
            }
        }
    }

    return $p;
}

=head2 fetch_all( @params )

@I<params> is passed directly to the Manager get_objects() method.
See the Rose::DB::Object::Manager documentation.

You can also use all().

=cut

sub fetch_all
{
    my $self = shift;
    return $self->_get_objects('get_objects', @_);
}

*all = \&fetch_all;

=head2 search( @params )

@I<params> is passed directly to the Manager get_objects() method.
See the Rose::DB::Object::Manager documentation.

=cut

sub search
{
    my $self = shift;
    return $self->_get_objects('get_objects', @_);
}

=head2 count( @params )

@I<params> is passed directly to the Manager get_objects_count() method.
See the Rose::DB::Object::Manager documentation.

=cut

sub count
{
    my $self = shift;
    return $self->_get_objects('get_objects_count', @_);
}

=head2 iterator( @params )

@I<params> is passed directly to the Manager get_objects_iterator() method.
See the Rose::DB::Object::Manager documentation.

=cut

sub iterator
{
    my $self = shift;
    return $self->_get_objects('get_objects_iterator', @_);
}

sub _get_objects
{
    my $self    = shift;
    my $method  = shift || 'get_objects';
    my $manager = $self->manager;
    my $name    = $self->name;
    my @args = (
                object_class => $self->name,
                @_
               );

    push(@args, with_objects => $self->config->{load_with}, multi_many_ok => 1)
      if $self->config->{load_with};

    return $manager->$method(@args);
}

1;

__END__


=head1 AUTHOR

Peter Karman

Thanks to Atomic Learning, Inc for sponsoring the development of this module.

=head1 LICENSE

This library is free software. You may redistribute it and/or modify it under
the same terms as Perl itself.


=head1 SEE ALSO

Rose::DB::Object

=cut
