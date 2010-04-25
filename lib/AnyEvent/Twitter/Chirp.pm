package AnyEvent::Twitter::Chirp;

use strict;
use 5.008_001;
our $VERSION = '0.01';

use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Util;

use MIME::Base64;
use Carp;

our $API_URL = 'http://chirpstream.twitter.com/2b/user.json';

sub new {
    my $class = shift;
    my %args = @_;

    my $username     = delete $args{username};
    my $password     = delete $args{password};

    my $on_error     = delete $args{on_error}     || sub { die @_ };
    my $on_eof       = delete $args{on_eof}       || sub {};
    my $on_keepalive = delete $args{on_keepalive} || sub {};
    my $timeout      = delete $args{timeout};

    my $on_tweet      = delete $args{on_tweet};
    my $on_friends    = delete $args{on_friends}    || sub {};
    my $on_follow     = delete $args{on_follow}     || sub {};
    my $on_retweet    = delete $args{on_retweet}    || sub {};
    my $on_delete     = delete $args{on_delete}     || sub {};
    my $on_favorite   = delete $args{on_favorite}   || sub {};
    my $on_unfavorite = delete $args{on_unfavorite} || sub {};
    my $on_unknown    = delete $args{on_unknown}    || sub {};

    my $auth = MIME::Base64::encode("$username:$password", '');

    my $self = bless {}, $class;

    {
        Scalar::Util::weaken(my $self = $self);

        my $set_timeout = $timeout
            ? sub { $self->{timeout} = AE::timer($timeout, 0, sub { $on_error->('timeout') }) }
            : sub {}
        ;
        $set_timeout->();

        $self->{connnection_guard} = http_request('GET', $API_URL,
            headers => {
                Authorization => "Basic $auth",
            }, 
            on_header => sub {
                my $hdr = shift;
                if ($hdr->{Status} ne '200') {
                    return $on_error->("$hdr->{Status}: $hdr->{Reason}")
                } 
                return 1;
            },
            want_body_handle => 1,
            sub {
                my ($handle, $hdr) = @_;

                return unless $handle;

                $handle->on_error(sub { undef $handle; $on_error->($_[2]); } );

                $handle->on_eof(sub { undef $handle; $on_eof->(@_); } );

                my $reader; $reader = sub {
                    my ($handle, $json) = @_;

                    $set_timeout->();

                    if (exists $json->{text}) {
                        $on_tweet->($json);
                    }
                    elsif (exists $json->{friends}) {
                        $on_friends->(@{$json->{friends}});
                    }
                    elsif (exists $json->{'delete'}) {
                        $on_delete->($json);
                    }
                    elsif (exists $json->{event}) {
                        if ($json->{event} eq 'follow')        { $on_follow->($json);     }
                        elsif ($json->{event} eq 'retweet')    { $on_retweet->($json);    }
                        elsif ($json->{event} eq 'favorite')   { $on_favorite->($json);   }
                        elsif ($json->{event} eq 'unfavorite') { $on_unfavorite->($json); }
                        else { $on_unknown->($json); }
                    }
                    else { $on_unknown->($json); }
                    $handle->push_read(json => $reader);
                };
                $handle->push_read(json => $reader);
                $self->{guard} = AnyEvent::Util::guard { $on_eof->(); $handle->destroy if $handle; undef $reader};
            }
        );
    }

    return $self;
}

1;
__END__

=encoding utf-8

=head1 NAME

AnyEvent::Twitter::Chirp - Recieve Twitter Chirp User Streams in an event loop

=head1 SYNOPSIS

    use strict;
    use warnings;
    use utf8;
    use Encode;
    use Data::Dumper;

    use AnyEvent;
    use AnyEvent::Twitter::Chirp;

    my $user = '';
    my $password = '';

    my $cv = AE::cv;

    my $chirp = AnyEvent::Twitter::Chirp->new(
        username => $user,
        password => $password,
        on_tweet => sub {
            my $tweet = shift;
            print encode_utf8($tweet->{text} . "\n");
        },
        on_friends => sub {
            my @friends = @_;
            print 'friends: ', join(',', @friends), "\n";
        },
        on_follow => sub {
            my $follow = shift;
            print Dumper ['follow', $follow];
        },
        on_retweet => sub {
            my $retweet = shift;
            print Dumper ['retweet', $retweet];
        },
        on_favorite => sub {
            my $favorite = shift;
            print Dumper ['fav', $favorite];
        },
        on_unfavorite => sub {
            my $unfavorite = shift;
            print Dumper ['unfav', $unfavorite];
        },
        on_delete => sub {
            my $delete = shift;
            print Dumper ['delete', $delete];
        },
        on_unknown => sub {
            my $unknown = shift;
            print Dumper ['on_unknonw', $unknown];
        },
    #    timeout => 45,
    );

    $cv->recv;

=head1 DESCRIPTION

AnyEvent::Twitter::Chirp is a good wrapper for Twitter Chirp User Streams with AnyEvent.

You MUST read API documentation L<http://apiwiki.twitter.com/ChirpUserStreams> before you use this module.

=head2 You can set the callback coderef each event.

=over 4

=item on_tweet

=item on_friends

=item on_follow

=item on_retweet

=item on_favorite

=item on_unfavorite

=item on_delete

=item on_unknown

=back

=head2 NOTE

This service is developer preview. So, some features can be added or be changed in the future.
I think that all events must be catched by this module. Therefore on_unknown event is implemented and you can keep up with the new features without waiting module update.
But I will welcome your fix :)

=head1 AUTHOR

punytan E<lt>punytan@gmail.comE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<AnyEvent::Twitter>, L<AnyEvent::Twitter::Stream>

=cut


