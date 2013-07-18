#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib $FindBin::Bin;

use List::MoreUtils qw(any);
use YAML qw(LoadFile);
use CGI::Pretty;
use ShulCal::Day;
use ShulCal::Util qw(e2h);
use DateTime::Calendar::Hebrew;

our %e2e = %{LoadFile("$FindBin::Bin/translations/english.yaml")};

my @week;
my $today = DateTime::Calendar::Hebrew->today;
#my $offset = 5 - $today->dow_0;
my $offset = 2;
for my $i (0..11) {
  my $day = $today + DateTime::Duration->new(days => $offset + $i);
  push(@week, ShulCal::Day->new(year => $day->year,
				month => $day->month,
				day => $day->day));

}

for my $i (0..$#week - 1) {
  $week[$i]->{tomorrow} = $week[$i+1];
}

our $q = new CGI::Pretty("");

print <<EOFText;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-US" lang="en-US">
<head>
  <title>Untitled Document</title>


  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">

</head>


<body>
EOFText

my @rows;
my $last_used_name = '';
for my $day (@week) {
  last if ($day eq $week[-1]);
  my $holiday = $day->holiday;
  my $holiday_name = $holiday->name;
  $holiday_name =~ s/^.*' // if ($holiday_name);
#  if ($holiday_name && $last_used_name eq $holiday_name) {
#    $holiday
  if ($holiday_name && $last_used_name ne $holiday_name) {
    $last_used_name = $holiday_name;
    push(@rows, $q->TR(
		       $q->td($q->b(e2e($holiday_name) . ":")),
		       $q->td,
		       $q->td({ style => 'direction: rtl'}, 
			      $q->b(e2h($holiday_name) . ":"))
		      ));
  }
  my %times = $day->get_times;
  if ($day->is_shabbat || ($day->holiday && $day->holiday->yomtov)) {
    $times{'childrens tefillah'} = "After Kri'at Ha'Tora (10:00)<br>לאחר קריאת התורה";
  }
  if (%times) {
    for my $k (ShulCal::Day::sort_by_davening(%times)) {
      if ($day->is_erev_shabbat || ($day->{tomorrow}->holiday && $day->{tomorrow}->holiday->yomtov)) {
	if ($times{$k} gt '16:00') {
	  $holiday_name = $day->{tomorrow}->holiday->name;
	  $holiday_name =~ s/^.*' //;
	  if ($holiday_name && $last_used_name ne $holiday_name) {
    
	    $last_used_name = $holiday_name;
	    push(@rows, $q->TR(
			       $q->td($q->b(e2e($holiday_name) . ":")),
			       $q->td,
			       $q->td({ style => 'direction: rtl'}, 
				      $q->b(e2h($holiday_name) . ":"))
			      ));
	  }
	}
      }
      push(@rows, $q->TR(
			 $q->td(e2e($k) . ":"),
			 $q->td($times{$k}),
			 $q->td({ style => 'direction: rtl'}, 
				e2h($k) . ":")
			));
    }
  }
}

print $q->table(@rows);

print "</body></html>\n\n";
sub e2e {
  my $phrase = shift;
  my $fix_phrase = smart_cap($phrase);
  return $e2e{$phrase} || $fix_phrase;
}

sub smart_cap {
  my($phrase) = @_;
  my @short_words = qw(and the a of in);
  my @phrase = split(/ /, $phrase);
  for my $word (@phrase) {
    unless (any { $_ eq lc $word } @short_words) {
      $word = ucfirst $word;
      $word =~ s/^ Ha (.) / 'Ha' . uc $1 /xe;
    }
  }
  return join(' ', @phrase);
}
