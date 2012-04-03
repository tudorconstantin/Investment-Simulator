#!/usr/bin/perl -w

use strict;
use warnings;
use 5.014;

use Math::Financial;
use Data::Printer qw(p);

my $start_config = {
  monthly_investment    => 1000,
  apartment_value       => 30000,
  start_aparments_no    => 0,
  down_payment          => 1000,
  monthly_rent          => 200,
  start_cash            => 0,
  initial_debt          => 0,
  credit_interest_rate  => 7.5,
  total_months          => 360,
  percent_from_assured  => 80,
  max_months_per_credit => 60,

  yearly_rent_increase   => 6,
  apartment_appreciation => 5,
  annual_taxes           => 100,
  annual_reparations     => 200,
};

sub get_assets_value {
  my ($month) = shift;

  $month->{assets_value} = $month->{num_aps} * $start_config->{apartment_value} + $month->{cash} - $month->{debt};
  $month->{total_possible_credit} = ( 1 + $start_config->{percent_from_assured} / 100 ) * $month->{assets_value};

  my $calc = new Math::Financial(
    ir  => $start_config->{credit_interest_rate},
    pmt => $month->{total_to_invest},
    np  => $start_config->{max_months_per_credit},

  );

  $month->{max_credit_on_time} = $calc->loan_size();

  return $month;
}    ## --- end sub get_assets_value

sub buy_aps {

  my ($month) = shift;

  $month->{assets_value} = $month->{num_aps} * $start_config->{apartment_value} + $month->{cash} - $month->{debt};
  $month->{total_possible_credit} = ( 1 + $start_config->{percent_from_assured} / 100 ) * $month->{assets_value};

  my $calc = new Math::Financial(
    ir  => $start_config->{credit_interest_rate},
    pmt => $month->{total_to_invest},
    np  => $start_config->{max_months_per_credit},
  );

  $month->{max_credit_on_time} = $calc->loan_size();

  if ( $month->{max_credit_on_time} + $month->{cash} >= $start_config->{apartment_value}
    && $month->{total_possible_credit} + $month->{cash} >= $month->{max_credit_on_time} )
  {

    my $aps_to_buy = int( ( $month->{max_credit_on_time} + $month->{cash} ) / $start_config->{apartment_value} );

    $month->{credit} = $start_config->{apartment_value} * $aps_to_buy - $month->{cash};

    my $calc_period = new Math::Financial(
      ir  => $start_config->{credit_interest_rate},
      pmt => $month->{total_to_invest},
      pv  => $month->{credit},
    );

    $month->{debt} = int( $calc_period->loan_term() * $month->{total_to_invest} + 0.5 );
    $month->{cash} = 0;

    $month->{num_aps} += $aps_to_buy;
  }

  return $month;
}    ## --- end sub buy_aps

sub next_month_stats {
  my ($month_object) = shift;

  my $monthly_taxes       = $start_config->{annual_taxes} / 12;
  my $monthly_reparations = $start_config->{annual_reparations} / 12;

  if ( $month_object->{debt} > 0 ) {
    $month_object->{debt} -= $month_object->{total_to_invest};

    if ( $month_object->{debt} < 0 ) {
      $month_object->{cash} += -1 * $month_object->{debt};
      $month_object->{debt} = 0;
    }
    return $month_object;
  }

  $month_object->{cash} += $month_object->{total_to_invest};

  if ( $month_object->{cash} >= $start_config->{down_payment} ) {

    $month_object->{num_aps} += 1;

    #               $month_object = buy_aps( $month_object );
    $month_object->{total_to_invest} =
      $start_config->{monthly_investment}
      + ( $month_object->{num_aps} * ( $start_config->{monthly_rent} - $monthly_taxes - $monthly_reparations ) );

    while ( $month_object->{cash} > $start_config->{apartment_value} ) {
      $month_object->{cash} -= $start_config->{apartment_value};
      $month_object->{num_aps} += 1;
    }

    $month_object->{credit_value} = $start_config->{apartment_value} - $month_object->{cash};

    my $calc = new Math::Financial(
      pv  => $month_object->{credit_value},
      ir  => $start_config->{credit_interest_rate},
      pmt => $month_object->{total_to_invest},
    );

    #say $calc->loan_term();
    say $month_object->{total_to_invest};
    $month_object->{debt} = int( $calc->loan_term() * $month_object->{total_to_invest} + 0.5 );
    $month_object->{cash} = 0;
  }

  return $month_object;
}    ## --- end sub get_month_stats

my $months = [];
my $month  = {
  num_aps         => $start_config->{start_aparments_no},
  total_to_invest => $start_config->{monthly_investment}
    + $start_config->{start_aparments_no} * $start_config->{monthly_rent},
  cash => $start_config->{start_cash},
  debt => $start_config->{initial_debt},
};

my $i           = 0;
my $old_num_aps = $start_config->{num_aps};
my $prev_debt   = 0;
while ( $i < $start_config->{total_months} ) {

  $month = next_month_stats($month);
  die "Error in month $i" . p($month) if ( $month->{debt} < 0 or $month->{credit_value} < 0 );
  $month = get_assets_value($month) and say "month $i:" . p($month) if $old_num_aps != $month->{num_aps};
  say "apartment no:" . $month->{num_aps} . " paid in month no: $i" if $prev_debt > 0 && $month->{debt} == 0;
  $old_num_aps = $month->{num_aps};
  $prev_debt   = $month->{debt};
  push( @{$months}, $month );
  $start_config->{apartment_value} *= ( 1 + ( $start_config->{apartment_appreciation} / 100 ) / 12 );
  $start_config->{monthly_rent}    *= ( 1 + ( $start_config->{yearly_rent_increase} / 100 ) / 12 );
  $i++;
}

say "Last month stat " . p($start_config);

