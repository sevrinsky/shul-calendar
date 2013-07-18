#!/usr/bin/perl

use YAML;
use ShulCal::Holiday;
use ShulCal::Util;



  my @parshiot = (
                "bereishit",
                "noach",
                "lech lecha",
                "vayera",
                "chayei sarah",
                "toldot",
                "vayetze",
                "vayishlach",
                "vayeshev",
                "miketz",
                "vayigash",
                "vayechi",
                "shmot",
                "vaera",
                "bo",
                "beshalach",
                "yitro",
                "mishpatim",
                "terumah",
                "tetzaveh",
                "ki tisa",
                "vayakhel",
                "pekudei",
                "vayikra",
                "tzav",
                "shmini",
                "tazria",
                "metzora",
                "acharei mot",
                "kedoshim",
                "emor",
                "behar",
                "bechukotai",
                "bemidbar",
                "naso",
                "behaalotcha",
                "shlach",
                "korach",
                "chukat",
                "balak",
                "pinchas",
                "matot",
                  "maasei",
                "devarim",
                "vaetchanan",
                "ekev",
                "reei",
                "shoftim",
                "ki tetze",
                "ki tavo",
                "nitzavim",
                  "vayelech",
                "haazinu",
                 );

my %hash = ShulCal::Util::initialize_translations;
print Dump(\%hash);
