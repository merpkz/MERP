#!/usr/bin/perl
use strict;
use warnings;
use feature 'say';

#  created 2017 10 07
#  updated 2021 12 08 as requested on /r/homelabs

die 'need to run as root' if $> != 0;
die 'install smartcl first' if ! -e '/sbin/smartctl';

my %disks;
for my $disk ( glob("/dev/sd*") ) {
     chomp $disk;
     next if $disk =~ /\d$/;
     for my $line ( qx(/sbin/smartctl -a "$disk") ) {
         chomp $line;
         if ( $line =~ m/^Device\sModel:\s+(.+?)$/ ) {
             $disks{$disk}{name} = $1;
             $disks{$disk}{dev} = $disk;
         }
         if ( $line =~ m/^Serial\sNumber:\s+(.+?)$/ ) {
             $disks{$disk}{serial} = $1;
         }
         if ( $line =~ m/Power_On_Hours\s.+\s+(.+?)$/ ) {
             $disks{$disk}{poweron} = $1;
         }
         if ( $line =~ m/Reallocated_Sector_Ct\s.+\s(.+?)$/ ) {
             $disks{$disk}{sectors} = $1;
         }
         if ( $line =~ m/Current_Pending_Sector\s.+\s(.+?)$/ ) {
             $disks{$disk}{bad_sectors} = $1;
         }
         if ( $line =~ m/Power_Cycle_Count\s.+\s+(.+?)$/ ) {
             $disks{$disk}{pcycle} = $1;
         }
         if ( $line =~ m/(Airflow_Temperature_Cel|Temperature_Celsius)\s.+\s+(\d+)/ ) {
             $disks{$disk}{temp} = $2;
         }
     }
}

say scalar localtime();
for my $disk ( sort { $$a{'poweron'} <=> $$b{'poweron'} } values %disks ) {
     printf"%8s: %15s: power cycled: %4d, bad sectors: %1d, pending: %1d, temp %2dC, power on: %s\n", $$disk{dev}, $$disk{serial}, $$disk{pcycle}, $$disk{sectors}, $$disk{bad_sectors} || 0,$$disk{temp}, join' ', reverse each %{ sec2human( (($$disk{poweron} * 60 ) * 60 )) }
}

sub sec2human{
     my $secs = shift;
    if    ($secs >= 365*24*60*60) { return { years => sprintf '%.2f', $secs/(365*24*60*60) } }
    elsif ($secs >=     24*60*60) { return { days => sprintf '%.2f', $secs/(24*60*60) } }
    elsif ($secs >=        60*60) { return { hours => sprintf '%.2f', $secs/(60*60) } }
    elsif ($secs >=           60) { return { minutes => sprintf '%.2f', $secs/(60) } }
    else                          { return { seconds => sprintf '%.2f', $secs } }
}
