#!/usr/bin/perl -w

use FindBin;
use lib $FindBin::Bin;

use strict;
use CGI;
use ShulCal::Day;
use ShulCal::Util qw(gematria e2h eng_month heb_month);
use DateTime::Calendar::Hebrew;
use Getopt::Long;
use File::Slurper qw(read_text);
use Encode;

our @tefillot;
our %tef_order_lookup;
our @weekday_start;

binmode STDOUT, ":utf8";

{
  my $printed_times = 0;
  sub maybe_tefillah_times {
    my($days_remaining, $month, $month_note, $include_shul_times) = @_;
    if ($days_remaining < 3 || $printed_times || ! $include_shul_times) {
      return "&nbsp;";
    }
    $printed_times = 1;
    my $msg =  read_text("$FindBin::Bin/templates/weekday_times.txt");
    if ($month_note) {
        $msg .= "\n<br><br>\n$month_note";
    }
    $msg .= maybe_month_message($month);

    my $month_preamble_filename = "$FindBin::Bin/templates/weekday_times_preamble_$month.txt";
    if (-f $month_preamble_filename) {
        $msg = read_text($month_preamble_filename) . $msg;
    }
    return $msg;
  } 
}


#--------------------------------------------------

my $current_year;
my @months;
my $fullpage;
my $ical_mode;
my $finish_week;
my $include_shiurim = undef;
my $include_shiur_times = 1;
my $include_shul_times = 1;
GetOptions('year=i' => \$current_year,
           'month=s' => \@months,
           'fullpage!' => \$fullpage,
           'ical!' => \$ical_mode,
           'finish-week!' => \$finish_week,
           'include-shiurim!' => \$include_shiurim,
           'include-shiur-times!' => \$include_shiur_times,
           'include-shul-times!' => \$include_shul_times,
    );

if ($fullpage && ! defined($include_shiurim)) {
    $include_shiurim = 1;
}

@months = split(/,/, join(",", @months));
unless (@months) {
  die "Must specify months\n";
}

$current_year ||= 5765;

our $q = new CGI("");

# Page header
if ($fullpage) {
  my $header = $q->start_html(-head=> $q->meta({-http_equiv => 'Content-Type',
                                                -content    => 'text/html; charset=utf-8',
                                               }));
  $header =~ s/^.*?(<html)/$1/si;
  print $header;
}

unless ($ical_mode) {
  print "<style>\n" . get_stylesheet() . "\n</style>\n";

  print <<EOFText;
<style>
table, tr, td { border-collapse: collapse }
</style>
EOFText

  print $q->div({-class => "calendar_header"},
                e2h("kehillat ahavat tzion"));
}

for my $month (@months) {
  my @month = make_month(year => $current_year,
                         month => $month,
                         finish_week => $finish_week,
                         is_not_first_month => ($month ne $months[0]),
                         include_shul_times => $include_shul_times,
                         include_shiur_times => $include_shiur_times,
      );
  
  if ($month == 7) {
    unshift(@month, new ShulCal::Day(year => $current_year - 1,
                                     month => 6, day => 29));
    $month[0]->{tomorrow} = $month[1];
  }

  if ($ical_mode) {
    print ical_month(@month);
  }
  else {
    print month_header(@month);
    print month_cal(month_num => $month,
                    month_days => \@month,
                    include_shul_times => $include_shul_times,
                    include_shiur_times => $include_shiur_times,
        );
  }
}

if ($include_shiurim) {
    print read_text("$FindBin::Bin/templates/footer_msg.txt");
}

if ($fullpage) {
  print $q->end_html;
}

exit();

#==================================================

sub month_header {
  my(@month, $month_num) = @_;
  
  my $date = $month[1];
  my $next_month_date = $month[-1];

  my $year_gem = gematria($date->year, 1);
  my $month_string = heb_month($date->month);
  if ($date->month == 12 && DateTime::Calendar::Hebrew::_LastMonthOfYear($date->year) == 13) {
    $month_string = decode_utf8('אדר א\''); # Adar I in a leap year
  } 

  $month_string .= " $year_gem (";

  if ($next_month_date->e_month != $date->e_month) {
    $month_string .= eng_month($date->e_month) . '-' . eng_month($next_month_date->e_month) . ')';
  }
  else {
    $month_string .= eng_month($date->e_month) . ')';
  }

  return $q->div({-class => "month_header"},
	       $month_string) . "\n\n";
}

#--------------------------------------------------

sub make_month {
  my(%params) = @_;
  my @month;
  my %day_params = (year => $params{year}, month => $params{month});
  push(@month, new ShulCal::Day(%day_params, day => 1));

  if ($month[0]->dow_0 == 6 && !$params{is_not_first_month} && $params{month} != 7) {
      my $prev_month = $day_params{month} - 1;
      if (! $prev_month) {
          $prev_month = DateTime::Calendar::Hebrew::_LastMonthOfYear($day_params{year});
      }
      # If the first day of the month is Shabbat, add the preceding Friday
      unshift(@month, new ShulCal::Day(%day_params, 
                                       month => $prev_month,
                                       day => DateTime::Calendar::Hebrew::_LastDayOfMonth($day_params{year}, $prev_month),
                                      ));
      $month[0]->{tomorrow} = $month[1];
  }

  for my $i (2..DateTime::Calendar::Hebrew::_LastDayOfMonth($day_params{year}, $day_params{month})) {
    push(@month, new ShulCal::Day(%day_params,
                                  day => $i));
    $month[-2]->{tomorrow} = $month[-1];
  }
  my $extra_day = 1;
  if ($params{finish_week}) {
      while (1) {
          my $next_day = new ShulCal::Day(%day_params, 
                                          month => ($day_params{month} % DateTime::Calendar::Hebrew::_LastMonthOfYear($day_params{year})) + 1, 
                                          day => $extra_day,
              );
          last if ($next_day->dow_0 == 0);
          $extra_day++;
          push(@month, $next_day);
          $month[-2]->{tomorrow} = $month[-1];
      }
  }
  $month[-1]->{tomorrow} = new ShulCal::Day(%day_params,
                                            month => ($day_params{month} % DateTime::Calendar::Hebrew::_LastMonthOfYear($day_params{year})) + 1,
                                            day => $extra_day,
      );

  return @month;
}

#--------------------------------------------------

sub month_cal {
  my(%params) = @_;
  my $month_num = $params{month_num};
  my @month = @{$params{month_days}};
  my $include_shul_times = $params{include_shul_times};
  my $include_shiur_times = $params{include_shiur_times};

  my @row;
  my @weeks;
  my @days_of_week_e = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Shabbat');
  push(@weeks, join("",map($q->td({-class => 'days_of_week_header'},
                                  $q->div($_)), 
			   map { e2h($_) } @days_of_week_e)));

  my $month_note = '';
  my @print_day_output;
  for my $d (@month) {
      push(@print_day_output, $d->print_cell(html_page => $q,
                                             include_shul_times => $include_shul_times,
                                             include_shiur_times => $include_shiur_times,
           ));
      if (my $note = $d->get_month_note()) {
          $month_note .= $note;
      }
  }

  if ($month[0]->dow_0) {
    push(@row, $q->td({-colspan => $month[0]->dow_0,
		       -class => 'general_tefillah_times'},
		      $q->div({-class => 'general_tefillah_times_div'},
            maybe_tefillah_times($month[0]->dow_0, $month_num, $month_note, $include_shul_times))));
  }

  for my $i (0..$#month) {

      #    my %davening_times = compute_davening_times($holiday, $holiday_tomorrow, $date);

      push(@row, $q->td({-class => 'day_cell'}, 
                       $print_day_output[$i]) . "\n");

      if ($month[$i]->dow_0 == 6) {
          push(@weeks, join("",@row));
          @row = ();
      }
  }

  if ($month[-1]->dow_0 != 6) {
    push(@weeks, join("",@row, $q->td({-colspan => (7 - $month[-1]->dow),
                                       -class => 'general_tefillah_times'}, 
				      $q->div({-class => 'general_tefillah_times_div'},
                maybe_tefillah_times(7- $month[-1]->dow, $month_num, $month_note, $include_shul_times))
				     )));
  }

  return $q->table({-class => 'entire_calendar',
                    -dir => 'rtl'},
                   $q->TR(\@weeks)) . "\n";
}

#==================================================

sub maybe_month_message {
  my($month) = @_;
  if ($month == 7) {
    return read_text("$FindBin::Bin/templates/tishrei_msg.txt");
  }
  if ($month == 3) {
    return read_text("$FindBin::Bin/templates/sivan_msg.txt");
  }
#  if ($month == 2) {
#    return read_text("$FindBin::Bin/templates/iyar_msg.txt");
#  }
  return "";
}
#==================================================

sub ical_month {
    my(@month) = @_;

    my @events;

    for my $d_index (0..$#month - 1) {
        my $d = $month[$d_index];
        my $tomorrow = $month[$d_index + 1];
        if ($d->holiday) {
            for my $day_event (qw(name notice parsha)) {
                if ($d->holiday->$day_event) {
                    my @day_events;
                    if (ref($d->holiday->$day_event)) {
                        @day_events = @{$d->holiday->$day_event};
                    }
                    else {
                        @day_events = ($d->holiday->$day_event );
                    }

                    for my $day_event (@day_events) {
                        my $summary = e2h($day_event);
                        my $start = sprintf("%4.4d%2.2d%2.2d", $d->e_year, $d->e_month, $d->e_day);
                        my $end = sprintf("%4.4d%2.2d%2.2d", $tomorrow->e_year, $tomorrow->e_month, $tomorrow->e_day);
                        push(@events, <<EndText);
BEGIN:VEVENT
DTSTART;VALUE=DATE:$start
DTEND;VALUE=DATE:$end
SUMMARY:$summary
END:VEVENT
EndText
                    }
                }
            }
        }

        my %davening_times = $d->get_times();
        for my $k (keys %davening_times) {
            my $all_times = $davening_times{$k};
            for my $time (split(/,\s*/, $all_times)) {
                $time =~ s/\s*\(.*//;
                $time =~ s/<.*//;
                my($hour,$min) = split(/:/, $time);
                next unless ($hour && $hour =~ /^\d+$/);
                my $start = sprintf("%4.4d%2.2d%2.2dT%2.2d%2.2d%2.2d", $d->e_year, $d->e_month, $d->e_day, $hour, $min, 0);
                my $summary = e2h($k);
                push(@events, <<EndText);
BEGIN:VEVENT
DTSTART;TZID=Asia/Jerusalem:$start
DTEND;TZID=Asia/Jerusalem:$start
SUMMARY:$summary
END:VEVENT
EndText
            }
        }
    }

    my $ical_header = <<EndText;
BEGIN:VCALENDAR
PRODID:Data::ICal 0.16
VERSION:2.0
EndText
    my $ical_footer = <<EndText;
END:VCALENDAR
EndText

    return join('', $ical_header, @events, $ical_footer);
}

#----------------------------------------------------------------------

sub get_stylesheet {
return <<EOFText;
p { font-size: 100% }
td { font-size: 100% }

.entire_calendar {  background-color: #ffffff; direction: rtl; width: 100%; border: 1px solid black }
	  .day_cell  { border: 1px solid black; height: 100%; vertical-align: top;  }
	  .general_tefillah_times { font-size: 0.62em; background: #bbffff; border: 1px solid black; padding: 1px 5px } 
	  .general_tefillah_times table.regular_times tr td { font-size: 0.62em; white-space: nowrap; } 
	  .general_tefillah_times_div { _height: 5em; min-height: 5em } 
	  .days_of_week_header { border: 1px solid black; background: yellow; text-align: center;}
	  .days_of_week_header div { width: 4em }
	  .heb_day_number, .eng_day_number { font-size: 0.62em; margin: 1px 5px }
	  .heb_day_number { float: right }
	  .eng_day_number { float: left }
	  .holiday_name, .holiday_notice { font-size:100%; text-align: center }
          .holiday_notice { margin: 2px }
	  .holiday_name { font-weight: bold }
	  .holiday_notice { clear: both; }
	  .holiday_notice_inner { white-space: nowrap; font-size:0.88em; font-weight: bold; border: 1px solid black; background: #cccccc }
	  .parsha_name { text-align: right; clear: both; font-family: cursive }
	  .bar_mitzva { text-align: right; font-size: 0.75em; white-space: nowrap; clear: both; font-family: Arial; vertical-align: top }
	  .subparsha_name { font-size: 0.62em }
	  .tefillah_times_inner_box { clear: both }
	  .holiday_name, .parsha_name,.tefillah_times_inner_box,
      .tefillah_times_inner_box tr, .tefillah_times_inner_box tr td { margin: 0px; padding: 0px; border-spacing: 0px }
      .tefillah_times_inner_box tr td.tefillah_name { font-size: 0.75em; white-space: nowrap; text-align: right; }
      .tefillah_times_inner_box tr td.tefillah_time { font-size: 0.75em; padding-right: 15px; white-space: nowrap; text-align: right; }
	  .calendar_header { direction: rtl; font-family: cursive; text-align: center; font-weight: bold }
	  .month_header { direction: rtl; margin-top: 8px; text-align: center; font-weight: bold; font-style: italic }
	  .calendar_footer { direction: rtl; font-size: 0.75em; text-align: right }
          .nowrap { white-space: nowrap }
.inner_day { height: 100%; width: 100% }
.inner_day_top { vertical-align: top }
.inner_day_bottom { font-size: 0.62em; text-align: center; vertical-align: bottom;  }
.preomer_div { padding: 5px }
.omer_div { font-size: 0.62em; padding: 2px; clear: both; text-align: center; position: absolute; bottom: 0; width: 100% }
.matnas_cell { background: #ffccff;  font-size: 0.5em; font-weight: bold; border: 1px solid black }
.all_day_div { min-height: 100px; position: relative }
table, tr, td { border-collapse: collapse }
EOFText
}

