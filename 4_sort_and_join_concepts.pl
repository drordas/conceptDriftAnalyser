#!/usr/bin/perl -w


## PACKAGES DECLARATION
use Data::Dumper;
use File::ReadBackwards;
use Scalar::Util qw(looks_like_number);
use Getopt::Long qw(GetOptions);
use File::Slurp;
use strict;
use warnings;
use Time::Piece;
use DateTime;

#########################

#Constant declarations
use constant false => 0;
use constant true => 1;
use constant fcompressed_concepts => "3_compresed_concepts.csv";
use constant fsort_and_joined_date => "4_sort_and_joined_date.csv";
use constant default_value => 1;
use constant initial_position => 0;
#########################################

#Main variables declaration
my $year = true;
my $month = true;
my $week = false;
my $keep_user = false;
my $start = initial_position;
#########################################

#Input parameters
GetOptions(
	'year|y' => \$year,
	'month|m' => \$month,
	'week|w' => \$week,
	'keepuser|u' => \$keep_user);	

#print "Values set: \n";
#if ($year) {print "- Year -> ON\n"} else {print "- YEAR -> OFF\n";}
#if ($month) {print "- Month -> ON\n"} else {print "- Month -> OFF\n";}
#if ($week) {print "- WeekMonth -> ON\n"} else {print "- WeekMonth -> OFF\n";}
#if ($keep_user) {print "- Keep User -> ON\n"} else {print "- Keep User -> OFF\n";}
#########################################

#MAIN PROGRAM

my $start_time = DateTime->now();

printf("   ==========================================================\n");
printf("       3) Topics sorting process    \n");
printf("   ==========================================================\n");

my $outputFilename = fsort_and_joined_date;
my $conceptsTitles = readEMLHeader(fcompressed_concepts);

if (!-e fcompressed_concepts or -z fcompressed_concepts){
	printf("    File '".fcompressed_concepts."' is empty or not exists. Aborting execution\n");
	exit 0;
}else{
	if (-z $outputFilename or !-e $outputFilename){
		$start = 0;
		open ( my $fh, '>', $outputFilename) or die printf("    Cannot open output file\n");	
		my $date="";
		$date.="YYYY/" if ($year);
		$date.="MM/" if ($month);
		$date.="W/" if ($week);
		$date =~ s/(.*)\//$1/;
		
		if ($keep_user){ 
			print $fh "user_name,$date,$conceptsTitles";
		}else{ print $fh "$date,$conceptsTitles";}
		close $fh;
	}else{
		my @last = split /,/, File::ReadBackwards->new($outputFilename)->readline;
		$start = ($last[0]+1) if (looks_like_number($last[0]));
	}
}
printf("    1- Reading CSV information\n");
my @csvLines = readEMLfromExtractedConcepts(fcompressed_concepts);
my @conceptsTitles = readEMLHeader(fcompressed_concepts);

if (!@csvLines){
	printf("    Cannot obtain data from CSV: ".fcompressed_concepts." Aborting execution ...\n");
	exit 0;
}

open ( my $fh, '>>', $outputFilename) or die "[ERROR][MAIN]: Cannot open output file\n";

printf("    2- Sorting information by date\n");
my %joinedConcepts = joinConceptsByDate(\@csvLines,$year,$month,$week);
my @arrayByDate = dateMapToArray(\%joinedConcepts,$year,$month,$week);

printf("    3- Writting results\n");
foreach my $pos (0 .. (scalar(@arrayByDate)-1) ){
	print $fh $arrayByDate[$pos][0].",";
	for my $values (0 .. (scalar(@{$arrayByDate[$pos][1]})-2)){
		print $fh $arrayByDate[$pos][1][$values].",";
	}
	print $fh $arrayByDate[$pos][1][(scalar(@{$arrayByDate[$pos][1]})-1)]."\n";
}

my $elapsed = $start_time->subtract_datetime(DateTime->now());

printf("   ==========================================================\n");
printf("      FINISH - SUMMARY    \n");
printf("   ==========================================================\n");
printf("    => Elapsed time: ".$elapsed->days."d ".$elapsed->hours."h ".$elapsed->minutes."m ".$elapsed->seconds."s\n");
printf("   ==========================================================\n");
close($fh);

#########################################

#Functions

sub readEMLHeader{
	my $path = shift;
	open (my $data, $path) or return undef;
	my $line = <$data>;
	my @array = split /,/, $line;
	my @concepts = splice @array, 3;
	return join ',', @concepts
}

sub readEMLfromExtractedConcepts{
	my $path = shift;
	my @csvLines;
	
	open (my $data, $path) or return undef;
	my $line = <$data>; #avoid the first line. Is the column description.

	while($line = <$data>){
		chomp $line;
		my @fields = split (",", $line);
		my $date = $fields[1];
		my $user = $fields[2];
		my @concepts = splice @fields, 3 ;
		push @csvLines, [ $date, $user, \@concepts ];
	}
	close $data;
	
	return @csvLines;
}

sub joinConceptsByDate{
	my $arrayRef = shift;
	my $year = shift;
	my $month = shift; 
	my $week = shift;
	
	my @AoE = @{$arrayRef};
	my %HoC;
	
	foreach my $line (@AoE){
		my @email = @$line;
		my $key = $email[0];
		$key =~s/(\d{4}\/\d{1,2})\/\d{1,2}/$1/ if ($year and $month and !$week);
		$key =~s/(\d{4})\/\d{1,2}\/\d{1,2}/$1/ if ($year and !$month and !$week);
		if (exists $HoC{$key}){
			my @dst = $HoC{$key};
			my @aux = splice (@email, 2);
			$HoC{$key}=sumateConcepts(@dst,@aux);
		}else{ $HoC{$key} = splice(@email, 2); }
	}
	return %HoC;
}

sub joinConceptsByUser{
	my $arrayRef = shift;
	my $year = shift;
	my $month = shift; 
	my $week = shift;
	
	my @AoE = @{$arrayRef};
	my %HoC;
	
	foreach my $line (@AoE){
		my @email = @$line;
		my $user_key = $email[1];
		my $date_key = $email[0];
		$date_key =~s/(\d{4}\/\d{1,2})\/\d{1,2}/$1/ if ($year and $month and !$week);
		$date_key =~s/(\d{4})\/\d{1,2}\/\d{1,2}/$1/ if ($year and !$month and !$week);
		if (exists $HoC{$user_key}{$date_key}){
			my @dst = $HoC{$user_key}{$date_key};
			my @aux = splice (@email, 2);
			$HoC{$user_key}{$date_key}=sumateConcepts(@dst,@aux);
		}else{ $HoC{$user_key}{$date_key} = splice(@email, 2); }
	}
	return %HoC;
}

sub dateMapToArray{
	my $hashRef = shift;
	my $year = shift;
	my $month = shift; 
	my $week = shift;
	
	my %hash = %{$hashRef};
	my @toret;
	
	foreach my $email_key (keys %hash){
		push @toret, [ $email_key, \@{$hash{$email_key}} ];
	}
	
	return sort { Time::Piece->strptime($a->[0],'%Y/%m') <=> Time::Piece->strptime($b->[0],'%Y/%m') } @toret if ($year and $month and !$week);
	
	return sort { Time::Piece->strptime($a->[0],'%Y') <=> Time::Piece->strptime($b->[0],'%Y') } @toret if ($year and !$month and !$week);
	
	return sort { Time::Piece->strptime($a->[0],'%Y/%m/%d') <=> Time::Piece->strptime($b->[0],'%Y/%m/%d') } @toret if ($year and $month and $week);
}

sub userMapToArray{
	my $hashRef = shift;
	
	my %hash = %{$hashRef};
	my @toret;
	
	foreach my $user_key (keys %hash){
		foreach my $date_key (keys %{$hash{$user_key}}){
			push @toret, [ $user_key, $date_key, \@{$hash{$user_key}{$date_key}} ];
		}
	}
	
	return sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1]} @toret;
}

sub sumateConcepts{
	my $srcRef = shift;
	my $dstRef = shift;
	
	my @srcA = @{$srcRef};
	my @dstA = @{$dstRef};
	my $srcSize = scalar(@srcA);
	my $dstSize = scalar(@dstA);
	
	my @toret;
	
	if ($srcSize != $srcSize){
		print "Error Array elements can not be summed due to have different size\n";
		die;
	}
	
	for my $pos (0 .. ($srcSize-1) ){
		push @toret, $srcA[$pos]+$dstA[$pos];
	}
	
	return \@toret;
}
#########################################
