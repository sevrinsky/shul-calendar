#!/usr/bin/perl

use FindBin;
use lib $FindBin::Bin;

use ShulCal::SolarTimes;
use Data::Dumper;

print Dumper(ShulCal::SolarTimes->new(year => 2024, month => 10, day => 6, timezone => 3));
