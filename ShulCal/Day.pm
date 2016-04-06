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

my $DAF_YOMI_SHIUR_LENGTH = 40;

our @weekday_start = map { new ShulCal::Time($_) } (qw(6:30 6:20 6:30 6:30 6:20 6:30));

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
  my($self, $q) = @_;
  my @inside_rows = ();
  my $holiday = $self->holiday;
  my %davening_times = $self->get_times();
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
    push(@inside_rows, $q->div({-class => 'holiday_notice'}, $q->span({-class => 'holiday_notice_inner'}, "&nbsp;" . e2h($holiday->notice) . "&nbsp;")));
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
    push(@inside_rows, $q->div({-class => 'holiday_notice'}, $q->span({-class => 'holiday_notice_inner'}, "&nbsp;" . e2h($holiday->bottom_notice) . "&nbsp;")));
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
  my($self) = @_;
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
  my $sh_mincha_time = ($sunset - 51) % 5; # Changed from 15 for winter 5771
  my $chatzot_halayla = $sunrise + (($sunset - $sunrise) / 2) + 12*60;
  $sh_mincha_time->set("15:40") if ($sh_mincha_time lt '15:45');
#  $sh_mincha_time = '17:00'
#    if ($self->{holiday}->{subparsha} && $self->{holiday}->{subparsha} =~ /(hagadol|shuva)/); 
  $sh_mincha_time->set("18:00") if ($sh_mincha_time gt '18:00');


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

  if ($holiday->notice eq 'bedikat chometz') {
#    $davening_times{'tzeit hacochavim'} = ShulCal::Time->new($time_calc->tzeit());
    $davening_times{'arvit'} = ($time_calc->tzeit + 5) % 15;
  }

  if ((!$self->is_shabbat && !$holiday->yomtov) &&
      $self->dow_0 < 6 &&
      $self->month == 7 &&
      $self->day > 2 && $self->day < 9) {
     # Selichot - for Asseret Yimei Tshuva
     $davening_times{"selichot"} ||= $weekday_start[$self->dow_0] - 35;
     if ($self->dow_0 == 5) {
       $davening_times{"selichot"} .= ', 8:10';
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
  if (ref($holiday->name) eq 'ARRAY' && grep(/rosh chodesh/, @{$holiday->name})
      && !$self->is_shabbat) {
    $davening_times{shacharit} = ShulCal::Time->new('6:15');
  }

  if ($self->is_shabbat || $holiday->yomtov) {
        
    if (ref($holiday->name) eq 'ARRAY' && grep(/rosh chodesh/, @{$holiday->name})) {
      if (ref($holiday->name) eq 'ARRAY' && grep(/chanukah/, @{$holiday->name})) {

        $davening_times{'shacharit'} ||= "6:35, 8:30";
      }
      else {
        $davening_times{'shacharit'} ||= "6:40, 8:30";
      }
    }
    elsif ((ref($holiday->name) eq 'ARRAY' && grep(/chanukah/, @{$holiday->name})) ||
           (!ref($holiday->name) && grep(/chanukah/, $holiday->name))) {
      $davening_times{'shacharit'} ||= "6:40, 8:30";
      # Changed from 6:35 -> 6:40 for 5773 request
    }
    else {
      $davening_times{'shacharit'} ||= "6:45, 8:30";
    }

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
        $davening_times{mincha} = $sh_mincha_time;
        if (! $self->is_dst) {
            $davening_times{mincha} ||= '13:15, ' . $sh_mincha_time;
        }

      if ($tom_holiday && ($tom_holiday->name =~ /chanukah/ || (ref($tom_holiday->name) eq 'ARRAY' && grep(/chanukah/, @{$tom_holiday->name})))) {
          # On motza"sh chanukah, daven arvit 10 minutes early.
          $davening_times{"arvit"} = $havdalah_time - 10;
      }

      if ($davening_times{"megillah reading"}) {
	$davening_times{"arvit"} = ($havdalah_time + 32) % 5;
        $davening_times{"megillah reading"} = ($davening_times{"arvit"} + 10) . ", " . ($davening_times{"arvit"} + 90);
      }

      if ($tom_holiday && $tom_holiday->name eq '9 av') {
	$davening_times{'mincha'} = $davening_times{mincha} - 30;
	$davening_times{'start fast evening'} = $time_calc->sunset;
	$davening_times{'arvit'} = ($havdalah_time + 20) % 5;
      }

      if (compute_date_diff($next_rosh_hashana, $self) <= 11  && compute_date_diff($next_rosh_hashana, $self) > 4) {
#      	$davening_times{"night selichot"} = ($chatzot_halayla) % 10;
      	$davening_times{"sicha and selichot"} = ($chatzot_halayla - 15) % 5;
      }

      if ($tom_holiday && $tom_holiday->yomtov) {
        if ($tom_holiday && $tom_holiday->name eq 'pesach') {
          $davening_times{mincha} = ($sunset - 25) % 5;
        }
        else {
#          $davening_times{mincha} = ($sunset - 95) % 15; # todo: special request of the Rav for 5767
#          $davening_times{"arvit"} = ($time_calc->tzeit() + 10) % 5; # Rav asked for Arvit at 19:10 on 1st day of RH (5770)
            $davening_times{mincha} = ($sunset - 10) % 15; # Ironed out for Shavuot 5772
            $davening_times{"arvit"} = ($time_calc->tzeit()) % 5; # Ironed out for Shavuot 5772
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

#      unless (($self->month == 1 && $self->day == 14) || $holiday->name =~ /kippur/) {
####      $davening_times{'daf yomi'} ||= $davening_times{mincha} - $DAF_YOMI_SHIUR_LENGTH;
#        if ($davening_times{mincha} =~ /^[\d:]+$/) {
#          $davening_times{'daf yomi'} ||= $davening_times{mincha} - 30;
#          if ($davening_times{'daf yomi'} lt '15:00') {
#            $davening_times{'daf yomi'} = ShulCal::Time->new('15:00');
#          }
#        }
#      }
    } 
    else {
      if (!$davening_times{'mincha'}) {
	if ($holiday->name =~ /rosh hashana/) {
	  $davening_times{"mincha"} =  ($sunset - 25) % 5;
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
  else {
      if (((ref($holiday->name) eq 'ARRAY' && grep(/chanukah/, @{$holiday->name})) ||
          (!ref($holiday->name) && grep(/chanukah/, $holiday->name))) &&
          $holiday->duration_instance > 1) {

          $davening_times{shacharit} .= ', 8:45';
      }

  }

  if ($holiday->name eq 'erev yom kippur') {
    $davening_times{'kol nidre'} = ($candle_time + 5) % 5;
  }
  if ($holiday->name =~ /' rosh hashana/)  {
    $davening_times{mincha} ||= $mincha_time;
    if ($self->is_erev_shabbat) {
      # Friday RH 
      $davening_times{'shofar2'} = $davening_times{'mincha'} - 30;
    }
    elsif (!$self->is_shabbat) {
      $davening_times{'shofar2'} = $davening_times{'mincha'} - 30;
    }
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
    if ((ref($holiday->name) && grep(/chanukah/, @{$holiday->name})) || $holiday->name =~ /chanukah/) {
      # On erev shabbos chanukah, add early mincha
        # As per Rav Menachem's request (5770), make mincha 10 minutes earlier
      $davening_times{mincha} = "12:30, " . ($sunset - 20) % 5;
    }
    if (!grep(/mincha/, keys %davening_times)) {
      $davening_times{'mincha'} =  $mincha_time;
    }
    if ($self->is_dst && $tom_holiday 
        && $tom_holiday->name !~ /pesach/  # 5772 - no early minyan for 7th day pesach
        && ! $holiday->yomtov # 5772 - no early minyan for Shabbat on Friday chag
        && $tom_holiday->name ne 'shavuot' 
        && $tom_holiday->name !~ / rosh hashana/ 
        && $early_mincha_time ge '17:00'
        && $self->month != 7
        && compute_date_diff($self, $this_pesach) > 0
        && (compute_date_diff($self, $next_rosh_hashana) < -5 ||
            compute_date_diff($self, $next_rosh_hashana) > 0)
       ) {
      $davening_times{'plag hamincha'} ||= "$plag_mincha_time";
      $davening_times{'early shabbos mincha'} ||= "$early_mincha_time";
    }
    # Add late shacharit
    if ($self->dow_0 != 5 && 
        !grep(/shacharit/, keys %davening_times) &&
        $tom_holiday->name !~ / rosh hashana/  &&
        $tom_holiday->name !~ /yom kippur/ 
       ) {
      $davening_times{'shacharit'} =  $weekday_start[$self->dow_0] . ", 8:10";
    }
  }

  if (defined($davening_times{'arvit'}) && !ref($davening_times{arvit}) && $davening_times{'arvit'} eq 'arvit') {
    $davening_times{'arvit'} = $time_calc->tzeit();
  }

  if ($holiday->fast && !$holiday->yomtov) {
    if ($holiday->name ne '9 av') {
      $davening_times{'start fast'} ||= $time_calc->alot;
#      $davening_times{'alot later'} = $time_calc->alot_later;
#      $davening_times{'regular 72'} = $time_calc->sunrise - 72;
#      $davening_times{'adjusted 72'} = $time_calc->sunrise - (72/60 * $shaa_zmanit);
#      $davening_times{'regular 90'} = $time_calc->sunrise - 90;
#      $davening_times{'adjusted 90'} = $time_calc->sunrise - (90/60 * $shaa_zmanit);

      if ($holiday->name !~ /gedalia/) { # not printed when we have selichot
        $davening_times{shacharit} = ShulCal::Time->new('6:10');
        if ($self->dow_0 == 5) {
            $davening_times{shacharit} = '6:10, 8:10';
        }
      }
      # Changed for Tzom Gedalia 5772 - print mincha on fast regardless
      # Changed for 10 Tevet 5772 - do not print mincha
      if ((($sunset - 30) % 5) ge '17:00') {
          $davening_times{mincha} = ($sunset - 25) % 5; 
      }
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
            $davening_times{arvit} = ($time_calc->tzeit - 2) % 5 if ($time_calc->tzeit gt '17:30');
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
          my $compare_sunrise = $sunrise;
          if ($self->dow_0 < 3) {
              my $time_calc = new Suntimes(day => $self->e_day + 3,
                                           month => $self->e_month,
                                           year => $self->e_year,
                                           londeg => 34,
                                           lonmin => 59.9172,
                                           latdeg => 31,
                                           latmin => 42.852,
                                           timezone => 2 + ($self->is_dst ? 1 : 0),
                                           time_constructor => sub { new ShulCal::Time($_[0]) } );
              $compare_sunrise = $time_calc->sunrise;
          }
          if ($shacharit_time !~ /,/) {
              if ($compare_sunrise - $shacharit_time > 14) {
                  $davening_times{netz} = $sunrise;
              }
              if ($compare_sunrise - $shacharit_time > 16 &&
                  ! $holiday->fast && ! $holiday->contains('rosh chodesh') && ! $holiday->contains('chanukah')) {

                  $davening_times{$shacharit_key} = ($sunrise - 12) % 5;
              }
          }
      }
  }

  if ($self->is_erev_shabbat && !$holiday->yomtov) {
#    unless ($davening_times{shacharit}) {
#      $davening_times{shacharit} = '6:30';
#    }
    if ($davening_times{shacharit} && (!$holiday->name || ref($holiday->name))) {
      $davening_times{shacharit} .= ', 8:10';
    }
  }

#  unless ($self->is_shabbat || $holiday->yomtov || $holiday->name eq '9 av') {
#    if ($davening_times{shacharit} && $davening_times{shacharit} !~ /,/) {
#      $davening_times{'daf yomi'} ||= $davening_times{shacharit} - $DAF_YOMI_SHIUR_LENGTH;
#    }
#  }

  if ($self->month == 7 && $self->day == 11) {
     $davening_times{"shacharit"} ||= $weekday_start[$self->dow_0] - 5;
  }

  # if ($self->day == 14) {
  #   $davening_times{alot} = $time_calc->alot;
  #   $davening_times{tzeit} = $time_calc->tzeit;
  #   my $shaa_zmanit_ma = (($time_calc->tzeit - $time_calc->alot) / 12);
  #   $davening_times{hour} = "aaa $shaa_zmanit_ma";
  #   $davening_times{test_eat} = $time_calc->alot + ( 3 * $shaa_zmanit_ma);
  #   $davening_times{test_eat1} = $time_calc->alot + ( 4 * $shaa_zmanit_ma);
  #   $davening_times{test_eat2} = $time_calc->alot + ( 5 * $shaa_zmanit_ma);
  #   $davening_times{test_eat3} = $time_calc->alot + ( 6 * $shaa_zmanit_ma);
  # }

#  my $combined_date = sprintf("%2.2d/%2.2d", $self->e_month, $self->e_day);
#  if ($combined_date gt "03/31" && $combined_date lt "04/28") {
#    for my $k (%davening_times) {
#      my $orig_time = $davening_times{$k};
#      $davening_times{$k} = time_oper($orig_time, -60) . " (קיץ: " . $orig_time . ")" if ($orig_time && $orig_time =~ /^\d+:\d+$/);
#    }
#  }
  # Friday Shacharit for the summer

        # $davening_times{'sunrise'} = $sunrise;
        # $davening_times{'shaa zmanit'} = 'in minutes: ' . sprintf('%.4f', $shaa_zmanit);
        # $davening_times{'3 hours'} = 'in minutes: ' . sprintf('%.4f', $shaa_zmanit * 3);
        # $davening_times{'sof zman kriat shma'} = $sof_zman_kriat_shma;

  for my $k (keys %davening_times) {
    if ($davening_times{$k} =~ /\$\w+/) {
      my $time_string = $davening_times{$k};
      $time_string =~ s/\$/\$time_calc->/g;
      $davening_times{$k} = eval($time_string);
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

1;
