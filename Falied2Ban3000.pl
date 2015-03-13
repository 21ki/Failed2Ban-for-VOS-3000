#!/usr/bin/perl
use strict;
use DBI;
use File::Copy;

my $db = DBI->connect(
     "dbi:mysql:dbname=vos3000db",
     "root",
     "",
     { RaiseError => 1 },
) or die $DBI::errstr;

my $query = $db->prepare("select DISTINCT callerip from e_cdr where endreason = '-9'");
$query->execute();

my $rows;
my $count=0;
my @heckip;

while ($rows = $query->fetchrow_arrayref()) {
    $heckip[$count++] = @$rows[0];
}

$query->finish();
$db->disconnect();

#read iptables configuration
open(my $fh, '<',"/etc/sysconfig/iptables") or die "Could not open file!\n";
my @lines=<$fh>;
my $linenum = scalar(@lines) - 2;
close $fh;

#backup iptables file
my $t = localtime;
move("/etc/sysconfig/iptables","/etc/sysconfig/iptables.$t") or die "Could not backup file!\n";

#Updated an iptables configuration file
my $i=0;
open(my $fh, '>',"/etc/sysconfig/iptables") or die "Could not open file!\n";
foreach my $line (@lines) {

   for(my $j=0; $j < $count; $j++) {
       my $str = "-A RH-Firewall-1-INPUT -s $heckip[$j] -j DROP\n";
       if($line eq $str) {
         $heckip[$j]="";
       }
   }

   if($i == $linenum) {
      for(my $j=0; $j < $count; $j++) {
        if($heckip[$j]!="") {
          print $fh "-A RH-Firewall-1-INPUT -s $heckip[$j] -j DROP\n";
          #Updated a rule in IPtables
          my $returncode = system("/sbin/iptables -A RH-Firewall-1-INPUT -s $heckip[$j] -j DROP");
          if($returncode != 0) {
              print "Falied to add rules in iptables!\n";
          }

        }
      }
      print $fh $line;
   } else {
       print $fh $line;
   }
   $i++;
}
