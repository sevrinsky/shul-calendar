#!/usr/bin/perl -w

use FindBin;
use lib $FindBin::Bin;

use strict;
use CGI::Pretty;
use ShulCal::Day;
use ShulCal::Util qw(gematria e2h);
use DateTime::Calendar::Hebrew;
use DateTime;
use Getopt::Long;
use Date::Format;

our @tefillot;
our %tef_order_lookup;
our @weekday_start;


#--------------------------------------------------

my @months = (12,13,1..11);
#my @months = (12);
my @heb_months = ('', 'ניסן', 'אייר', 'סיון', 'תמוז', 'מנחם-אב', 'אלול', 'תשרי', 'חשון', 'כסלו', 'טבת', 'שבט', 'אדר', 'אדר ב\'');
my @eng_months = ('', 'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני', 'יולי', 'אגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר');

our $q = new CGI::Pretty("");

print "<html>";
print <<EOFText;
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<style>
.holiday { color: red }
.heb_time, .heb_date_part { direction: rtl }
</style>
</head>
EOFText
print "<body><table>\n";
for my $month (@months) {
  my @month = make_month(year => ($month > 11 || $month < 7 ? 5765 : 5766),
                         month => $month);

  for my $d (@month) {
    my @other;
    if ($d->{holiday} && $d->{holiday}->{name}) {
      if (ref($d->{holiday}->{name})) {
        push(@other, map($q->div({-class=>'holiday'},e2h($_)), @{$d->{holiday}->{name}}));
      } else {
        push(@other, $q->div({-class=>'holiday'},e2h($d->{holiday}->{name})));
      }
    }
    if ($d->{holiday} && $d->{holiday}->{parsha}) {
      push(@other, e2h("parsha") . ": " . e2h($d->{holiday}->{parsha}));
      if ($d->{holiday}->{subparsha}) {
        $other[-1] .= ", " . e2h("shabbat") . " " . e2h($d->{holiday}->{subparsha});
      }
      $other[-1] = $q->div({-class => "shabbat"}, $other[-1]);
    }
    my %times = $d->get_times();
    if ($times{kl}) {
      push(@other, 
           $q->table($q->TR($q->td({-class => 'eng_time'}, "Candle Lighting:"),
                            $q->td({-class => 'time'}, $times{kl}),
                            $q->td({-class => 'heb_time'}, e2h("candle lighting long") . ":"))));
    }
    if ($times{motzash}) {
      push(@other, 
           $q->table($q->TR($q->td({-class => 'eng_time'}, "End Shabbat:"),
                            $q->td({-class => 'time'}, $times{motzash}),
                            $q->td({-class => 'heb_time'}, e2h("end shabbat long") . ":"))));
    }
    if ($times{'motzei shabbat and chag'}) {
      push(@other, 
           $q->table($q->TR($q->td({-class => 'eng_time'}, "End Shabbat and Chag:"),
                            $q->td({-class => 'time'}, $times{'motzei shabbat and chag'}),
                            $q->td({-class => 'heb_time'}, e2h("end shabbat and chag long") . ":"))));
    }
    if ($times{'motzei chag'}) {
      push(@other, 
           $q->table($q->TR($q->td({-class => 'eng_time'}, "End Chag:"),
                            $q->td({-class => 'time'}, $times{'motzei chag'}),
                            $q->td({-class => 'heb_time'}, e2h("end chag long") . ":"))));
    }
    next unless @other;
    my $datepart = time2str("%a %e %b" , DateTime->from_object(object => $d)->epoch) . " / " . $q->span({-class => 'heb_date_part'}, gematria($d->day) . " " . $heb_months[$d->month]);
    
    print $q->TR($q->td({-valign => 'top', -align => 'left'}, $datepart),
                 $q->td({-valign => 'top', -align => 'center'}, join("\n",@other))) . "\n\n";
  }
}

print "</table></body></html>\n";
exit();

#==================================================

sub month_header {
  my(@month) = @_;
  my @heb_months = ('', 'ניסן', 'אייר', 'סיון', 'תמוז', 'מנחם-אב', 'אלול', 'תשרי', 'חשון', 'כסלו', 'טבת', 'שבט', 'אדר', 'אדר ב\'');
  my @eng_months = ('', 'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני', 'יולי', 'אגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר');
  
  my $date = $month[1];
  my $next_month_date = $month[-1];

  my $year_gem = gematria($date->year);
  $year_gem =~ s/(..)$/\"$1/;
  my $month_string = $heb_months[$date->month];
  if ($date->month == 12 && DateTime::Calendar::Hebrew::_LastMonthOfYear($date->year) == 13) {
    $month_string .= ' א\''; # Adar I in a leap year
  } 

  $month_string .= " $year_gem (";

  if ($next_month_date->e_month != $date->e_month) {
    $month_string .= $eng_months[$date->e_month] . '-' . $eng_months[$next_month_date->e_month] . ')';
  }
  else {
    $month_string .= $eng_months[$date->e_month] . ')';
  }

  return $q->div({-class => "month_header"},
	       $month_string) . "\n\n";
}

#--------------------------------------------------

sub make_month {
  my(%params) = @_;
  my @month;
  push(@month, new ShulCal::Day(%params, day => 1));
  for my $i (2..DateTime::Calendar::Hebrew::_LastDayOfMonth($params{year}, $params{month})) {
    push(@month, new ShulCal::Day(%params,
                                  day => $i));
    $month[-2]->{tomorrow} = $month[-1];
  }
  $month[-1]->{tomorrow} = new ShulCal::Day(%params, month => ($params{month} % DateTime::Calendar::Hebrew::_LastMonthOfYear($params{year})) + 1, day => 1);
  return @month;
}

#--------------------------------------------------

sub month_cal {
  my(@month) = @_;
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
		      maybe_tefillah_times($month[0]->dow_0)));
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
                                      maybe_tefillah_times(7- $month[-1]->dow)
				     )));
  }

  return $q->table({-class => 'entire_calendar',
                    -dir => 'rtl'},
                   $q->TR(\@weeks)) . "\n";
}

#==================================================

sub get_stylesheet {
return <<EOFText;
	  .entire_calendar {  background-color: #ffffff; direction: rtl; width: 100%; border: 1px solid black }
	  .day_cell_0, .day_cell_1, .day_cell_2, .day_cell_3, .day_cell_4, .day_cell_5, .day_cell_6  { border: 1px solid black }
	  .general_tefillah_times { font-size: 10pt; background: #bbffff; border: 1px solid black; padding: 1px 5px; height: 5em } 
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
      .tefillah_times_inner_box tr td.tefillah_time { padding-right: 15px }
	  tr.omer {vertical-align: bottom}
	  td.omer { font-size: 8pt;  }
	  .calendar_header { direction: rtl; font-family: cursive; font-size: 13pt; text-align: center; font-weight: bold }
	  .month_header { direction: rtl; font-size: 12pt; margin-top: 8px; text-align: center; font-weight: bold; font-style: italic }
          .nowrap { white-space: nowrap }
EOFText
}

#<sup>*</sup>מגילת רות לשחרית המוקדמת - 4:40
