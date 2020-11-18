# shul-calendar

## Overview

Generates monthly tefillah times calendar for [Kehillat Ahavat Tzion](https://www.ahavat-tzion.com/) in Ramat Beit Shemesh, since Menachem-Av 5764 (August 2004)

## Usage

```
shul_cal2.cgi --month 9 --year 5781 --fullpage --noinclude-shiur-times --noinclude-chofesh-hagadol --noinclude-shiurim --include-corona --noinclude-late-friday > ~/web/mamash.com/kat-calendars/5781_09.html
```

## Technical background

Most of the regular weekday, Shabbat, and holiday times are handled in code by `ShulCal::Day`. Shabbat parsha calculation is handled by `ShulCal::Holiday`.

Holidays and other special occasions (including bar mitzvahs) are defined in `holidays.yaml`.

Gregorian-Hebrew date conversion is handled mostly by [Perl module `DateTime::Calendar::Hebrew`](https://metacpan.org/pod/release/WEINBERG/DateTime-Calendar-Hebrew-0.01/Hebrew.pm).

Solar times are calculated using `Suntimes.pm`, which is my own Perl port of a long chain of astronimcal calculation libraries leading back to `SUN.C`.

Historical generated calendars are available at [my backup of the shul's previous website](http://kat.mamash.com/calendar.php).
