#!/usr/bin/perl

use common::sense;
use Term::ReadKey;

srand();

package The2048;

use Term::ANSIColor qw/colored/;
use Data::Dump 'pp';
use feature 'state';
use Time::HiRes;

sub new
{
    my ($class, $self) = @_;
    $self //= {};
    bless $self, $class;
    $self->init_map();
    $self->{over} = $self->{win} = 0;
    $self->put_random();
    return $self;
}

sub over
{
    return shift->{over};
}

sub win
{
    return shift->{win};
}

sub init_map
{
    my $self = shift;
    $self->{map} = [ map { [ map { 0 } (0 .. 3) ] } (0 .. 3) ];
}

sub auto_play
{
    my $self = shift;
    my $moves = [ qw/up right down left/ ];
    state $move_idx = 0;
    $self->pull($moves->[ $move_idx = ($move_idx + 1) % 4 ]);
    Time::HiRes::sleep 0.01;
}

sub check_game_over
{
    my $self = shift;
    $self->{over} = 1;
    for my $i (0 .. 3) {
        for my $j (0 .. 3) {
            if ($self->{map}->[$i][$j] == 0) {
                $self->{over} = 0;
            }
            if ($self->{map}->[$i][$j] == 2048) {
                $self->{over} = 1;
                $self->{win} = 1;
                return;
            }
            if ($self->{map}->[$i][$j] > 0) {
                if ($i < 3
                    && $self->{map}->[$i][$j] == $self->{map}->[$i+1][$j]
                )
                {
                    $self->{over} = 0;
                }
                if ($j < 3
                    && $self->{map}->[$i][$j] == $self->{map}->[$i][$j+1]
                )
                {
                    $self->{over} = 0;
                }
            }
        }
    }
    if ($self->{win}) {
        $self->{over} = 1;
    }
}

sub pull
{
    my ($self, $direction) = @_;
    $self->{valid_move} = 0;
    if ($direction eq 'up') {
        $self->pull_up();
    }
    elsif ($direction eq 'down') {
        $self->pull_down();
    }
    elsif ($direction eq 'left') {
        $self->pull_left();
    }
    elsif ($direction eq 'right') {
        $self->pull_right();
    }
    if ($self->{valid_move}) {
        $self->put_random();
    }
    $self->check_game_over();
}

sub pull_up
{
    my $self = shift;
    $self->rotate();
    $self->pull_left();
    $self->rotate();
}

sub pull_down
{
    my $self = shift;
    $self->rotate();
    $self->pull_right();
    $self->rotate();
}

sub pull_left
{
    my $self = shift;
    for my $i (keys @{$self->{map}}) {
        my ($new_row, $moved) = row_pull_merge($self->{map}->[$i]);
        $self->{map}->[$i] = $new_row;
        $self->{valid_move} ||= $moved;
    }
}

sub pull_right
{
    my $self = shift;
    for my $i (keys @{$self->{map}}) {
        my ($new_row, $moved) = row_pull_merge_rev($self->{map}->[$i]);
        $self->{map}->[$i] = $new_row;
        $self->{valid_move} ||= $moved;
    }
}

sub row_pull_merge_rev
{
    my $row = shift;
    my $ok;
    $row = [ reverse @$row ];
    ($row, $ok) = row_pull_merge($row);
    $row = [ reverse @$row ];
    return ($row, $ok);
}

sub row_pull_merge
{
    my $row = shift;
    my $ok = pull_row($row);
    if (merge_row($row)) {
        $ok = 1;
    }
    if (pull_row($row)) {
        $ok = 1;
    }
    return ($row, $ok);
}

sub merge_row
{
    my $a = shift;
    my $ok = 0;
    for my $i (0 .. 2) {
        if ($a->[$i] > 0 && $a->[$i] == $a->[$i+1]) {
            $a->[$i] *= 2;
            $a->[$i+1] = 0;
            $ok = 1;
        }
    }
    return $ok;
}

sub pull_row
{
    my $a = shift;
    my $moved = 0;
    for my $i (0 .. 3) {
        if ($a->[$i] > 0) {
            my $j = $i-1;
            while ($j >= 0 && $a->[$j] == 0) {
                $a->[$j] = $a->[$j+1];
                $a->[$j+1] = 0;
                $j--;
                $moved = 1;
            }
        }
    }
    return $moved;
}

sub rotate
{
    my $self = shift;
    for my $i (0 .. 3) {
        for my $j (0 .. 3) {
            next unless $i >= $j;
            ($self->{map}->[$i][$j], $self->{map}->[$j][$i]) = ($self->{map}->[$j][$i], $self->{map}->[$i][$j]);
        }
    }
}

sub draw
{
    my $self = shift;
    state $clear = `clear`;
    my $box = qq/
    ┌──────┬──────┬──────┬──────┐
    │      │      │      │      │
    │ %s │ %s │ %s │ %s │
    │      │      │      │      │
    ├──────┼──────┼──────┼──────┤
    │      │      │      │      │
    │ %s │ %s │ %s │ %s │
    │      │      │      │      │
    ├──────┼──────┼──────┼──────┤
    │      │      │      │      │
    │ %s │ %s │ %s │ %s │
    │      │      │      │      │
    ├──────┼──────┼──────┼──────┤
    │      │      │      │      │
    │ %s │ %s │ %s │ %s │
    │      │      │      │      │
    └──────┴──────┴──────┴──────┘/;
    print $clear;
    printf $box, map { map { hl(pad($_)) } @$_ } @{$self->{map}};
    print "\n";
}

sub pad
{
    my $s = shift;
    if ($s eq '0') {
        $s = '';
    }
    while (length($s) < 4) {
        $s = ' '.$s;
    }
    return $s;
}

sub hl
{
    my $s = shift;
    my $n = int($s =~ s/\D//rg);
    my %hl = (
        2 => 'black bold',
        4 => 'red bold',
        8 => 'green bold',
        16 => 'yellow bold',
        32 => 'blue bold',
        64 => 'magenta bold',
        128 => 'cyan bold',
        256 => 'red bold on_black',
        512 => 'green bold on_black',
        1024 => 'yellow bold on_black',
        2048 => 'blue bold on_black',
    );
    return colored(["$hl{$n}"], $s);
}

sub put_random
{
    my $self = shift;
    my @zeros;
    for my $i (0 .. 3) {
        for my $j (0 .. 3) {
            if ($self->{map}->[$i][$j] == 0) {
                push @zeros, [$i, $j];
            }
            if ($self->{map}->[$i][$j] == 2048) {
                $self->{win} = 1;
                return;
            }
        }
    }
    if (@zeros == 0) {
        return;
    }
    my $ij = $zeros[int rand @zeros];
    $self->{map}->[$ij->[0]][$ij->[1]] = (rand() > 0.9 ? 4 : 2);
}


package main;

help();

my $game = The2048->new();
while (1) {
    $game->draw();
    if ($game->over) {
        print "game over: you ".($game->win ? 'made it!' : 'lost')."\n";
        last;
    }
    # $game->auto_play();
    # next;
    my $key = get_key();
    if ($key eq 'w') {
        $game->pull('up');
    }
    elsif ($key eq 's') {
        $game->pull('down');
    }
    elsif ($key eq 'a') {
        $game->pull('left');
    }
    elsif ($key eq 'd') {
        $game->pull('right');
    }
    elsif ($key eq 'q') {
        last;
    }
    elsif ($key eq '?') {
        help();
    }
}

sub get_key
{
    # arrows to WASD map: A = w, B = s, C = d, D = a
    ReadMode(3);
    my $ch = ReadKey(0);
    if ($ch eq "\e") {
        $ch = ReadKey(0);
        if ($ch eq "[") {
            $ch = ReadKey(0);
            $ch = { A => 'w', B => 's', C => 'd', D => 'a' }->{$ch};
        }
    }
    ReadMode(0);
    # vim-style controls
    $ch = { h => 'a', l => 'd', j => 's', k => 'w'  }->{$ch} // $ch;
    return $ch;
}

sub help
{
    print q/
Controls:

  w
a s d

  ↑
← ↓ →

  k
h j l

q to quit
? to see this message

Press any key to continue
/;
    get_key();
}

