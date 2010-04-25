#!/usr/bin/perl

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

__END__

