#!/usr/bin/perl -Tw
# getdrafts.pl -- an IETF draft retriever/printer
# 
# Eric Rescorla
# ekr@networkresonance.com

use Getopt::Std;
use File::Path;

getopts("vVpncd:",\%opts);

# Untaint env (this is perl fodder)
$env=$ENV{"PATH"};
$env=~/^(.*)$/;
$ENV{"PATH"}=$1;
$env=$ENV{"CDPATH"};
$env=~/^(.*)$/;
$ENV{"CDPATH"}=$1;


$VERBOSE=0;
$VERBOSE=1 if $opts{"v"};
$VERBOSE=2 if $opts{"V"};
$NODOWNLOAD=1 if $opts{"n"};
$PRINTDRAFTS=1 if $opts{"p"};
$CLEAN=1 if $opts{"c"};

$stat_found=0;
$stat_total=0;

&usage() unless $#ARGV>=1;

$mtg_tmp=shift @ARGV;
die("Bad meeting name $mtg_tmp: try YY<monthname> like 07mar") unless $mtg_tmp=~/^(\d\d[a-z][a-z][a-z])$/;
$mtg=$1;

$AGENDA_URL="http://www3.ietf.org/proceedings/$mtg/agenda/";
$DRAFT_URL="http://www.ietf.org/internet-drafts/";
$PRINT_COMMAND="enscript -2rG -h";

if($opts{'d'}){
  $lp_tmp=$opts{'d'};
  $lp_tmp=~/^(\S+)$/;
  $lp=$1;

  $PRINT_COMMAND .= " -d $lp";
}

if($CLEAN){
  rmtree([$mtg],0,0);
}

mkdir($mtg);
chdir($mtg);

use LWP::UserAgent;

$ua=LWP::UserAgent->new;
$ua->agent("DraftScraper");


while ($wg_tmp=shift @ARGV){

  die("Bad wg name") unless $wg_tmp=~/^(\w+)$/;  # untaint wg
  $wg=$1;

  print STDERR "WG: $wg\n" if $VERBOSE;
  &get_drafts_for_wg($wg);
  &print_drafts_for_wg($wg) if $PRINTDRAFTS;
}

while($nf=shift @NOTFOUND){
  print STDERR "NOT FOUND: $nf\n";
}
print STDERR "Found $stat_found out of $stat_total drafts\n";


exit(0);


sub get_drafts_for_wg {
  local($wg)=@_;

  my @drafts=&list_drafts_for_wg($wg);


  return if $#drafts==-1;
  $stat_total+=$#drafts+1;

  mkdir($wg);

  while($draft=shift @drafts){
    if (-f "$wg/$draft") {
      print STDERR "$draft already exists\n" if $VERBOSE;
      $stat_found++;
      next;
    };
    
    my $ret=&get_draft($draft,"$wg/$draft") unless $NODOWNLOAD;
    $stat_found++ unless $ret;
  }
}

  
sub list_drafts_for_wg {
  local($wg)=@_;
  my $url= $AGENDA_URL. $wg;

  print STDERR "  URL=$url\n" if $VERBOSE;

  my $req=HTTP::Request->new(GET=>$url);
  my $res=$ua->request($req);

  if(!$res->is_success){
    print STDERR "Couldn't get agenda for $wg\n" if $VERBOSE;
    push(@NOTFOUND,"WG: $wg");
    return ();
  }

  my $content=$res->content;
  
  my @drafts=();
  my(%drafts)=();

  if($VERBOSE>1){
    print STDERR "CONTENTS======\n";
    print STDERR $content;
    print STDERR "==============\n";
  }

  while($content =~ m!(draft-[a-z0-9\.-]+-\d\d)!mgis){
    my $d=$1;

    # Double-check filter for bad stuff
    next unless $d=~/^[a-z0-9\.-]+-\d\d$/;

    my $draft="$d.txt";
    
    next if $drafts{$draft};

    push(@drafts,$draft);
    $drafts{$draft}=1;
      
    print STDERR "  DRAFT: $draft\n" if $VERBOSE;
  }

  @drafts;
}

sub get_draft {
  local($draft,$filename)=@_;

  $url=$DRAFT_URL . $draft;

  print STDERR "draft URL: $url\n" if $VERBOSE;

  my $req=HTTP::Request->new(GET=>$url);
  my $res=$ua->request($req);

  if(!$res->is_success){
    print STDERR "Couldn't get draft $draft\n" if $VERBOSE;
    push(@NOTFOUND,"DRAFT: $draft");
    return -1;
  }

  open(OUT,">$filename")||die("Couldn't open $filename");
  print OUT $res->content;
  close(OUT);
  return 0;
}

sub print_drafts_for_wg {
  local($wg)=@_;

  my @files=();

  opendir(DIR,"$wg")||die("Couldn't open directory $wg");
  open(HEADER,">$wg/HEADER")||die("Couldn't open header");

  print HEADER "************** WG $wg *****************\n\n";

  while($file=readdir(DIR)){
    next if $file eq ".";
    next if $file eq "..";
    next if $file=~/.printed$/;
    next if $file=~/HEADER/;

    next unless $file=~/^(draft-[a-z0-9\.-]+-\d\d.txt)$/;
    $file=$1;

    # Add a copy of this to the header page
    print HEADER "[] $file\n";

    # suppress anything already printed
    next if -f "$wg/.printed.$file";

    push(@files,$1);
  }
  
  close(HEADER);

  return if($#files==-1);  #nothing to do

  #Print the burst page/header
  system("$PRINT_COMMAND $wg/HEADER");

  while($file=shift @files){
    system("$PRINT_COMMAND $wg/$file");    
    &touch("$wg/.printed.$file");
  }
}

sub touch {
  local($filename)=@_;
  
  open(OUT,">$filename");
  close(OUT);
}

sub usage {
  print <<FOO;
usage: [-vVpnt] getdrafts.pl <meeting-name> <wg1> <wg2>

 Get a copy of every relevant draft for a given meeting for
 some set of wgs and stuff them in <meeting-name>/<wgname>

 -v = verbose
 -V = really verbose
 -p = print all the drafts that haven't been printed yet
 -n = don't download drafts that aren't here already
 -c = clean up

FOO

exit(0);
}
