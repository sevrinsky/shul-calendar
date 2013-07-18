package Suntimes;
use POSIX;
# /* ksun.js - Kaluach suntimes Javascript routines
#  *   Version 1.00 (initial release)
#  *   Version 1.01 (fixed bug with time adjust - AM/PM and 24 hour clock)
#  *   Version 1.02 (fixed bug with time adjust [again] - AM/PM and 24 hour clock)
#  *   Version 2.00 (new suntimes routine, original routine was buggy)
#  *   Version 2.01 (handle invalid sunrise/set, different knissat shabbat times)
#  * Copyright (C) 5760-5763 (2000 - 2003 CE), by Abu Mami and Yisrael Hersch.
#  *   All Rights Reserved.
#  *   All copyright notices in this script must be left intact.
#  * Based on:
#  *   - PHP code that was translated by mattf@mail.com from the original perl
#  *     module Astro-SunTime-0.01
#  *	 - original version of ksun.js was based on the program SUN.C by Michael
#  *     Schwartz, which was based on an algorithm contained in:
#  *         Almanac for Computers, 1990
#  *         published by Nautical Almanac Office
#  *         United States Naval Observatory
#  *         Washington, DC 20392
#  * Permission will be granted to use this script on your web page
#  *   if you wish. All that's required is that you please ask.
#  *   (Of course if you want to send a few dollars, that's OK too :-)
#  * website: http://www.kaluach.net
#  * email: abumami@kaluach.org
#  */

sub new {
  my($class, %init_params) = @_;
  my $self = {};
  bless $self, $class;
  $self->init(%init_params);
  return $self;
}

sub init {
  my($self, %hash) = @_;
  for my $k (keys %hash) {
    $self->{$k} = $hash{$k};
  }
  my $junk;
  my @base_times = $self->suntime(90,50);
  $self->{sunrise} = timeadj($base_times[1]);
  $self->{sunset} = timeadj($base_times[2]);
}

sub sunrise {
  my($self) = @_;
  if ($self->{time_constructor}) {
    return $self->{time_constructor}->($self->{sunrise});
  }
  return $self->{sunrise};
}

sub sunset {
  my($self) = @_;
  if ($self->{time_constructor}) {
    return $self->{time_constructor}->($self->{sunset});
  }
  return $self->{sunset};
}

sub havdalah {
  my($self) = @_;
  unless (defined($self->{havdalah})) {
    my @havdalah_times = $self->suntime(98, 30);
    $self->{havdalah} = timeadj($havdalah_times[2]);
  }
  if ($self->{time_constructor}) {
    return $self->{time_constructor}->($self->{havdalah});
  }
  return $self->{havdalah};
}

sub tzeit {
  my($self) = @_;
  unless (defined($self->{tzeit})) {
    my @tzeit_times = $self->suntime(96, 0);
    $self->{tzeit} = timeadj($tzeit_times[2]);
  }
  if ($self->{time_constructor}) {
    return $self->{time_constructor}->($self->{tzeit});
  }
  return $self->{tzeit};
}

sub alot_later {
  my($self) = @_;
  unless (defined($self->{alot_later})) {
    my @alot_times = $self->suntime(106, 6);
    $self->{alot_later} = timeadj($alot_times[1]);
  }
  if ($self->{time_constructor}) {
    return $self->{time_constructor}->($self->{alot_later});
  }
  return $self->{alot_later};
}

sub alot {
  my($self) = @_;
  unless (defined($self->{alot})) {
    my @alot_times = $self->suntime(110, 0);
    $self->{alot} = timeadj($alot_times[1]);
  }
  if ($self->{time_constructor}) {
    return $self->{time_constructor}->($self->{alot});
  }
  return $self->{alot};
}

sub misheyakir {
  my($self) = @_;
  unless (defined($self->{misheyakir})) {
    my @misheyakir_times = $self->suntime(101, 0);
    $self->{misheyakir} = timeadj($misheyakir_times[1]);
  }
  if ($self->{time_constructor}) {
    return $self->{time_constructor}->($self->{misheyakir});
  }
  return $self->{misheyakir};
}

sub doy {
  my($d, $m, $y) = @_;
  my @monCount = (0, 1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366);
  return $monCount[$m] + $d + leap($y, $m);
}


sub leap {
  my($y, $m) = @_;
  return 1 if ((($y % 400 == 0) || ($y % 100 != 0 && $y % 4 == 0)) && $m > 2);
  return 0;
}

sub suntime {
  my($self, $sundeg, $sunmin) = @_;
  my $invalid = 0;	#// start out as OK

  my $longitude = ($self->{londeg} + $self->{lonmin}/60.0); # * ((ew == 0) ? -1 : 1);
  my $latitude  = ($self->{latdeg} + $self->{latmin}/60.0); # * ((ns == 0) ? 1 : -1);

  my $yday = doy($self->{day}, $self->{month}, $self->{year});

  my $A = 1.5708; 
  my $B = 3.14159; 
  my $C = 4.71239; 
  my $D = 6.28319;      
  my $E = 0.0174533 * $latitude; 
  my $F = 0.0174533 * $longitude; 
  my $G = 0.261799 * $self->{timezone}; 

  my $R = cos(0.01745 * ($sundeg + $sunmin/60.0));

  my $J;
  my ($ss, $sr);
#  // two times through the loop
#	//    i=0 is for sunrise
#	//    i=1 is for sunset
  for my $i (0..1) {
    $J = ($i ? $C : $A);

    my $K = $yday + (($J - $F) / $D); 
    my $L = ($K * .017202) - .0574039; #             // Solar Mean Anomoly 
    my $M = $L + .0334405 * sin($L); #           // Solar True Longitude 
    $M += 4.93289 + (3.49066E-04) * sin(2 * $L); 
    
    # // Quadrant Determination 
    if ($D == 0) {
      alert("Trying to normalize with zero offset...");
      return;
    } 

    while($M < 0) {
      $M += $D;
    }
    
    while($M >= $D) {
      $M -= $D;
    }

    if (($M / $A) - floor($M / $A) == 0) {
      $M += 4.84814E-06;
    }
    
    my $P = sin($M) / cos($M);                   # // Solar Right Ascension 
    $P = atan2(.91746 * $P, 1); 
    
    # // Quadrant Adjustment 
    if ($M > $C) {
      $P += $D;
    }
    else {
      if ($M > $A) {
	$P += $B;
      }
    } 

    my $Q = .39782 * sin($M);      # // Solar Declination 
    $Q = $Q / sqrt(-$Q * $Q + 1);     # // This is how the original author wrote it! 
    $Q = atan2($Q, 1); 

    my $S = $R - (sin($Q) * sin($E)); 
    $S = $S / (cos($Q) * cos($E)); 

    if(abs($S) > 1) {
      $invalid = 1;	# // uh oh! no sunrise/sunset
    }
    
    $S = $S / sqrt(-$S * $S + 1); 
    $S = $A - atan2($S, 1); 

    if(!$i) {
      $S = $D - $S;	# // sunrise
    }

    my $T = $S + $P - 0.0172028 * $K - 1.73364;  # // Local apparent time 
    my $U = $T - $F;                            # // Universal timer 
    my $V = $U + $G;                            # // Wall clock time 
		
    # // Quadrant Determination 
    if($D == 0) {
      alert("Trying to normalize with zero offset...");
      return;
    } 
    
    while($V < 0) {
      $V = $V + $D;
    }
    while($V >= $D) {
      $V = $V - $D;
    }
    $V = $V * 3.81972; 

    if(!$i) {
      $sr = $V;	# // sunrise
    }
    else {
      $ss = $V;	# // sunset
    }
  } 

  return ($invalid, $sr, $ss);
}


sub timeadj {
  my ($t, $ampm) = @_;
  my $time = $t;

  my $hour = floor($time);
  my $min  = floor(($time - $hour) * 60.0 + 0.5);
  
  if($min >= 60) {
    $hour += 1;
    $min  -= 60;
  }

  $hour += 24   if($hour < 0);
  my $ampm_str = '';
  if($ampm) {
    $ampm_str = ($hour > 11) ? ' PM' : ' AM';
    $hour %= 12;
    $hour = ($hour < 1) ? 12 : $hour;
  }

  my $str = $hour . ':' . (($min < 10) ? '0' : '') . $min . $ampm_str;
# //	my str = hour + ':' + min + ampm_str;
  return $str;
}

1;

=head1



my month = 0, day = 0, year = 0;
my lat = 0, lng = 0;	# // sun's location
my latd = -1, latm = 0;# // lat on earth
my lngd = -1, lngm = 0;# // long on earth
my ns = 'N', ew = 'E';	# // hemisphere
my dst = 0;			# // daylight saving time
my ampm = 1;			# // am/pm or 24 hour display





sub change_year(num) {
	my y = parseInt(document.data.year.value);
	y += num;
	document.data.year.value = y;
	year = y;
	date_vars_doit();
}

sub list_pos(w) {

	my str, place, desc
	my i;

	i = w.options.selectedIndex;
	with(document.data) { # // reset all prior selections
		israel_city.options[0].selected = 1;
		diaspora_city.options[0].selected = 1;
	}
	w.options[i].selected = 1; # // restore current selection
	with (w) {
		desc = options[0].text;
		str = options[options.selectedIndex].value;
		place = options[options.selectedIndex].text;
		if(i == 0)
			document.data.placename.value = '';
	}

	i = str.indexOf(",");
	ns = str.substring(0, i);
	str = str.substring(i+1, str.length);

	i = str.indexOf(",");
	latd = eval(str.substring(0, i));
	str = str.substring(i+1, str.length);

	i = str.indexOf(",");
	latm = eval(str.substring(0, i));
	str = str.substring(i+1, str.length);

	i = str.indexOf(",");
	ew = str.substring(0, i);
	str = str.substring(i+1, str.length);

	i = str.indexOf(",");
	lngd = eval(str.substring(0, i));
	str = str.substring(i+1, str.length);

	i = str.indexOf(",");
	lngm = eval(str.substring(0, i));

	my tz = eval(str.substring(i+1, str.length));

	if((latd != -1) && (lngd != -1)) {
		document.data.tz.options[12+tz].selected = 1;
		doit("(" + desc + ") " + place);
	}

}

sub man_pos() {

	latd = abs(eval(document.data.latd.value));
	latm = abs(eval(document.data.latm.value));
	ns = (document.data.lats[1].checked) ? 'S' : 'N';

	lngd = abs(eval(document.data.lngd.value));
	lngm = abs(eval(document.data.lngm.value));
	ew = (document.data.lngs[1].checked) ? 'E' : 'W';

	my tz = - (12 - document.data.tz.options.selectedIndex);
	document.data.tz.options[12+tz].selected = 1;
	doit("(manual entry)");
	return 1;
}

sub doit(title) {

	my d, m, y;
	my nsi, ewi;
	my i;
 
	if(title != "")
		document.data.placename.value = title;
 
	document.data.latd.value = latd;
	document.data.latm.value = latm;
	i = ns.indexOf("N");
	nsi = (i != -1) ? 0 : 1;
	document.data.lats[nsi].checked = 1;
 
	document.data.lngd.value = lngd;
	document.data.lngm.value = lngm;
	i = ew.indexOf("W");
	ewi = (i != -1) ? 0 : 1;
	document.data.lngs[ewi].checked = 1;
 
	d = day + 1;
	m = month + 1;
	y = year;
 
	my adj = - (12 - document.data.tz.options.selectedIndex);
	adj += dst;

	my time;
	my sunrise, sunset;
	my shaa_zmanit;

	time = suntime(d, m, y, 90, 50, lngd, lngm, ewi, latd, latm, nsi, adj);
	if(time[1] == 0) {
		sunrise = time[2];
		sunset  = time[3];
		document.data.hanetz.value = timeadj(sunrise, ampm);
		document.data.shkia.value = timeadj(sunset, ampm);
		shaa_zmanit = (sunset - sunrise) / 12;
	}
	else {
		document.data.hanetz.value = "";
		document.data.shkia.value = "";
	}

	time = suntime(d, m, y, 106, 6, lngd, lngm, ewi, latd, latm, nsi, adj);
	if(time[1] == 0)
		document.data.alot.value = timeadj(time[2], ampm);
	else
		document.data.alot.value = "";

	time = suntime(d, m, y, 101, 0, lngd, lngm, ewi, latd, latm, nsi, adj);
	if(time[1] == 0)
		document.data.misheyakir.value = timeadj(time[2], ampm);
	else
		document.data.misheyakir.value = "";

	time = suntime(d, m, y, 96, 0, lngd, lngm, ewi, latd, latm, nsi, adj);
	if(time[1] == 0)
		document.data.tzeit.value = timeadj(time[3], ampm);
	else	
		document.data.tzeit.value = "";

	document.data.shema.value    = timeadj(sunrise + shaa_zmanit * 3, ampm);
	document.data.tefillah.value = timeadj(sunrise + shaa_zmanit * 4, ampm);
	document.data.chatzot.value  = timeadj(sunrise + shaa_zmanit * 6, ampm);
	document.data.minchag.value  = timeadj(sunrise + shaa_zmanit * 6.5, ampm);
	document.data.minchak.value  = timeadj(sunrise + shaa_zmanit * 9.5, ampm);
	document.data.plag.value     = timeadj(sunrise + shaa_zmanit * 10.75, ampm);

	my yom = new Date (y, m-1, d);
	if(yom.getDay() == 6) {

		# // motzei shabbat (3 small stars)
		time = suntime(d, m, y, 98, 30, lngd, lngm, ewi, latd, latm, nsi, adj);
		if(time[1] == 0)
			document.data.motzeiShabbat.value = timeadj(time[3], ampm);
		else
			document.data.motzeiShabbat.value = "";

		# // knissat shabbat (sunset from day before)
		my day_before = new Date(yom.getTime() - 86400000);
		db = day_before.getDate();
		mb = day_before.getMonth() + 1;
		yb = day_before.getYear();
		if(yb < 1900)
			yb += 1900;
		time = suntime(db, mb, yb, 90, 50, lngd, lngm, ewi, latd, latm, nsi, adj);
		if(document.data.placename.value == "(Israel) Jerusalem")
			document.data.knissatShabbat.value = timeadj(time[3] - 40.0/60.0, ampm);
		else if(document.data.placename.value == "(Israel) Haifa")
			document.data.knissatShabbat.value = timeadj(time[3] - 30.0/60.0, ampm);
		else if(document.data.placename.value == "(Israel) Be'er Sheva")
			document.data.knissatShabbat.value = timeadj(time[3] - 30.0/60.0, ampm);
		else if(document.data.placename.value == "(Israel) Karnei Shomron")
			document.data.knissatShabbat.value = timeadj(time[3] - 22.0/60.0, ampm);
		else if(document.data.placename.value == "(Israel) Tel Aviv")
			document.data.knissatShabbat.value = timeadj(time[3] - 22.0/60.0, ampm);
		else if(document.data.placename.value == "(Israel) Karnei Shomron")
			document.data.knissatShabbat.value = timeadj(time[3] - 22.0/60.0, ampm);
		else
			document.data.knissatShabbat.value = timeadj(time[3] - 18.0/60.0, ampm);
	}
	else {
		document.data.motzeiShabbat.value = '';
		document.data.knissatShabbat.value = '';
	}


}

sub set_date_vars() {
	month = document.data.month.selectedIndex;
	day   = document.data.day.selectedIndex;
	year  = document.data.year.value;

	var len = civMonthLength(month+1, year);
	if(day >= len) {
		day = len - 1;
		document.data.day.selectedIndex = day;
	}
}


=cut
