package ShulCal::Day;

use strict;
use Memoize;
use Encode;

use DateTime::Calendar::Hebrew;
use ShulCal::Util qw(e2h gematria);
use ShulCal::Holiday;
use ShulCal::Time;
use Suntimes;
use base 'DateTime::Calendar::Hebrew';

memoize 'get_rosh_hashana';
memoize 'get_pesach';
memoize 'dst_start_date';
memoize 'dst_end_date';

our @weekday_start = map { new ShulCal::Time($_) } (qw(6:30 6:20 6:30 6:30 6:20 6:30));
our $DAF_YOMI_DURATION = 40;
our $HORIM_VYELADIM_DURATION = 40;

#==================================================

sub new {
  my($class, @params) = @_;
  my $self = $class->SUPER::new(@params);
  $self->init;
  return $self;
}


sub init {
  my($self) = @_;
  $self->{_holiday} = ShulCal::Holiday->new($self);
}
#--------------------------------------------------

sub print_cell {
  my($self, %params) = @_;
  my $q = $params{html_page};
  my $include_shul_times = defined $params{include_shul_times} ? $params{include_shul_times} : 1;
  my $include_shiur_times = defined $params{include_shiur_times} ? $params{include_shiur_times} : 1;
  my $include_chofesh_hagadol = defined $params{include_chofesh_hagadol} ? $params{include_chofesh_hagadol} : 1;
  my $include_late_friday = defined $params{include_late_friday} ? $params{include_late_friday} : 1;
  my $include_youth_minyan = defined $params{include_youth_minyan} ? $params{include_youth_minyan} : 1;
  my $include_bezman_mincha = defined $params{include_bezman_mincha} ? $params{include_bezman_mincha} : 1;

  my @inside_rows = ();
  my $holiday = $self->holiday;
  my %davening_times = $self->get_times(include_chofesh_hagadol => $include_chofesh_hagadol,
                                        include_late_friday => $include_late_friday,
                                        include_youth_minyan => $include_youth_minyan,
                                        include_bezman_mincha => $include_bezman_mincha,
                                       );
  if (! $include_shul_times) {
      my %nonshul_times = map { ($_ => 1) } ('candle lighting',
                                             'motzash',
                                             'plag hamincha',
                                             'early shabbos mincha',
                                            );
      for my $k (keys %davening_times) {
          if (! $nonshul_times{$k}) {
              delete $davening_times{$k};
          }
      }
  }
  if (! $include_shiur_times) {
      my %shiur_times = map { ($_ => 1) } ('horim vyeladim',
                                           'daf yomi',
                                          );
      for my $k (keys %shiur_times) {
          if (exists $davening_times{$k}) {
              delete $davening_times{$k};
          }
      }
  }

  push(@inside_rows, $q->div({-class => 'day_number_row'},
                            $q->span({-class => 'heb_day_number'}, 
                                   gematria($self->day)),
                            $q->span({-class => 'eng_day_number'}, 
                                   $self->e_day)));

  if ($holiday->name) {
      if (ref($holiday->name) eq 'ARRAY') {
          push(@inside_rows, map( $q->div({-class => 'holiday_name'}, e2h($_)), @{$holiday->name}));
      } 
      elsif ($holiday->{fast_delayed}) {
          push(@inside_rows, $q->div({-class => 'holiday_name'}, e2h($holiday->name) . ' ' . e2h('delayed')));
      }
      else {
          push(@inside_rows, $q->div({-class => 'holiday_name'}, e2h($holiday->name)));
      }

  }
  if ($holiday->notice) {
    push(@inside_rows, $q->div({-class => 'holiday_notice'}, $q->div({-class => 'holiday_notice_inner'}, "&nbsp;" . e2h($holiday->notice) . "&nbsp;")));
  }

  if ($holiday->parsha) {
    my $parsha = join("-", map(e2h($_), split(/-/,$holiday->parsha)));
    $parsha .= qq| - <span class="subparsha_name">| . e2h($holiday->subparsha) . "</span>" if ($holiday->subparsha);
    push(@inside_rows, $q->div({-class => 'parsha_name'}, $parsha));
  }

  my @davening_rows = ();
  if ($holiday->bar_mitzva) {
      my @bar_mitzva = ($holiday->bar_mitzva);
      if (ref($holiday->bar_mitzva)) {
          @bar_mitzva = @{$holiday->bar_mitzva};
      }

      for my $bm (@bar_mitzva) {
          push(@davening_rows, $q->TR(
                                      $q->td({-class => 'bar_mitzva tefillah_name'}, e2h('bar mitzva') . ":"),
                                      $q->td({-class => 'bar_mitzva tefillah_time'},$bm)));
      }
  }

  if ($holiday->shabbat_chatan) {
      my @shabbat_chatanim = ($holiday->shabbat_chatan);

      for my $shabbat_chatan (@shabbat_chatanim) {
          push(@davening_rows, $q->TR(
                                      $q->td({-class => 'bar_mitzva tefillah_name'}, e2h('shabbat chatan') . ":"),
                                      $q->td({-class => 'bar_mitzva tefillah_time'}, $shabbat_chatan)));
      }
  }

  if ($holiday->shabbat_sheva_brachot) {
      my @shabbat_lines = ($holiday->shabbat_sheva_brachot);

      for my $shabbat_line (@shabbat_lines) {
          push(@davening_rows, $q->TR(
                                      $q->td({-class => 'bar_mitzva tefillah_name'}, e2h('shabbat sheva brachot') . ":"),
                                      $q->td({-class => 'bar_mitzva tefillah_time'}, $shabbat_line)));
      }
  }

  if ($holiday->non_bar_mitzva) {
      push(@davening_rows, $q->TR(
                                  $q->td({-colspan => 2, -class => 'bar_mitzva tefillah_time'},$holiday->non_bar_mitzva)));
  }

  my $has_extra_class = 0;
  if (%davening_times) {
    my $has_matnas = 0;
    for my $k (keys %davening_times) {
      $has_matnas = 1 if $self->is_matnas($holiday, $k);
    }

    for my $k (sort_by_davening(%davening_times)) {
      
      my @tefillah_row = ($q->td({-class => "tefillah_name"}, e2h($k) . ($davening_times{$k} =~ /\S/ ? ":" : '')),
			  $q->td({-class => "tefillah_time"},  $davening_times{$k}));

      if ($has_matnas) {
	if ($self->is_matnas($holiday, $k)) {
	  unshift(@tefillah_row, $q->td({-class => "matnas_cell"},
					"מ"),
		 $q->td({-class => 'tefillah_name'},'&nbsp;'));
	} else {
	  unshift(@tefillah_row, 		 
		  $q->td({-class => 'tefillah_name'},'&nbsp;'),
		  $q->td({-class => 'tefillah_name'},'&nbsp;'));
	}
      }

      push(@davening_rows, $q->TR(@tefillah_row));
    }

    push(@inside_rows,
         $q->table({-class => 'tefillah_times_inner_box'},
                   @davening_rows));
  }

  if ($holiday->bottom_notice) {
    push(@inside_rows, $q->div({-class => 'holiday_notice'}, $q->div({-class => 'holiday_notice_inner'}, "&nbsp;" . e2h($holiday->bottom_notice) . "&nbsp;")));
  }
#   if ($self->get_omer()) {
#     return $q->table({-class => 'inner_day', -cellpadding=> 0, -cellspacing=> 0, -border => 0}, 
#                      $q->TR({-class => 'inner_day_top'}, 
#                             $q->td(join("\n", @inside_rows))),
#                      $q->TR({-class => 'inner_day_bottom'}, 
#                             $q->td($self->get_omer())));
#   } else {
#     return join("\n", @inside_rows);
#   }

  if ($self->get_omer()) {
    push(@inside_rows,
         $q->div({-class => 'preomer_div'},
                 ''),
         $q->div({-class => 'omer_div'},
                 $self->get_omer));
  }
  return $q->div({-class => 'all_day_div'},
                 join("\n", @inside_rows));
}

#--------------------------------------------------

sub is_matnas {
  my($self, $holiday, $tefillah) = @_;

  return 0; # temporarilly disable all matnas, pending shul building
  if ($holiday->name && 
      ($holiday->name eq 'yom kippur' || 
       ($holiday->name eq 'erev yom kippur' && $tefillah =~ /^kol nidre|arvit/) ||
       ($holiday->name eq 'erev rosh hashana' && $tefillah =~ /^(mincha|arvit)/) ||
       ($holiday->name =~ /' rosh hashana/ && $tefillah =~ /^(shacharit|shofar|arvit|motzei chag)$/) ||
       ($holiday->name =~ /ב' rosh hashana/ && $tefillah eq 'mincha') ||
       ($holiday->name eq 'hoshana rabbah' && $tefillah =~ /^(mincha|arvit)$/) ||
       ($holiday->name eq 'simchat torah' && $tefillah =~ /^(shacharit|hakafot)$/) 
      )) {
    return 1;
  }
  return 0;
}

#--------------------------------------------------

sub get_times {
  my($self, %params) = @_;
  my $include_chofesh_hagadol = $params{include_chofesh_hagadol};
  my $include_late_friday = $params{include_late_friday};
  my $force_include_late_friday = 0;
  my $global_include_youth_minyan = $params{include_youth_minyan};
  my $include_bezman_mincha = $params{include_bezman_mincha};
  my $include_holiday_times = 1;
  my $holiday = $self->holiday;
  my $tom_holiday;
  if ($self->{tomorrow}) {
    $tom_holiday = $self->{tomorrow}->holiday;
  }
  my %davening_times;
  if ($holiday->times) {
    %davening_times = %{$holiday->times};
  }
  for my $k (keys %davening_times) {
    my $t = $davening_times{$k};
    if ($t =~ /^(\d+:\d+)$/) {
      $davening_times{$k} = new ShulCal::Time($t);
    }
    if ($t =~ m|//|) {
      delete $davening_times{$k};
      for my $possible_rec (split(m|//|, $t)) {
        my($dow_or_range, $possible_time) = split(m|/|, $possible_rec);
        my($dow_start) = $dow_or_range;
        my($dow_end) = $dow_or_range;
        if ($dow_or_range =~ /-/) {
          ($dow_start, $dow_end) = split(/-/, $dow_or_range);
        }
        if ($self->dow_0 >= $dow_start && $self->dow_0 <= $dow_end) {
          if ($possible_time eq '-') {
            delete $davening_times{$k};
          } else {
              if ($possible_time =~ /,/) {
                  $davening_times{$k} = $possible_time;
              }
              else {
                  $davening_times{$k} = new ShulCal::Time($possible_time);
              }
          }
        }
      }
    }
  }

  my $time_calc = new Suntimes(day => $self->e_day,
			       month => $self->e_month,
			       year => $self->e_year,
			       londeg => 34,
			       lonmin => 59.9172,
			       latdeg => 31,
			       latmin => 42.852,
			       timezone => 2 + ($self->is_dst ? 1 : 0),
			       time_constructor => sub { new ShulCal::Time($_[0]) } );
  my $sunrise = $time_calc->sunrise;
  my $sunset = $time_calc->sunset;
  my $shaa_zmanit = ($sunset - $sunrise) / 12;
  my $sof_zman_kriat_shma = $sunrise + (3 * $shaa_zmanit);
  $self->{_sof_zman_kriat_shma} = $sof_zman_kriat_shma;
  my $sof_zman_tefillah = $sunrise + (4 * $shaa_zmanit);
  my $havdalah_time = $time_calc->havdalah;
  my $MA_CONST = 90;
  my $burn_chametz = $time_calc->sunrise - $MA_CONST  + (5 * ($MA_CONST * 2 + $time_calc->sunset - $time_calc->sunrise) / 12);
  my $eat_chametz = $time_calc->sunrise - $MA_CONST  + (4 * ($MA_CONST * 2 + $time_calc->sunset - $time_calc->sunrise) / 12);

  my $candle_time = $sunset - 20;
  my $mincha_time = ($candle_time + 8) % 5;
  my $plag_mincha_time = $sunset - (1.25 * $shaa_zmanit);
  my $early_mincha_time;
  if ($plag_mincha_time lt '17:30') {
    $early_mincha_time = ($plag_mincha_time - 14) % 5;
  }
  else {
    $early_mincha_time = ($plag_mincha_time - 15) % 5;
  }

  # my $shabbat_post_mincha_shiur_duration = 10;
  #   No post-mincha shiur during Corona winter 5781
  my $shabbat_post_mincha_shiur_duration = 0;
  my $sh_mincha_time = ($sunset - 41 - $shabbat_post_mincha_shiur_duration) % 5;
  my $chatzot_halayla = $sunrise + (($sunset - $sunrise) / 2) + 12*60;
  #  $sh_mincha_time->set("15:40") if ($sh_mincha_time lt '15:45');
  # Earliest winter Shabbat minyan time set to 16:00, for Corona winter 5781
  $sh_mincha_time->set("16:00") if ($sh_mincha_time lt '16:00');
#  $sh_mincha_time = '17:00'
#    if ($self->{holiday}->{subparsha} && $self->{holiday}->{subparsha} =~ /(hagadol|shuva)/); 
  $sh_mincha_time->set("18:00") if ($sh_mincha_time gt '18:00');

  for my $k (keys %davening_times) {
      if ($davening_times{$k} =~ /\$\w+/) {
          my $time_string = $davening_times{$k};
          $time_string =~ s/\$/\$time_calc->/g;
          $davening_times{$k} = eval($time_string);
      }
      if ($davening_times{$k} =~ /\&/) {
          my $time_string = $davening_times{$k};
          $time_string =~ s/\&(.*?\))/eval($1)/e;
          $davening_times{$k} = $time_string;
      }
  }

  # TODO: move these to holiday
  if ($davening_times{'chatzot halayla'}) {
    $davening_times{'chatzot halayla'} = $chatzot_halayla;
  }
  if ($davening_times{'end eating chometz'}) {
      $davening_times{'end eating chometz'} = $eat_chametz;
  }
  if ($davening_times{'burn chometz'}) {
      $davening_times{'burn chometz'} = $burn_chametz;
  }

  if ($davening_times{'netz'}) {
    $davening_times{'netz'} = $sunrise;
  }

#  if ($davening_times{'brachot'}) {
#    $davening_times{'brachot'} = $time_calc->misheyakir;
#  }

#  if ($davening_times{'end eating chometz'}) {
#    $davening_times{'end eating chometz'} = $sunrise + 4 * $shaa_zmanit;
#  }
#  if ($davening_times{'burn chometz'}) {
#    $davening_times{'burn chometz'} = $sunrise + 5 * $shaa_zmanit;
#  }

#  if ($davening_times{'bitul chometz'}) {
#    $davening_times{'bitul chometz'} = $sunrise + 5 * $shaa_zmanit;
#  }

  if ($include_holiday_times && $holiday->notice && $holiday->notice eq 'bedikat chometz') {
#    $davening_times{'tzeit hacochavim'} = ShulCal::Time->new($time_calc->tzeit());
    $davening_times{'arvit'} = ($time_calc->tzeit + 5) % 105;
  }

  if ((!$self->is_shabbat && !$holiday->yomtov) &&
      $self->dow_0 < 6 &&
      $self->month == 7 &&
      $self->day > 2 && $self->day < 9) {
     # Selichot - for Asseret Yimei Tshuva
     $davening_times{"selichot"} ||= $weekday_start[$self->dow_0] - 35;
     if ($self->dow_0 == 5 && $include_late_friday) {
       $davening_times{"selichot"} .= ', 8:00';
     }
   }

  my $next_rosh_hashana = get_rosh_hashana($self->year + 1);
  my $this_pesach = get_pesach($self->year);
  my $days_to_rh = compute_date_diff($next_rosh_hashana, $self);
  if ($self->dow_0 < 6 &&
      ($self->dow_0 != 0 || $days_to_rh > 12 || $days_to_rh < 4) &&
      # Week of rosh hashana
      (($days_to_rh <= (7 - $self->dow_0) &&
	$days_to_rh > 2) ||
       # Week before rosh hashana and rosh Hashana on Monday or Tuesday
       ($next_rosh_hashana->dow_0 < 4 &&
	$days_to_rh <= (14 - $self->dow_0) &&
	$days_to_rh > (7 - $self->dow_0)))) {
    # Selichot - for before Rosh HaShana
    $davening_times{"selichot"} = $weekday_start[$self->dow_0] - 25;
    if ($self->dow_0 == 5 && $include_late_friday) {
        $davening_times{"selichot"} .= ', 8:00';
    }
}

  # Friday shacharit for the summer
  # Not being continued for summer 5768
#   my $combined_date = sprintf("%2.2d/%2.2d", $self->e_month, $self->e_day);
#   if ($combined_date ge "07/01" && $combined_date le "08/31" && $self->dow_0 == 5) {
#     if (ref($holiday->name) eq 'ARRAY' && grep(/rosh chodesh/, @{$holiday->name})) {
#       $davening_times{'shacharit'} = ShulCal::Time->new('7:15');
#     }
#     else {
#       $davening_times{'shacharit'} = ShulCal::Time->new('7:30');
#     }
#   }

  my $include_late_workweek_shacharit = 0;
  if (ref($holiday->name) eq 'ARRAY' && grep(/rosh chodesh/, @{$holiday->name})
      && !$self->is_shabbat) {

      $davening_times{shacharit} ||= ShulCal::Time->new('6:15');
      if ($self->dow_0 < 5 && $include_late_workweek_shacharit) {
          $davening_times{"shacharit"} .= ', 7:30';
      }
  }

  if ($self->is_shabbat || $holiday->yomtov) {
      my $early_minyan = ShulCal::Time->new('6:45');

      if ($holiday->is_chanukah) {
          $early_minyan -= 5;
      }
      if ($holiday->is_rosh_chodesh) {
          $early_minyan -= 5;
          if ($holiday->subparsha || ($holiday->parsha && $holiday->parsha eq 'matot-maasei')) {
              $early_minyan -= 5;
          }
      }
      $davening_times{'shacharit'} ||= "$early_minyan, 8:30";

    if (!$holiday->name || $holiday->name !~ /rosh hashana/) {
      my $last_minyan = $davening_times{shacharit};
      if ($davening_times{shacharit} =~ /,/) {
        $last_minyan = ShulCal::Time->new((split(/,\s*/, $davening_times{shacharit}))[-1]);
      }
      if ($sof_zman_kriat_shma - $last_minyan <= 40) {
        $davening_times{'sof zman kriat shma'} = $sof_zman_kriat_shma;
      }
    }


    if ($self->is_shabbat) {
        $davening_times{mincha} ||= $sh_mincha_time;
        if (! $self->is_dst) {
            $davening_times{mincha} = '13:30, ' . $sh_mincha_time;
        }

        if ($tom_holiday && $tom_holiday->is_chanukah) {
            # On motza"sh chanukah, daven arvit 10 minutes early.
            $davening_times{"arvit"} = $havdalah_time - 10;
        }

      if ($davening_times{"megillah reading"}) {
	$davening_times{"arvit"} = ($havdalah_time + 32) % 5;
        $davening_times{"megillah reading"} = ($davening_times{"arvit"} + 10) . ", " . ($davening_times{"arvit"} + 90);
      }

      if ($tom_holiday && $tom_holiday->name eq '9 av') {
          $davening_times{'mincha'} = ($time_calc->sunset - 100) % 15;
          $davening_times{'start fast evening'} = $time_calc->sunset;
          $davening_times{'arvit'} = ($havdalah_time + 25) % 5;
          $davening_times{'additional megillat eicha'} = ($havdalah_time + 89) % 105;
      }

      if (compute_date_diff($next_rosh_hashana, $self) <= 11  && compute_date_diff($next_rosh_hashana, $self) > 4) {
          $davening_times{"sicha and selichot"} = ($chatzot_halayla - 15) % 5;
      }

      if ($tom_holiday && $tom_holiday->yomtov) {
        if ($tom_holiday && $tom_holiday->name eq 'pesach') {
          $davening_times{mincha} = ($sunset - 25) % 5;
        }
        elsif ($tom_holiday->name =~ /' rosh hashana/)  {
            $davening_times{mincha} = ($sunset - 30) % 5;
            $davening_times{"arvit"} = ($time_calc->tzeit() + 5) % 5;
        }
        else {
#          $davening_times{mincha} = ($sunset - 95) % 15; # todo: special request of the Rav for 5767
#          $davening_times{"arvit"} = ($time_calc->tzeit() + 10) % 5; # Rav asked for Arvit at 19:10 on 1st day of RH (5770)
#            $davening_times{mincha} = ($sunset - 10) % 15; # Ironed out for Shavuot 5772
            $davening_times{mincha} = '13:30, ' . ($sunset - 17) % 10;
            $davening_times{"arvit"} = ($time_calc->tzeit() + 10) % 5;
        }
        $davening_times{"candle lighting"} = e2h("not before") . " " . $havdalah_time;
      } elsif ($holiday->name eq 'yom kippur') {
        $davening_times{"end yom kippur"} = $havdalah_time;
      } elsif (!$holiday->yomtov || $holiday->name =~ /chol hamoed/) {
          if (! grep { /^motzash/ } keys %davening_times) {
              $davening_times{"motzash"} = $havdalah_time;
          }
      } elsif ($holiday->yomtov && ($tom_holiday && !$tom_holiday->yomtov)) {
        $davening_times{"motzei shabbat and chag"} = $havdalah_time;
      }


      if ($holiday->subparsha eq "zachor") {
	$davening_times{"second reading"} = e2h("after musaf") . ", " . ($sh_mincha_time - 15);
      }

      if (($self->month == 1 && $self->day == 7) || # Exception for Shabbat Hagadol drasha when Erev Pesach is on Shabbat
          ($holiday->subparsha =~ /(hagadol|shuva)/ && $self->day != 14)) { 

          $davening_times{"drasha"} = (($sunset - 75) % 5);
          $davening_times{'mincha'} = $davening_times{drasha} - 20;
      }

        my $mincha = $davening_times{mincha};
        if ($mincha =~ /,\s*(\S+)/) {
            $mincha = ShulCal::Time->new($1);
        }
        my $earliest_summer_time_motzash = '18:30';

        my($motzash_time_key) = grep { /^motzash/ } keys %davening_times;

        if ($motzash_time_key && $davening_times{$motzash_time_key} gt $earliest_summer_time_motzash) {
            $davening_times{'daf yomi'} ||= $mincha - ($HORIM_VYELADIM_DURATION + $DAF_YOMI_DURATION);
        }
        elsif ($tom_holiday && $tom_holiday->yomtov) {
            $davening_times{'daf yomi'} ||= $mincha - ($HORIM_VYELADIM_DURATION + $DAF_YOMI_DURATION);
        }
        elsif (ref($mincha) && ref($mincha) eq 'ShulCal::Time') {
            $davening_times{'daf yomi'} ||= $mincha - $DAF_YOMI_DURATION;
        }

        if ($davening_times{motzash} && $davening_times{motzash} lt $earliest_summer_time_motzash) {
            my $minimum_gap = 60;
            if ($davening_times{motzash} gt '18:00') {
                $minimum_gap = 58;
            }
            $davening_times{'horim vyeladim'} = ($davening_times{motzash} + $minimum_gap) % 15;
        }
        elsif (! $holiday->yomtov) {
            my $mincha = $davening_times{mincha};
            if (!ref($mincha)) {
                $mincha =~ /^(.*?),/;
                $mincha = ShulCal::Time->new($1);
            }
            $davening_times{'horim vyeladim'} = ($mincha - $HORIM_VYELADIM_DURATION);
        }
    }

    else {
      if (!$davening_times{'mincha'}) {
          if ($holiday->name =~ /rosh hashana/) {
              my $rh_sunset = $sunset;
              if ($self->day == 1) {
                  # Calculate based on second day's sunset
                  my $rh2_datetime = DateTime->from_object(object => $self);
                  $rh2_datetime->add_duration(DateTime::Duration->new(days => 1));
                  my $rh2_time_calc = new Suntimes(day => $rh2_datetime->day,
                                                   month => $rh2_datetime->month,
                                                   year => $rh2_datetime->year,
                                                   londeg => 34,
                                                   lonmin => 59.9172,
                                                   latdeg => 31,
                                                   latmin => 42.852,
                                                   timezone => 2 + ($self->is_dst ? 1 : 0),
                                                   time_constructor => sub { new ShulCal::Time($_[0]) } );
                  $rh_sunset = $rh2_time_calc->sunset;
              }

              $davening_times{"mincha"} =  ($rh_sunset - 30) % 5;
          }
          else {
              $davening_times{"mincha"} =  ($sunset - 15) % 5;
          }
      }

      if (!$self->is_erev_shabbat) {
        # Figure out reasonable mincha time
        if ($tom_holiday && $tom_holiday->yomtov) {
          #        $davening_times{"kl arvit"} = $havdalah_time;
          $davening_times{"candle lighting"} = e2h("not before") . " " . ($time_calc->tzeit + 2);
          $davening_times{"arvit"} = ($time_calc->sunset + 25) % 5;
#          $davening_times{"candle lighting"} = $time_calc->tzeit;
        }
        else {
          if ($holiday->name eq 'yom kippur') {
            $davening_times{'end fast'} = $havdalah_time;
          }
          else {
            $davening_times{'motzei chag'} = $havdalah_time;
          }
        }
      }

      if ($tom_holiday && $tom_holiday->name eq '9 av') {
        $davening_times{mincha} = ShulCal::Time->new("18:00");
        $davening_times{'start fast evening'} = $time_calc->sunset;
        $davening_times{'arvit'} = ($time_calc->sunset + 22) % 5;
    }
    }
  }
  if ($holiday->name eq 'shavuot' && $self->dow_0 < 6) {
      $davening_times{'horim vyeladim'} = ($davening_times{mincha} - $HORIM_VYELADIM_DURATION);
      $davening_times{'daf yomi'} = $davening_times{mincha} - ($HORIM_VYELADIM_DURATION + $DAF_YOMI_DURATION);
  }

  if ($holiday->name eq 'erev yom kippur') {
    $davening_times{'kol nidre'} = ($candle_time + 5) % 5;
  }
  if ($holiday->name =~ /' rosh hashana/)  {
    $davening_times{mincha} ||= $mincha_time;
    if ($self->is_erev_shabbat) {
      # Friday RH 
      $davening_times{'shofar2'} = $davening_times{'mincha'} - 25;
    }
    elsif (!$self->is_shabbat) {
      $davening_times{'shofar2'} = $davening_times{'mincha'} - 25;
    }
    $davening_times{'horim vyeladim'} = ($davening_times{mincha} - $HORIM_VYELADIM_DURATION);
  }
  if (($tom_holiday && $tom_holiday->yomtov) || $self->is_erev_shabbat) {
    if ($self->dow_0 == 6) {
      # Candle lighting not needed -- derived from arvit
#      $davening_times{"candle lighting"} = $time_calc->tzeit;
    }
    elsif (!($holiday->name && $holiday->yomtov) || $self->dow_0 == 5) { #todo: fix
      if ($holiday->yomtov) {
#        $davening_times{"candle lighting"} = e2h("before") . " " . $candle_time;
        $davening_times{"candle lighting"} = $candle_time;
      } else {
        $davening_times{"candle lighting"} = $candle_time;
	if ($tom_holiday && $tom_holiday->name) {
#	  $davening_times{arvit} = $time_calc->tzeit;
	}
      }      
    }
    if ($tom_holiday && $tom_holiday->is_chanukah) {
      # On erev shabbos chanukah, add early mincha
      $davening_times{mincha} = "13:30, " . ($sunset - 20) % 5;
    }
    if (!grep(/mincha/, keys %davening_times)) {
      $davening_times{'mincha'} =  $mincha_time;
    }
    if ($self->is_dst && $tom_holiday 
        && $tom_holiday->name !~ /pesach/  # 5772 - no early minyan for 7th day pesach
#        && ! $holiday->yomtov # 5772 - no early minyan for Shabbat on Friday chag
        # 5780 - added early minyan on Shavuot for Shabbat Naso, not sure what will be in the future
        && $tom_holiday->name ne 'shavuot' 
        && $tom_holiday->name !~ / rosh hashana/ 
        && $early_mincha_time ge '17:15'
        && $self->month != 7
        && compute_date_diff($self, $this_pesach) > 7
        && (compute_date_diff($self, $next_rosh_hashana) < -7 ||
            compute_date_diff($self, $next_rosh_hashana) > 0)
       ) {
      $davening_times{'plag hamincha'} ||= "$plag_mincha_time";
      $davening_times{'early shabbos mincha'} ||= "$early_mincha_time";
    }
    # Add late shacharit
    if (($self->dow_0 != 5 || $force_include_late_friday) &&
        !grep(/shacharit/, keys %davening_times) &&
        ! $davening_times{selichot} &&
        $tom_holiday->name !~ / rosh hashana/  &&
        $tom_holiday->name !~ /yom kippur/ &&
        $include_late_friday
       ) {
      $davening_times{'shacharit'} =  $weekday_start[$self->dow_0] . ", 8:00";
    }
  }

  if (defined($davening_times{'arvit'}) && !ref($davening_times{arvit}) && $davening_times{'arvit'} eq 'arvit') {
    $davening_times{'arvit'} = $time_calc->tzeit();
  }

  if ($holiday->fast && !$holiday->yomtov) {
      if (! $include_late_friday) {
          $davening_times{'start fast'} ||= $time_calc->alot;
          $davening_times{'end fast'} = $time_calc->tzeit;
      }
      else {

          if ($holiday->name ne '9 av') {
              $davening_times{'start fast'} ||= $time_calc->alot;
              #      $davening_times{'alot later'} = $time_calc->alot_later;
              #      $davening_times{'regular 72'} = $time_calc->sunrise - 72;
              #      $davening_times{'adjusted 72'} = $time_calc->sunrise - (72/60 * $shaa_zmanit);
              #      $davening_times{'regular 90'} = $time_calc->sunrise - 90;
              #      $davening_times{'adjusted 90'} = $time_calc->sunrise - (90/60 * $shaa_zmanit);

              if ($holiday->name !~ /gedalia/) { # not printed when we have selichot
                  $davening_times{shacharit} = ShulCal::Time->new('6:10');
                  if ($self->dow_0 == 5 && $include_late_friday) {
                      $davening_times{shacharit} = '6:20, 8:00';
                  }
              }
              $davening_times{mincha} ||= ($sunset - 25) % 5;
              if ($self->dow_0 == 5) {
                  $davening_times{mincha} = ($candle_time - 5) % 5;
              }
          }

          if ($holiday->name eq 'taanit esther' && $self->dow_0 != 4) {
              # end fast not wanted for taanit esther - 5772
              #        $davening_times{'end fast'} = $time_calc->tzeit;
              #        $davening_times{arvit} ||= $time_calc->tzeit;
          }
          else {
              if ($self->dow_0 != 5) {
                  $davening_times{'end fast'} = $time_calc->tzeit;
                  $davening_times{arvit} ||= $time_calc->tzeit - 2;
              }
          }
      }
  }

  if (!$self->is_shabbat) {
      my $shacharit_key = 'shacharit';
      if (exists $davening_times{'shacharit and siyum'}) {
          $shacharit_key = 'shacharit and siyum';
      }
      # 5774 Tishrei: decided not to move shacharit time for neitz
      # 5774 Tevet : decided to re-instate delay
      # 5775 Tishrei: decided not to move shacharit time for neitz -- setting rule to exclude tishrei/marcheshvan
      # 5775 Shvat: decided not to move Rosh Chodesh start time, or Mondays which wouldn't match the corresponding Thursday
      
      if ($self->month != 7 && $self->month != 8) { 
          my $shacharit_time = $davening_times{$shacharit_key} || $weekday_start[$self->dow_0];

          my $compare_sunrise_day_diff = 3;
          if ($self->dow_0 >= 3) {
              $compare_sunrise_day_diff = -3;
          }
          my $time_calc = new Suntimes(day => $self->e_day + $compare_sunrise_day_diff,
                                       month => $self->e_month,
                                       year => $self->e_year,
                                       londeg => 34,
                                       lonmin => 59.9172,
                                       latdeg => 31,
                                       latmin => 42.852,
                                       timezone => 2 + ($self->is_dst ? 1 : 0),
                                       time_constructor => sub { new ShulCal::Time($_[0]) } );
          my $compare_sunrise = $time_calc->sunrise;
          if ($compare_sunrise - $sunrise < 0) {
              $compare_sunrise = $sunrise;
          }

          if ($shacharit_time !~ /,/ && ! $holiday->fast && ! $holiday->contains('rosh chodesh') && ! $holiday->contains('chanukah')) {
              if ($compare_sunrise - $shacharit_time > 15) {
                  $davening_times{netz} = $sunrise;
                  $davening_times{$shacharit_key} = ($compare_sunrise - 12) % 5;
              }
          }
      }
  }

  if ($self->month == 7 && $self->day == 11) {
      $davening_times{"shacharit"} ||= $weekday_start[$self->dow_0] - 5;
  }

  if ($self->is_erev_shabbat && !$holiday->yomtov && (! $holiday->name || $holiday->name !~ /chol hamoed/) && !$holiday->times) {
      if ($include_late_friday && $davening_times{shacharit} && (ref($davening_times{shacharit}) || $davening_times{shacharit} !~ /8:00/)) {
          $davening_times{shacharit} .= ', 8:00';
      }
  }

  my $include_youth_minyan = 0;
  my $include_weekday_shacharit = 0;
  if (!$self->is_shabbat && (! $holiday->name || $holiday->name ne '9 av') && $self->is_chofesh_hagadol && $include_chofesh_hagadol) {
      $include_youth_minyan = 1;
      if ($self->month == 3) {
          $include_weekday_shacharit = 1;
      }
  }

  if (!$self->is_shabbat && ($holiday->is_youth_minyan || $self->other_youth_vacation)) {
      $include_weekday_shacharit = 1;
      $include_youth_minyan = 1;
  }

  if ($include_late_workweek_shacharit && $self->dow_0 < 5) {
      $include_weekday_shacharit = 1;
  }

  if ($global_include_youth_minyan && $include_weekday_shacharit && ! $davening_times{"shacharit"} && ! $davening_times{selichot}) {
      $davening_times{"shacharit"} = $weekday_start[$self->dow_0];
      if ($self->dow_0 == 5 && $include_late_friday) {
          $davening_times{"shacharit"} .= ', 8:00';
      }
      elsif ($self->dow_0 < 5 && $include_late_workweek_shacharit) {
          $davening_times{"shacharit"} .= ', 7:30';
      }
  }


  if ($global_include_youth_minyan && $include_youth_minyan && $davening_times{"shacharit"}) {
      my $youth_minyan_time = '8:45';
      if ($sof_zman_kriat_shma lt ShulCal::Time->new('8:55')) {
          $youth_minyan_time = '8:30';
      }
      if ($self->dow_0 != 5 || $youth_minyan_time ne '8:30') {
          $davening_times{"shacharit"} .= ", $youth_minyan_time";
      }
  }

  if ($include_bezman_mincha &&
      (($self->day == 1 && $self->dow_0 < 5) ||
       (! $holiday->yomtov && ! $holiday->minor_holiday && ! $self->{tomorrow}->holiday->yomtov && $self->dow_0 == 0) ||
       ($self->{yesterday} &&
        ($self->{yesterday}->holiday->yomtov || $self->{yesterday}->holiday->minor_holiday) &&
        ($self->dow_0 == 1 || $self->dow_0 == 2)))) {

      if (! $self->is_dst) {
          $davening_times{"mincha"} ||= ($sunset - 14) % 5;
          $davening_times{"arvit"} ||= (($sunset + 26) % 5) . ", 20:30";
      }
  }

  if (!$self->is_shabbat) {
      if ($holiday->is_chanukah) {
          if ($holiday->is_rosh_chodesh) {
              $davening_times{shacharit} -= 5;
          }
          if ($include_youth_minyan && $holiday->duration_instance > 1) {

              if ($self->dow_0 == 5) {
                  $davening_times{shacharit} .= ', 8:45*';
                  $self->{month_note} = e2h('at ramat shalom');
              }
              else {
                  $davening_times{shacharit} .= ', 8:45';
              }
          }
      }
  }

  if ($holiday->low_priority_times) {
      for my $k (keys %{$holiday->low_priority_times}) {
          $davening_times{$k} ||= $holiday->low_priority_times->{$k};
      }
  }

  return %davening_times;
}

#--------------------------------------------------

sub is_dst {
  my($self) = @_;

  return (DateTime->from_object(object => $self) >= dst_start_date($self->e_year) &&
          DateTime->from_object(object => $self) < dst_end_date($self->e_year));
}

#----------------------------------------------------------------------

sub dst_start_date {
  my($e_year) = @_;
  my $dst_start_day = new DateTime(year => $e_year,
				   month => 3,
				   day => 29);
  # DateTime dow is different than DateTime::Calendar::Hebrew!!
  $dst_start_day->subtract_duration(DateTime::Duration->new(days => ($dst_start_day->dow + 2) % 7));
  return $dst_start_day;
}

#----------------------------------------------------------------------

sub dst_end_date {
  my($e_year) = @_;

  my $dst_end_day = new DateTime(year => $e_year,
                                 month => 10,
                                 day => 31);
  # DateTime dow is different than DateTime::Calendar::Hebrew!!
  $dst_end_day->subtract_duration(DateTime::Duration->new(days => ($dst_end_day->dow) % 7));
  return $dst_end_day;
}

#----------------------------------------------------------------------

sub sort_by_davening {
  my(%times) = @_;
  my @time_keys = map { $_->[0] } sort { $a->[1] - 3*60 cmp $b->[1] - 3*60 } map { [$_, make_time($times{$_})] } keys %times;
  return @time_keys;
}

#----------------------------------------------------------------------

sub make_time {
  if ($_[0] =~ /(\d+:\d+)/) {
    return new ShulCal::Time($1);
  }
  if ($_[0] eq e2h('after musaf')) {
    return new ShulCal::Time('13:00');
  }
  return new ShulCal::Time('0:00');
}

sub e_month {
  return DateTime->from_object(object => $_[0])->month;
}

sub e_day {
  return DateTime->from_object(object => $_[0])->day;
}

sub e_year {
  return DateTime->from_object(object => $_[0])->year;
}

#----------------------------------------------------------------------

sub week {
  my($self) = @_;
  my $DAY_TIME = 24*60*60;
  my $WEEK_TIME = 7 * $DAY_TIME;
  return int((DateTime->from_object(object => $self)->epoch - $DAY_TIME - DateTime->from_object(object => get_rosh_hashana($self->year))->epoch) / $WEEK_TIME);
}

#----------------------------------------------------------------------

sub get_omer {
  my ($self) = @_;
  my $difference = compute_date_diff($self, get_pesach($self->year));
  if ($difference >= 1 && $difference <= 49) {
    my $week_portion = "";
    #      if ($difference > 7) {
    #        $week_portion = "(" . int($difference/7) . "+" . $difference % 7 . ")";
    #      } 
    my $gematria = gematria($difference, 1);
    return decode_utf8("סופרים ") . $gematria . decode_utf8(" לעומר בערב ") .$week_portion;
  }
  else {
    return undef;
  }
}

#----------------------------------------------------------------------

sub get_rosh_hashana {
  my($year) = @_;
  return new DateTime::Calendar::Hebrew(year => $year,
					month => 7,
					day => 1);
}

#----------------------------------------------------------------------

sub get_pesach {
  my($year) = @_;
  return new DateTime::Calendar::Hebrew(year => $year,
					month => 1,
					day => 15);
}

#----------------------------------------------------------------------

sub compute_date_diff {
  my($date1, $date2) = @_;
  return int((DateTime->from_object(object => $date1)->epoch - DateTime->from_object(object => $date2)->epoch) / (60*60*24)) + 1;
}

#----------------------------------------------------------------------

sub holiday {
  my($self, $param) = @_;
  if ($param) {
    if ($self->{_holiday} && $self->{_holiday}->{$param}) {
      return $self->{_holiday}->{$param};
    } else {
      return '';
    }
  }
  return $self->{_holiday};
}

#----------------------------------------------------------------------

sub is_shabbat {
  my($self) = @_;
  return $self->dow_0 == 6;
}

#----------------------------------------------------------------------

sub is_erev_shabbat {
  my($self) = @_;
  return $self->dow_0 == 5;
}

#----------------------------------------------------------------------

sub is_chofesh_hagadol {
    my($self) = @_;
    my $vacation_start_date = new DateTime(year => $self->e_year,
                                           month => 6,
                                           day => 21);
    if ($vacation_start_date->dow == 5) {
        $vacation_start_date = new DateTime(year => $self->e_year,
                                            month => 6,
                                            day => 23);
    }
    my $vacation_end_date = new DateTime(year => $self->e_year,
                                           month => 9,
                                           day => 1);
    return (DateTime->from_object(object => $self) >= $vacation_start_date &&
            DateTime->from_object(object => $self) < $vacation_end_date);
}

#----------------------------------------------------------------------

sub other_youth_vacation {
    my($self) = @_;

    my $yom_kippur = DateTime->from_object(object => new DateTime::Calendar::Hebrew(year => $self->year,
                                                                                    month => 7,
                                                                                    day => 10));
    my $sukkot = DateTime->from_object(object => new DateTime::Calendar::Hebrew(year => $self->year,
                                                                                month => 7,
                                                                                day => 15));
    if (DateTime->from_object(object => $self) > $yom_kippur &&
        DateTime->from_object(object => $self) < $sukkot) {
        return 1;
    }
    my $isru_chag = DateTime->from_object(object => new DateTime::Calendar::Hebrew(year => $self->year,
                                                                                   month => 7,
                                                                                   day => 23));
    if (DateTime->from_object(object => $self) == $isru_chag) {
        return 1;
    }
    return;
}

#----------------------------------------------------------------------

sub shacharit_time {
  my($self) = @_;
  my %davening_times = $self->get_times;
  if ($davening_times{shacharit}) {
    return $davening_times{shacharit};
  }
  else {
    return $weekday_start[$self->dow_0];
  }
}

#----------------------------------------------------------------------

sub get_month_note {
    my($self) = @_;
    return $self->{month_note};
}

#----------------------------------------------------------------------

1;
