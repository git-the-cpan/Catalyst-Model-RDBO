package Catalyst::Model::RDBO;

use strict;
use warnings;
use base 'Catalyst::Model';
use Catalyst::Exception;

our $VERSION = '0.07';

# uncomment this to see the _get_objects SQL print on stderr
#$Rose::DB::Object::QueryBuilder::Debug = 1;

=head1 NAME

Catalyst::Model::RDBO - **DEPRECATED** base class for Rose::DB::Object model

=head1 SYNOPSIS

 package MyApp::Model::Foo;
 use base qw( Catalyst::Model::RDBO );
 
 __PACKAGE__->config(
        name      => 'My::Rose::Class',
        manager   => 'My::Rose::Class::Manager',
        load_with => ['bar']
        );

 1;
 
 # then in your controller
 
 my $object = $c->model('Foo')->fetch(id=>1);
 
 
=head1 DESCRIPTION

B<This package is deprecated. Please use CatalystX::CRUD::Model::RDBO instead.>

Catalyst Model base class for Rose::DB::Object. This class provides
convenience access to your existing Rose::DB::Object class.

The assumption is one Model class per Rose::DB::Object class.

B<NOTE:> See the newer CatalystX::CRUD::Model::RDBO  
for a similar module with a similar API.

=head1 METHODS

=cut

=head2 new

Initializes the Model. This method is called by the Catalyst
setup() method.

=cut

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
    my $name = $self->name;
    if (!$name)
    {
        return if $self->throw_error("need to configure a Rose class name");
    }

    $self->config->{manager} ||= "${name}::Manager";

    my $mgr = $self->manager;
    if (!$mgr)
    {
        return
          if $self->throw_error("need to configure a Rose manager for $name");
    }

    eval "require $name";
    if ($@)
    {
        return if $self->throw_error($@);
    }
    eval "require $mgr";

    # don't croak -- just use RDBO::Manager
    if ($@)
    {
        $self->config->{manager} = 'Rose::DB::Object::Manager';
        require Rose::DB::Object::Manager;
    }
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

Returns the C<manager> value from config().

If C<manager> is not defined in config(),
the new() method will attempt to load a class
named with the C<name> value from config() 
with C<::Manager> appended.
This assumes the namespace convention of Rose::DB::Object::Manager.

If there is no such module in your @INC path, then
the fall-back default is Rose::DB::Object::Manager.

=cut 

sub manager
{
    my $self = shift;
    return $self->config->{manager};
}

=head2 create( @params )

Returns new instance of the RDBO object, instantiated with @params.
Same as calling:

 MyObject->new( @params );

Returns undef if there was any error creating the object. Check
the context's error() method for any error message. Example:

 my $obj = $c->model('Object')->create( id => 100 );
 if (!$obj or @{$c->error})
 {
     # handle error
     # ...
 }

The method is called create() instead of new() because new()
is a reserved method name in Catalyst::Model subclasses.

=cut

sub create
{
    my $self = shift;
    my $name = $self->name;
    my $obj;
    eval { $obj = $name->new(@_) };
    if ($@ or !$obj)
    {
        my $err = defined($obj) ? $obj->error : $@;
        return if $self->throw_error("can't create new $name object: $err");
    }
    return $obj;
}

=head2 fetch( @params )

If present,
@I<params> is passed directly to name()'s new() method,
and is expected to be an array of key/value pairs.
Then the load() method is called on the resulting object.

If @I<params> are not present, the new() object is simply returned,
which is equivalent to calling create().

All the methods called within fetch() are wrapped in an eval()
and sanity checked afterwards. If there are any errors,
throw_error() is called.

Example:

 my $foo = $c->model('Foo')->fetch( id => 1234 );
 if (@{ $c->error })
 {
    # do something to deal with the error
 }
 
B<NOTE:> If the object's presence in the database is questionable,
your controller code may want to use create() and then call load() yourself
with the speculative flag. Example:

 my $foo = $c->model('Foo')->create( id => 1234 );
 $foo->load(speculative => 1);
 if ($foo->not_found)
 {
   # do something
 }

=cut

sub fetch
{
    my $self = shift;
    my $obj = $self->create(@_) or return;

    if (@_)
    {
        my %v = @_;
        my $ret;
        my $name = $self->name;
        my @arg  = ();
        if ($self->config->{load_with})
        {
            push(@arg, with => $self->config->{load_with});
        }
        eval { $ret = $obj->load(@arg); };
        if ($@ or !$ret)
        {
            return if $self->throw_error(join(" : ", $@, "no such $name"));
        }

        # special handling of fetching
        # e.g. Catalyst::Plugin::Session::Store::DBI records.
        if ($v{id})
        {

            # stringify in case it's a char instead of int
            # as is the case with session ids
            my $pid = $obj->id;
            $pid =~ s,\s+$,,;
            unless ($pid eq $v{id})
            {

                return
                  if $self->throw_error(
                                  "Error fetching correct id:\nfetched: $v{id} "
                                    . length($v{id})
                                    . "\nbut got: $pid"
                                    . length($pid));
            }
        }
    }

    return $obj;
}

=head2 fetch_all( @params )

Alias for search().

=head2 all( @params )

Alias for search().

=cut

*all       = \&search;
*fetch_all = \&search;

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
    my @args    = @_;
    my $manager = $self->manager;
    my $name    = $self->name;
    my @params  = (object_class => $self->name);

    if (ref $args[0] eq 'HASH')
    {
        push(@params, %{$args[0]});
    }
    elsif (ref $args[0] eq 'ARRAY')
    {
        push(@params, @{$args[0]});
    }
    else
    {
        push(@params, @args);
    }

    push(
         @params,
         with_objects  => $self->config->{load_with},
         multi_many_ok => 1
        ) if $self->config->{load_with};

    return $manager->$method(@params);
}

=head2 throw_error( I<msg> )

Throws Catalyst::Exception. Override to manage errors in some other way.

NOTE that if in your subclass throw_error() is not fatal and instead
returns a false a value, methods that call it will, be default, continue
processing instead of returning. See fetch() for an example.

=cut

sub throw_error
{
    my $self = shift;
    my $msg = shift || 'unknown error';
    Catalyst::Exception->throw($msg);
}

1;

__END__


=head1 AUTHOR

Peter Karman

=head1 CREDITS

Thanks to Atomic Learning, Inc for sponsoring the development of this module.

Thanks to Bill Moseley for API suggestions.

=head1 LICENSE

This library is free software. You may redistribute it and/or modify it under
the same terms as Perl itself.


=head1 SEE ALSO

Rose::DB::Object, CatalystX::CRUD::Model::RDBO

=cut
