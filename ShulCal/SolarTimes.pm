package ShulCal::SolarTimes;

use Astro::Sunrise qw();

use ShulCal::Time;

sub new {
    my($class, %params) = @_;
    my $self = {};
    bless $self, $class;

    $self->init(%params);
    return $self;
}

sub init {
    my($self, %params) = @_;
    my %default_opts = (
                         isdst => 0,
                         lat => 31.714117644594232,
                         lon => 34.9986063478065,
                       );
    my %day_opts = (
                    year => $params{year},
                    month => $params{month},
                    day => $params{day},
                    tz   => $params{timezone},
                   );

    ($self->{sunrise_raw}, $self->{sunset_raw}) = Astro::Sunrise::sunrise( { %default_opts, %day_opts } );

    my $junk;
    ($junk, $self->{havdalah_raw}) = Astro::Sunrise::sunrise( { %default_opts, %day_opts,
                                                                alt => -8.5,
                                                              } );

    ($junk, $self->{tzeit_raw}) = Astro::Sunrise::sunrise( { %default_opts, %day_opts,
                                                             alt => -6.45,
                                                           } );

    ($self->{alot_raw}, $junk) = Astro::Sunrise::sunrise( { %default_opts, %day_opts,
                                                            alt => -20,
                                                          } );

    ($self->{misheyakir_raw}, $junk) = Astro::Sunrise::sunrise( { %default_opts, %day_opts,
                                                                  alt => -11,
                                                                } );

    for my $k (keys %$self) {
        if ($k =~ /_raw$/) {
            my $new_k = $k;
            $new_k =~ s/_raw$//;
            $self->{$new_k} = ShulCal::Time->new($self->{$k});
        }
    }

}

#----------------------------------------------------------------------

sub sunrise {
    my($self) = @_;
    return $self->{sunrise};
}

#----------------------------------------------------------------------

sub sunset {
    my($self) = @_;
    return $self->{sunset};
}

#----------------------------------------------------------------------

sub alot {
    my($self) = @_;
    return $self->{alot};
}

#----------------------------------------------------------------------

sub misheyakir {
    my($self) = @_;
    return $self->{misheyakir};
}

#----------------------------------------------------------------------

sub tzeit {
    my($self) = @_;
    return $self->{tzeit};
}

#----------------------------------------------------------------------

sub havdalah {
    my($self) = @_;
    return $self->{havdalah};
}

#----------------------------------------------------------------------

1;
