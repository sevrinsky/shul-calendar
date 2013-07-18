package ShulCal::Time;

use strict;
use POSIX;
use overload '+' => \&add,
  '-' => \&subtract,
  '%' => \&round,
  '""' => \&print,
  'cmp' => \&compare;


sub new {
  my($class, $time) = @_;
  my $self = bless({}, $class);
  $self->set($time);
  return $self;
}

sub set {
  my($self, $time) = @_;
  if ($time =~ /^(\d+):(\d+)$/) {
    $time = $1 * 60 + $2;
  }
  if ($time < 0 || $time > 24*60) {
    $time %= 24*60;
  }
  $self->{time} = $time;
}

sub add {
  my($self, $add_minutes) = @_;
  return ShulCal::Time->new($self->{time} + $add_minutes);
}

sub subtract {
  my($self, $subtract_obj) = @_;
  if (ref($subtract_obj)) {
    return $self->{time} - $subtract_obj->{time};
  } else {
    return $self->add(- $subtract_obj);
  }
}

sub round {
  my($self, $round_minutes) = @_;
  return ShulCal::Time->new($self->{time} - $self->{time} % $round_minutes);
}

sub print {
  my($self) = @_;
  my $hour = int($self->{time} / 60) % 24;
  my $minutes = $self->{time} % 60;
  return sprintf("%d:%2.2d", $hour, $minutes);
}

sub compare {
  my($self, $val, $inverted) = @_;
  if (ref($val)) {
    return $self->{time} <=> $val->{time};
  } else {
    return $self->{time} <=> ShulCal::Time->new($val)->{time};
  }
}

1;
