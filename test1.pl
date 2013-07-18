#!/usr/bin/perl -w

use FindBin;
use lib $FindBin::Bin;

use strict;
use CGI::Pretty;
use ShulCal::Day;
use ShulCal::Util qw(gematria e2h eng_month heb_month);
use DateTime::Calendar::Hebrew;
use Getopt::Long;
use File::Slurp qw(slurp);
use Data::ICal;
use Data::ICal::Entry::Event;
use Date::ICal;

my $q;

our @tefillot;
our %tef_order_lookup;
our @weekday_start;

our @day_of_week = qw(Sunday Monday Tuesday Wednesday Thursday Friday Shabbat);
our @hebrew_month = qw(junk Nissan Iyar Sivan Tamuz Av Elul Tishrei Marcheshvan Kislev Tevet Shvat Adar Adar2);

{
  my $printed_times = 0;
  sub maybe_tefillah_times {
    my($days_remaining, $month) = @_;
    if ($days_remaining < 3 || $printed_times) {
      return "&nbsp;";
    }
    $printed_times = 1;
    my $msg =  slurp("$FindBin::Bin/templates/weekday_times.txt");
    $msg .= maybe_month_message($month);
    return $msg;
  } 
}


#--------------------------------------------------

my $current_year;
my @months;
my $fullpage;
my $ical_mode;
GetOptions('year=i' => \$current_year,
           'month=s' => \@months,
           'fullpage!' => \$fullpage,
           'ical!' => \$ical_mode,
          );
@months = split(/,/, join(",", @months));
unless (@months) {
  die "Must specify months\n";
}

$current_year ||= 5765;


for my $month (@months) {
  my @month = make_month(year => $current_year,
                         month => $month,
			 is_not_first_month => ($month ne $months[0]));
  
  if ($month == 7) {
    unshift(@month, new ShulCal::Day(year => $current_year - 1,
                                     month => 6, day => 29));
    $month[0]->{tomorrow} = $month[1];
  }
  for my $day (@month) {
    my $time_calc = new Suntimes(day => $day->e_day,
                                 month => $day->e_month,
                                 year => $day->e_year,
                                 londeg => 34,
                                 lonmin => 59.94,
                                 latdeg => 31,
                                 latmin => 42.84,
                                 timezone => 2 + ($day->is_dst ? 1 : 0),
                                 time_constructor => sub { new ShulCal::Time($_[0]) } );
    my $sunrise = $time_calc->sunrise;

    if ($day->shacharit_time !~ /,/) {
      if ($sunrise - $day->shacharit_time > 15) {
        print sprintf("%s, %s %s (%d.%d) - sunrise = %s (shacharit = %s)\n",
                      $day_of_week[$day->dow_0], $hebrew_month[$day->month],
                      $day->day,
                      $day->e_day,
                      $day->e_month,
                      $sunrise,
                      $day->shacharit_time);

#        print $day->e_day . "." . $day->e_month . " - sunrise = $sunrise ( shacharit = " . $day->shacharit_time  . " )\n";
      }
    }

  }
}




exit();

#==================================================

sub month_header {
  my(@month, $month_num) = @_;
  
  my $date = $month[1];
  my $next_month_date = $month[-1];

  my $year_gem = gematria($date->year);
  $year_gem =~ s/(..)$/\"$1/;
  my $month_string = heb_month($date->month);
  if ($date->month == 12 && DateTime::Calendar::Hebrew::_LastMonthOfYear($date->year) == 13) {
    $month_string .= ' א\''; # Adar I in a leap year
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
    # If the first day of the month is Shabbat, add the preceding Friday
    unshift(@month, new ShulCal::Day(%day_params, 
                                     month => $day_params{month} - 1,
                                     day => DateTime::Calendar::Hebrew::_LastDayOfMonth($day_params{year}, $day_params{month} - 1)));
    $month[0]->{tomorrow} = $month[1];
  }

  for my $i (2..DateTime::Calendar::Hebrew::_LastDayOfMonth($day_params{year}, $day_params{month})) {
    push(@month, new ShulCal::Day(%day_params,
                                  day => $i));
    $month[-2]->{tomorrow} = $month[-1];
  }
  $month[-1]->{tomorrow} = new ShulCal::Day(%day_params, month => ($day_params{month} % DateTime::Calendar::Hebrew::_LastMonthOfYear($day_params{year})) + 1, day => 1);
  return @month;
}

#--------------------------------------------------

sub month_cal {
  my($month_num, @month) = @_;
  my @row;
  my @weeks;
  my @days_of_week_h = ('ראשון', 'שני','שלישי','רביעי','חמישי','שישי','שבת');
  push(@weeks, join("",map($q->td({-bgcolor => 'yellow',
				   -align => 'center',
                                   -class => 'days_of_week_header'},
                                  $q->div($_)), 
			   @days_of_week_h)));
  
  if ($month[0]->dow_0) {
    push(@row, $q->td({-colspan => $month[0]->dow_0,
		       -class => 'general_tefillah_times'},
		      $q->div({-class => 'general_tefillah_times_div'},
			      maybe_tefillah_times($month[0]->dow_0, $month_num))));
  }

  for my $d (@month) {

#    my %davening_times = compute_davening_times($holiday, $holiday_tomorrow, $date);

    push(@row, $q->td({-valign => 'top', -align=>'right', 
                       -class => 'day_cell_' . $d->dow_0}, 
		      $d->print_cell($q)) . "\n");

    if ($d->dow_0 == 6) {
      push(@weeks, join("",@row));
      @row = ();
    }
  }

  if ($month[-1]->dow_0 != 6) {
    push(@weeks, join("",@row, $q->td({-colspan => (7 - $month[-1]->dow),
                                       -class => 'general_tefillah_times'}, 
				      $q->div({-class => 'general_tefillah_times_div'},
					      maybe_tefillah_times(7- $month[-1]->dow, $month_num))
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
    return slurp("$FindBin::Bin/templates/tishrei_msg.txt");
  }
  if ($month == 3) {
    return slurp("$FindBin::Bin/templates/sivan_msg.txt");
  }
  if ($month == 2) {
    return slurp("$FindBin::Bin/templates/iyar_msg.txt");
  }
  return "";
}
#==================================================

sub ical_month {
  my(@month) = @_;

  my $calendar = Data::ICal->new();

  for my $d (@month) {
    if ($d->holiday) {
      for my $day_event (qw(name notice parsha)) {
        if ($d->holiday->$day_event) {
          my $vtodo = Data::ICal::Entry::Event->new();
          $vtodo->add_properties(
                                 summary => e2h($d->holiday->$day_event),
                                 dtstart => Date::ICal->new ( day => $d->e_day, 
                                                              month => $d->e_month, 
                                                              year => $d->e_year,
                                                            )->ical,
                                 dtend => Date::ICal->new ( day => $d->e_day, 
                                                            month => $d->e_month, 
                                                            year => $d->e_year,
                                                          )->ical,
                                );
          $calendar->add_entry($vtodo);
        }
      }
    }

    my %davening_times = $d->get_times();
    for my $k (keys %davening_times) {
      my $vtodo = Data::ICal::Entry::Event->new();
      my $time = $davening_times{$k};
      $time =~ s/,.*//;
      $time =~ s/\s*\(.*//;
      $time =~ s/<.*//;
      my($hour,$min) = split(/:/, $time);
      $vtodo->add_properties(
                             summary => e2h($k),
                             dtstart => Date::ICal->new ( day => $d->e_day, 
                                                          month => $d->e_month, 
                                                          year => $d->e_year,
                                                          hour => $hour,
                                                          min => $min,
                                                          sec => 00
                                                        )->ical,
                             dtend => Date::ICal->new ( day => $d->e_day, 
                                                        month => $d->e_month, 
                                                        year => $d->e_year,
                                                        hour => $hour,
                                                        min => $min,
                                                        sec => 00
                                                      )->ical,
                            );
      $calendar->add_entry($vtodo);
    }
  }

  return $calendar->as_string;
}

#----------------------------------------------------------------------

sub get_stylesheet {
return <<EOFText;
	  .entire_calendar {  background-color: #ffffff; direction: rtl; width: 100%; border: 1px solid black }
	  .day_cell_0, .day_cell_1, .day_cell_2, .day_cell_3, .day_cell_4, .day_cell_5, .day_cell_6  { border: 1px solid black; height: 100% }
	  .general_tefillah_times { font-size: 10pt; background: #bbffff; border: 1px solid black; padding: 1px 5px } 
	  .general_tefillah_times_div { _height: 5em; min-height: 5em } 
	  .days_of_week_header { border: 1px solid black}
	  .days_of_week_header div { width: 4em }
	  .heb_day_number, .eng_day_number { font-size: 10pt; margin: 1px 5px }
	  .heb_day_number { float: right }
	  .eng_day_number { float: left }
	  .holiday_name, .holiday_notice { text-align: center }
	  .holiday_name { font-size: 12pt; font-weight: bold }
	  .holiday_notice { clear: both; }
	  .holiday_notice_inner { font-size: 10pt; font-weight: bold; border: 1px solid black; background: #cccccc}
	  .parsha_name { font-size: 12pt; text-align: right; clear: both; font-family: cursive }
	  .subparsha_name { font-size: 10pt }
	  .tefillah_name,.tefillah_time { font-size: 7pt }
	  .tefillah_times_inner_box { clear: both }
	  .holiday_name, .parsha_name,.tefillah_times_inner_box,
      .tefillah_times_inner_box tr, .tefillah_times_inner_box tr td { margin: 0px; padding: 0px; border-spacing: 0px }
      .tefillah_times_inner_box tr td.tefillah_name { white-space: nowrap }
      .tefillah_times_inner_box tr td.tefillah_time { padding-right: 15px; white-space: nowrap }
	  tr.omer {vertical-align: bottom}
	  td.omer { font-size: 8pt;  }
	  .calendar_header { direction: rtl; font-family: cursive; font-size: 13pt; text-align: center; font-weight: bold }
	  .month_header { direction: rtl; font-size: 12pt; margin-top: 8px; text-align: center; font-weight: bold; font-style: italic }
	  .calendar_footer { direction: rtl; font-size: 11pt; text-align: right }
          .nowrap { white-space: nowrap }
.inner_day { height: 100%; width: 100% }
.inner_day_top { vertical-align: top }
.inner_day_bottom { font-size: 8pt; text-align: center; vertical-align: bottom;  }
.matnas_cell { background: #ffccff;  font-size: 7pt; font-weight: bold; border: 1px solid black }
EOFText
}

