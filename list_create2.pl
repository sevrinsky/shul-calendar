#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib $FindBin::Bin;

use List::MoreUtils qw(any);
use YAML qw(LoadFile);
use CGI::Pretty;
use ShulCal::Day;
use ShulCal::Util;
use DateTime::Calendar::Hebrew;
use Getopt::Long;

our %e2e = %{LoadFile("$FindBin::Bin/translations/english.yaml")};
our %e2h = %{LoadFile("$FindBin::Bin/translations/hebrew_long.yaml")};

#my $start_date = "5766-06-29";
#my $end_date = "5767-07-10";

my $start_date = "2006-09-22";
my $end_date = "2006-10-03";

#GetOptions("start=s" => \$start_date,
#	   "end=s" => \$end_date);


my @week;
my @start_date = split(/-/, $start_date);
my $start = DateTime->new(year => $start_date[0],
			  month => $start_date[1],
			  day => $start_date[2]);
my $offset = 0;
while(1) {
  my $day = $start + DateTime::Duration->new(days => $offset++);
  last if ($day->ymd gt $end_date);
  my $hday = ShulCal::Day->from_object(object => $day);
  $hday->init;
  push(@week, $hday);
}

for my $i (0..$#week - 1) {
  $week[$i]->{tomorrow} = $week[$i+1];
}

our $q = new CGI::Pretty("");
print page_header();

# my($friday) = grep($_->is_erev_shabbat, @week);
# my($shabbat) = grep($_->is_shabbat, @week);

# print $q->table($q->TR($q->td("SHABBAT SHALOM - Parshat " . e2e($shabbat->holiday->parsha)),
# 		       $q->td({ style => 'direction: rtl'},
# 			      e2h("shabbat shalom") . " - " . e2h("parshat"). " " . e2h($shabbat->holiday->parsha)),
# 		       )
# 	       );

# print $q->table(
# 		get_row('candle lighting long',{ $friday->get_times }->{'candle lighting'}),
# 		get_row('motzash long', { $shabbat->get_times }->{'motzash'}),
# 	       );

my @rows;

push(@rows, get_row('tefillah times', '', 1));
push(@rows, get_row('shabbat','',1));

my $last_used_name = '';
for my $day (@week) {
  last if ($day eq $week[-1]);
  my $holiday = $day->holiday;
  my $holiday_name = $holiday->name;
  $holiday_name =~ s/^(.*)' // if ($holiday_name);
  if ($holiday_name && $last_used_name ne $holiday_name) {
    $last_used_name = $holiday_name;
    push(@rows, get_row($holiday_name, '', 1));
  }
  my %times = $day->get_times;
  if ($day->is_shabbat) {
    $times{'childrens tefillah'} = '10:00';
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
      push(@rows, get_row($k, $times{$k}));
    }
  }
}

push(@rows, get_row("weekday tefillot", '', 1));
push(@rows, get_row('nonlayning shachrit', '6:15')); # todo: determine other exceptional days
push(@rows, get_row('layning shachrit', '6:05'));
push(@rows, get_row('arvit', '20:45'));

print $q->table(@rows);

print "</body></html>\n\n";

#----------------------------------------------------------------------

sub e2e {
  my $phrase = shift;
  my $fix_phrase = smart_cap($phrase);
  return $e2e{$phrase} || $fix_phrase;
}

#----------------------------------------------------------------------

sub e2h {
  my $phrase = shift;
  return $e2h{$phrase} || ShulCal::Util::e2h($phrase);
}

#----------------------------------------------------------------------

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

#----------------------------------------------------------------------

sub get_row {
  my($label, $time, $bold) = @_;
  my $eng = e2e($label) . ":";
  my $heb = e2h($label) . ":";
  if ($bold) {
    $eng = $q->b($eng);
    $heb = $q->b($heb);
  }
  return $q->TR(
		$q->td($eng),
		$q->td($time),
		$q->td({ style => 'direction: rtl'},
		       $heb),
	       );
}

#----------------------------------------------------------------------

sub page_header {
  return <<EOFText;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-US" lang="en-US">
<head>
  <title>Untitled Document</title>


  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">

</head>


<body>
EOFText

}
