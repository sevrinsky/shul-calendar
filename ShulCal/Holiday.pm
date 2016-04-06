package ShulCal::Holiday;

use strict;
use YAML qw(LoadFile);

use File::Basename;
use ShulCal::Util qw(e2h gematria);
use ShulCal::Day;
use DateTime::Calendar::Hebrew;
use DateTime::Duration;
our %holiday_cache;
our $AUTOLOAD;

#----------------------------------------------------------------------

sub new {
  my($class, $date) = @_;
  my $self = {};
  bless($self, $class);
  $self->{_data} = get_holiday($date);
  return $self;
}

#----------------------------------------------------------------------

sub AUTOLOAD {
  my($self) = @_;
  my $field = $AUTOLOAD;
  $field =~ s/.*:://;
  if (exists $self->{_data}->{$field}) {
    return $self->{_data}->{$field};
  }
  return '';
}

#----------------------------------------------------------------------

sub contains {
    my($self, $field) = @_;
    my $name = $self->name();
    if (ref($name) && ref($name) eq 'ARRAY') {
        return grep { /$field/ } @$name;
    }
    else {
        return $name =~ /$field/;
    }
}

#----------------------------------------------------------------------

sub get_holiday {
  my($date) = @_;
  unless ($holiday_cache{$date->year}) {
    generate_cache($date->year);
    generate_cache($date->year - 1) if ($date->month == 7);
    generate_cache($date->year + 1) if ($date->month == 6);
  }

  my $retval = $holiday_cache{$date->year}->{$date->month}->{$date->day};
  # Compute all Shabbatot
  if ($date->dow_0 == 6 && !defined($retval->{yomtov})) {
    unless ($retval->{name} && $retval->{name} =~ /chol hamoed/) {
      my @parsha = get_parsha($date);
      $retval->{parsha} = $parsha[0];
      $retval->{subparsha} = $parsha[1] if ($#parsha > 0 && $parsha[1]);

      if ($holiday_cache{$date->year}->{parsha}->{$retval->{parsha}}) {
          $retval->{bar_mitzva} = $holiday_cache{$date->year}->{parsha}->{$retval->{parsha}}->{bar_mitzva};
          $retval->{shabbat_chatan} = $holiday_cache{$date->year}->{parsha}->{$retval->{parsha}}->{shabbat_chatan};
          $retval->{shabbat_sheva_brachot} = $holiday_cache{$date->year}->{parsha}->{$retval->{parsha}}->{shabbat_sheva_brachot};
          $retval->{non_bar_mitzva} = $holiday_cache{$date->year}->{parsha}->{$retval->{parsha}}->{non_bar_mitzva};
      }
    }
  }

  $retval = {} unless $retval;
  return $retval;
}

#----------------------------------------------------------------------

sub generate_cache {
    my($year) = @_;

    for my $h (@{holiday_list()}) {

        if ($h->{parsha}) {
            $holiday_cache{$h->{year}}->{parsha}->{$h->{parsha}} = $h;
        }
        elsif ($h->{e_month}) {
            # Secular calendar event
            my $e_year = $year - 3760;
            my $date = DateTime::Calendar::Hebrew->from_object(object => new DateTime(year => $e_year,
                                                                                      month => $h->{e_month},
                                                                                      day => $h->{e_day}));
            if ($date->year != $year) { 
                $date = DateTime::Calendar::Hebrew->from_object(object => new DateTime(year => $e_year - 1,
                                                                                       month => $h->{e_month},
                                                                                       day => $h->{e_day}));
            }
            $holiday_cache{$date->year}->{$date->month}->{$date->day} = $h;
        }
        else {
            if ($h->{month} < 0) {
                $h->{month} = DateTime::Calendar::Hebrew::_LastMonthOfYear($year) + $h->{month} + 1;
            }
            my $delay_dow = -1;
            my $delay_dow_limit = 0;
            if ($h->{day} =~ /(\d+) \+ (\d+)/) {
                my $orig_day = $h->{day};
                $h->{day} = $1;
                $delay_dow = $2;
                if ($orig_day =~ /limit (\d+)/) {
                    $delay_dow_limit = $1;
                }
            }

            my $duration = 1;
            if (defined($h->{duration})) {
                $duration = $h->{duration};
            }

            my $date = new DateTime::Calendar::Hebrew(year => $year,
                                                      month => $h->{month},
                                                      day => $h->{day});
            if ($delay_dow > -1) {
                if ($date->dow_0 < $delay_dow) {
                    my $delay_duration = new DateTime::Duration(days => $delay_dow - $date->dow_0);
                    if ($delay_dow_limit && $delay_duration->days > $delay_dow_limit) {
                        next;
                    }
                    $date = $date + $delay_duration;
                }
            }

            if (defined($h->{disallow_dow})) {
                my %disallow_dow = map { ($_ => 1) } split(/,/, $h->{disallow_dow});
                while ($disallow_dow{$date->dow_0}) {
                    if ($date->dow_0 > 3) {
                        $date = $date - new DateTime::Duration(days => 1);
                    }
                    else {
                        $date = $date + new DateTime::Duration(days => 1);
                    }
                }
            }

            if (defined($h->{dow_times})) {
                if ($date->dow_0 == $h->{dow_times}->{dow}) {
                    $h->{times} = $h->{dow_times}->{times};
                }
            }

            if ($h->{name} && $h->{name} eq 'zot chanukah' && DateTime::Calendar::Hebrew::_ShortKislev($year)) {
                $date = $date + new DateTime::Duration(days => 1);
            }

            if ($h->{fast} && $date->dow_0 == 6 && $h->{name} !~ /kippur/) {
                if ($h->{name} =~ /esther/) {
                    $date = $date - new DateTime::Duration(days => 2);
                    $holiday_cache{$date->year}->{$date->month}->{13} = { times => { 'megillah reading' => $h->{times}->{'megillah reading'} } };
                    delete $h->{times}->{'megillah reading'};
                }
                else {
                    $h->{fast_delayed} = 1;
                    $date = $date + new DateTime::Duration(days => 1);
                }
            }

            if ($h && exists $h->{name} && 
                (($h->{name} eq 'yom hazikaron' && $date->dow_0 == 0) || 
                 ($h->{name} eq 'yom haatzmaut' && $date->dow_0 == 1))) {
                $date = $date + new DateTime::Duration(days => 1);
            }

            if ($h->{yomtov} && $h->{name} &&
                (($date->dow_0 == 5 && $h->{name} !~ /rosh hashana/) || 
                 ($date->dow_0 == 4 && $h->{name} =~ /rosh hashana/))) {
                my $eruv_tavshilin_date = $date - new DateTime::Duration(days => 1);

                $holiday_cache{$eruv_tavshilin_date->year}->{$eruv_tavshilin_date->month} = {} unless (exists $holiday_cache{$eruv_tavshilin_date->year}->{$eruv_tavshilin_date->month});
                my $cache_eruv_tavshilin_month = $holiday_cache{$eruv_tavshilin_date->year}->{$eruv_tavshilin_date->month};
                $cache_eruv_tavshilin_month->{$eruv_tavshilin_date->day} = {} unless exists $cache_eruv_tavshilin_month->{$eruv_tavshilin_date->day};
                $cache_eruv_tavshilin_month->{$eruv_tavshilin_date->day} = { %{$cache_eruv_tavshilin_month->{$eruv_tavshilin_date->{day}}},
                                                                             notice => 'eruv tavshilin',
                                                                           };
            }
            if ($h && exists $h->{bottom_notice} && 
                $h->{bottom_notice} eq 'erev chanukah' && $date->dow_0 == 6) {
                $h->{bottom_notice}  = 'erev chanukah motzash';
            }

            for my $d (1..$duration) {
                my $new_h = { %$h };
                if ($new_h->{name}) {
                    $new_h->{name} = gematria($d) . "' " . $new_h->{name} if ($duration > 1);
                }
                $new_h->{duration_instance} = $d;

                if ($date->dow_0 == 6) { # No shofar on Shabbat
                    for my $k (grep(/shofar/, keys %{$h->{times}})) {
                        delete $new_h->{times}->{$k};
                    }
                }

                $holiday_cache{$date->year}->{$date->month}->{$date->day} = {} 
                  unless exists $holiday_cache{$date->year}->{$date->month}->{$date->day};

                $holiday_cache{$date->year}->{$date->month}->{$date->day} = {
                                                                             %{$holiday_cache{$date->year}->{$date->month}->{$date->day}},
                                                                             %$new_h,
                                                                            };
                $date = $date + new DateTime::Duration(days => 1);
            }
        }
    }

    my $rosh_hashana = DateTime->from_object(object => ShulCal::Day::get_rosh_hashana($year));
    for my $dst_year ($rosh_hashana->year..$rosh_hashana->year + 1) {
        my $dst_start_date = DateTime::Calendar::Hebrew->from_object(object => ShulCal::Day::dst_start_date($dst_year));
        $holiday_cache{$dst_start_date->year}->{$dst_start_date->month}->{$dst_start_date->day}->{notice} = 'start summer time';

        my $dst_end_date = DateTime::Calendar::Hebrew->from_object(object => ShulCal::Day::dst_end_date($dst_year));
        $holiday_cache{$dst_end_date->year}->{$dst_end_date->month}->{$dst_end_date->day}->{notice} = 'end summer time';
    }

    # Compute all rosh chodeshes
    my $last_month_30_day = 0;
    for my $month (7..DateTime::Calendar::Hebrew::_LastMonthOfYear($year), 1..6) {
        if ($month != 7) {
            # No rosh chodesh in Tishrei
            if ($holiday_cache{$year}->{$month}->{1}->{name} && !ref($holiday_cache{$year}->{$month}->{1}->{name})) {
                $holiday_cache{$year}->{$month}->{1}->{name} = [ $holiday_cache{$year}->{$month}->{1}->{name} ];
            }

            push(@{$holiday_cache{$year}->{$month}->{1}->{name}}, ($last_month_30_day ? 'rosh chodesh 2' : 'rosh chodesh'));
        }

        if ($holiday_cache{$year}->{$month}->{30}->{name} && !ref($holiday_cache{$year}->{$month}->{30}->{name})) {
            $holiday_cache{$year}->{$month}->{30}->{name} = [ $holiday_cache{$year}->{$month}->{30}->{name} ];
        }
        if (DateTime::Calendar::Hebrew::_LastDayOfMonth($year, $month) == 30) {
            push(@{$holiday_cache{$year}->{$month}->{30}->{name}}, 'rosh chodesh 1');
            $last_month_30_day = 1;
        }
        else {
            $last_month_30_day = 0;
        }
    }
}

#--------------------------------------------------

sub holiday_list {
  return LoadFile(find_package_path() . "/../holidays.yaml");
}

#--------------------------------------------------

sub get_parsha {
  my($date) = @_;

  # Figure out which week in the Jewish year we are currently in.
  # Add weeks for holidays that were on Shabbat.
  # Special case double-ups, check leap year.

  my $pesach_date = DateTime::Calendar::Hebrew->new(year => $date->year,
                                                    month => 1,
                                                    day => 15);
  my $pesach_time = DateTime->from_object(object => $pesach_date)->epoch;
  my @parshiot = @{LoadFile(find_package_path() . "/../parshiot.yaml")};
  my $parsha;
  my $nitzavim_index = 50;
  # Hard coded fix for 5764 - joined parshiot - todo: write real code for this
  # Still needs real code, but for just don't join in leap years
  if (DateTime::Calendar::Hebrew::_LastMonthOfYear($date->year) == 12) {
    splice(@parshiot, 21, 2, $parshiot[21] . '-' . $parshiot[22]); # vayakhel-pekudei
    splice(@parshiot, 25, 2, $parshiot[25] . '-' . $parshiot[26]); # tazria-metzora
    splice(@parshiot, 26, 2, $parshiot[26] . '-' . $parshiot[27]); # acharei mot-kedoshim
    $nitzavim_index -= 3;

    if ($pesach_date->dow_0 != 6) {
        # If Pesach falls on Shabbat, Behar-Bechukotai are separate
        splice(@parshiot, 28, 2, $parshiot[28] . '-' . $parshiot[29]); # behar-bechukotai
        splice(@parshiot, 37, 2, $parshiot[37] . '-' . $parshiot[38]); # matot-maasei
        $nitzavim_index -= 2;
    }
    else {
        splice(@parshiot, 38, 2, $parshiot[38] . '-' . $parshiot[39]); # matot-maasei
        $nitzavim_index--;
    }
  }

  my $next_rosh_hashana = ShulCal::Day::get_rosh_hashana($date->year + 1);
  if ($next_rosh_hashana->dow_0 > 2) {
      # Joined in most years, including leap years
      splice(@parshiot, $nitzavim_index, 2, $parshiot[$nitzavim_index] . '-' . $parshiot[$nitzavim_index + 1]); # nitzavim-vayelech
  }

  my $subparsha = undef;
  if ($date->day < 15 && $date->month == 7) {
      my $rosh_hashana = ShulCal::Day::get_rosh_hashana($date->year);
      if ($rosh_hashana->dow_0 <= 2 && $date->day <= 7) {
          $parsha = "vayelech";
      } else {
          $parsha = "haazinu";
      }
      if ($date->day < 10) {
          $subparsha = "shuva";
      }
  } else {

    my $date_time = DateTime->from_object(object => $date)->epoch;

    if ($date_time < $pesach_time) {
      my $rh_adar = new DateTime::Calendar::Hebrew(year => $date->year,
                                                   month => DateTime::Calendar::Hebrew::_LastMonthOfYear($date->year),
                                                   day => 1);
      my $rh_adar_time = DateTime->from_object(object => $rh_adar)->epoch;
      my $adar_difference = ($date_time - $rh_adar_time) / (60*60*24);
      my $pesach_difference = ($date_time - $pesach_time) / (60*60*24);

      if ($adar_difference >= -6 &&
          $adar_difference <= 0) {
        $subparsha = 'shekalim';
      }

      # Special parsha rules are as follows:
      # The shabbat on or preceding RH Adar is Shekalim.
      # The other 3 parshiot follow on the following weeks, in the 
      # following configuration: bu dad u'biu zatu
      # Bu - RH Adar on Monday, skip Adar 6 (1st Sh)
      # Dad - RH Adar on Monday, skip Adar 4 (1st Sh)
      # U'biu - RH Adar on Friday, skip Adar 2 (1st Sh) and 16 (3rd Sh)
      # Zatu - RH Adar on Shabbat, skip Adar 15 (3rd Sh) [Adar 1 is shekalim]
      my @other_parshiot = ( 'zachor','parah', 'hachodesh');

      if ($rh_adar->dow_0 == 5 || $rh_adar->dow_0 == 6) {
        splice(@other_parshiot, 1, 0, ''); # U'biu and Zatu years
      }
      if ($adar_difference > 0 && $adar_difference <= 29) {
        # HaChodesh can be as late as Sh A' RH Nissan = day 29
        my $week = int($adar_difference / 7) + 1;
        $subparsha = $other_parshiot[$week - 2] if ($week > 1);
      }

      if ($pesach_difference >= -7 && $pesach_difference <= -1) {
        # HaGadol
        $subparsha = 'hagadol';
        # If before pesach, parsha is week number - 4
      }
      $parsha = $parshiot[$date->week - 3];
    } else {
      # After pesach, add one week for Chol HaMoed
      $parsha = $parshiot[$date->week - 4];
    }

    # Handling for special parshiot
    if (defined($parsha)) {
      if ($parsha eq "beshalach") {
        $subparsha = "shira";
      }
      if ($parsha eq "devarim") {
        $subparsha = "chazon";
      }
      if ($parsha eq "vaetchanan") {
        $subparsha = "nachamu";
      }
    }


  }
  return ($parsha, $subparsha);

}

#----------------------------------------------------------------------

sub find_package_path {
  my $package = __PACKAGE__;
  $package =~ s/::/\//g;
  $package .= ".pm";
  return dirname($INC{$package});
}

1;
