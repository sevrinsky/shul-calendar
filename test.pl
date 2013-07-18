#!/usr/bin/perl -w

use strict;
use Suntimes;
use DateTime;
use DateTime::Event::Sunrise;


for my $m (1..12) {
  for my $d (1..30) {
    my $time_calc = new Suntimes(day => $d,
                                 month => $m,
                                 year => 2005,
                                 londeg => 34,
                                 lonmin => 58,
                                 latdeg => 31,
                                 latmin => 45,
                                 timezone => 2);
    print "Sunrise = " . $time_calc->sunrise . "\n";
    print "Sunset = " . $time_calc->sunset . "\n";
    print "Havdalah = " . $time_calc->havdalah . "\n";
    print "Alot = " . $time_calc->alot . "\n";
    print "Tzeit = " . $time_calc->tzeit . "\n";
    print "Sunrise = " . $time_calc->sunrise . "\n\n";

    my $dt = DateTime->new( year   => 2005,
                            month  => $m,
                            day    => $d,
                            time_zone => "+0200");

    my @altitudes = (0, -0.25, -0.583, -0.833, -6, -12, -15, -18);
    for my $a (@altitudes) {
      my $sunrise = DateTime::Event::Sunrise ->new (longitude =>'34.966',
                                                    latitude =>'31.75',
                                                    altitude => $a);
      
      my $both_times = $sunrise->sunrise_sunset_span($dt);
      print "Sunrise ($a) is: " , $both_times->start->datetime . "\n";
      print "Sunset ($a) is: " , $both_times->end->datetime . "\n";
    }
    exit;
  }
}
