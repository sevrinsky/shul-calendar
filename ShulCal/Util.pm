package ShulCal::Util;

use strict;
use Encode;
use YAML qw(LoadFile);
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(e2h gematria heb_month eng_month);

our %e2h;

our @heb_months = ('', 'ניסן', 'אייר', 'סיון', 'תמוז', 'מנחם-אב', 'אלול', 'תשרי', 'מרחשון', 'כסלו', 'טבת', 'שבט', 'אדר', 'אדר ב\'');
our @eng_months = ('', 'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני', 'יולי', 'אגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר');

sub e2h {
  my($phrase) = @_;
  # Translate phrase to displayed hebrew
  %e2h = initialize_translations() unless %e2h;
  my $prefix = "";
  if ($phrase =~ s/^(.*' )//) {
    $prefix = $1;
  }
  $phrase = $e2h{$phrase} if ($e2h{$phrase});
  return $prefix .  $phrase;
}

sub heb_month {
  return decode_utf8($heb_months[$_[0]]);
}

sub eng_month {
  return decode_utf8($eng_months[$_[0]]);
}

sub initialize_translations {
  return %{LoadFile("$FindBin::Bin/translations/hebrew.yaml")};
}


sub gematria {
  my($self_or_num, $with_quote) = @_;
  my $num;
  if (ref($self_or_num)) {
    $num = $self_or_num->{h_day};
  }
  else {
    $num = $self_or_num;
  }

  my(@ones) = ('', 'א','ב','ג', 'ד','ה',
	       'ו', 'ז', 'ח', 'ט', 'י');
  my(@tens) = ('', 'י', 'כ', 'ל', 'מ', 'נ', 'ס', 'ע', 'פ', 'צ');
  my(@hundreds) = ('', 'ק', 'ר', 'ש', 'ת');
  my $retval;
  if ($num > 1000) {
    $retval = $ones[int($num / 1000)] . '"';
    $num %= 1000;
  }
  while($num >= 500) {
    $num -= 400;
    $retval .= $hundreds[4];
  }
  if ($num > 100) {
    $retval .= $hundreds[int($num / 100)];
    $num %= 100;
  }
  if ($num == 15) {
    $retval .= "טו";
  }
  elsif ($num == 16) {
    $retval .= "טז";
  }
  else {
    $retval .= $tens[int($num/10)] . $ones[$num % 10];
  }
  my $str = decode_utf8($retval);
  if ($with_quote) {
      if (length($str) > 1) {
          $str = substr($str, 0, length($str) - 1) . '"' . substr($str, -1, 1);
      }
      else {
          $str .= '\'';
      }
  }
  return $str;
}


1;
