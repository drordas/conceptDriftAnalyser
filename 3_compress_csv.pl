#!/usr/bin/perl -w


## PACKAGES DECLARATION
use WordNet::QueryData;
use WordNet::Similarity;
use Data::Dumper;
use File::ReadBackwards;
use Scalar::Util qw(looks_like_number);
use File::Slurp;
use strict;
use DateTime;
use warnings;
#########################

#Constant declarations
use constant false => 0;
use constant true => 1;
use constant fextracted_concepts => "2_extracted_concepts.csv";
use constant fcompressed_concepts => "3_compresed_concepts.csv";
use constant default_deepness => 5;
use constant initial_position => 0;
#########################################

#Main variables declaration
my $deepness = default_deepness;
my $start = initial_position;
my $wn = WordNet::QueryData->new(noload => 1);
#########################################

my @csvLines = readEMLfromExtractedConcepts(fextracted_concepts);
my @sortedConcepts =getConceptsMap(\@csvLines);

my $start_time = DateTime->now();

printf("   ==========================================================\n");
printf("       2.2) COMPUTING TOPIC FREQUENCY    \n");
printf("   ==========================================================\n");


if (!-e fextracted_concepts or -z fextracted_concepts){
	print("    File '".fextracted_concepts."' is empty or not exists. Aborting execution\n");
	exit 0;
}else{
	if (-z fcompressed_concepts or !-e fcompressed_concepts){
		$start = 0;
		open ( my $fh, '>', fcompressed_concepts) or die "    Cannot open output file. Exiting...\n";	
		print $fh "email_id,M/Y,".vectorToString(\@sortedConcepts)."\n";
		close $fh;
	}else{
		my @last = split /,/, File::ReadBackwards->new(fcompressed_concepts)->readline;
		$start = ($last[0]+1) if (looks_like_number($last[0]));
	}
}

printf("    Hashing concepts ....\n");
my %lineMap = map { $_, 0 } @sortedConcepts;

open (my $fh, '>>', fcompressed_concepts) or die "    Cannot open output file. Exiting...\n";

printf("    Calculating topic frequency ....\n");
for my $line ( $start .. (scalar(@csvLines)-1) ){
	my @ref = @{$csvLines[$line]};
	my %HoC = binarize(\@{$ref[2]},\%lineMap);
	print $fh $ref[0].",".$ref[1].",".hashToSortedString(\%HoC,\@sortedConcepts);
}
close $fh;

my $elapsed = $start_time->subtract_datetime(DateTime->now());

printf("   ==========================================================\n");
printf("      FINISH - SUMMARY    \n");
printf("   ==========================================================\n");
printf("    => Total topics: ".(scalar(@sortedConcepts))."\n");
printf("    => Elapsed time: ".$elapsed->days."d ".$elapsed->hours."h ".$elapsed->minutes."m ".$elapsed->seconds."s\n");
printf("   ==========================================================\n");

#########################################


#Functions

sub getConceptsMap{
	my $arrayRef = shift;
	my %hash;
	my @vector = @{$arrayRef};
	my @toret; 
	for my $level (1 .. (scalar(@vector)-1)){
		foreach my $concept (@{$vector[$level][2]}){
			$hash{$concept}=0;
		}
	}
	
	return (@toret = sort { $a cmp $b} keys %hash);
}

sub getSublevels{
	my $numLevel = shift;
	my @levelArray = ();
	my $begin = 0;
	
	$levelArray[$begin] = [( "entity#n#1" )];
	
	for (my $i=0;$i<$numLevel;$i++){
		my @AoT = ();
		foreach my $term (@{$levelArray[$i]}){
			my @result = split /, /, (join (", ",$wn->querySense($term,"hypo")));
			push @AoT, @result;
		}
		$levelArray[$i+1]=[ @AoT ];
	}
	
	return @levelArray;
}

sub buildConceptsArray{
	my $AoCRef = shift;
	my @AoC = @{$AoCRef};
	my @toret;
	
	for my $pos ( 0 .. (scalar(@AoC)-1) ){
		my @concepts = @{$AoC[$pos][3]};
		for my $i ( 0 .. (scalar(@concepts)-1) ){
			push @toret, $concepts[$i] if (!(grep ( /^$concepts[$i]$/, @toret)) );
		}
	}
	
	return @toret;
}

sub binarize{
	my $AoCRef = shift;
	my $HoCRef = shift;
	
	my @AoC = @{$AoCRef};
	my %HoC = %{$HoCRef};
	
	foreach my $concept (@AoC){
		if (exists ($HoC{$concept}) ){
			$HoC{$concept}=1;
		}
	}
	return %HoC;
}

sub hashToSortedString{
	my $HoCRef = shift;
	my $AoSRef = shift;
	
	my %HoC = %{$HoCRef};
	my @AoS = @{$AoSRef};
	my $string;
	
	foreach my $pos ( 0 .. (scalar(@AoS)-2) ){
		$string.=$HoC{$AoS[$pos]}.",";
	}

	$string.=$HoC{$AoS[(scalar(@AoS)-1)]}."\n";
	
	return $string;
}

sub plainVector{
	my $refVector = shift;
	my @vector = @{$refVector};
	my $string = $1 if ($vector[0][0]=~/(.+)#\w#\d/i);
	
	for my $level (1 .. (scalar(@vector)-1)){
		foreach my $concept (@{$vector[$level]}){
			$string.=",$1" if ($concept=~ /(.+)#\w#\d/i);
		}
	}
	return $string;
}

sub sortConcepts{
	my $refVector = shift;
	my @vector = @{$refVector};
	my @toret;
	
	for my $level (0 .. (scalar(@vector)-1)){
		foreach my $concept (@{$vector[$level]}){
			push @toret, $1 if ($concept=~ /(.+)#\w#\d/i and !(grep ( /^$1$/, @toret)) );
		}
	}
	return @toret;
}

sub vectorToString{
	my $refVector = shift;
	my @vector = @{$refVector};
	my $string;
	
	for my $level (0 .. (scalar(@vector)-2)){
		$string.= $vector[$level].",";
	}
	$string.=$vector[scalar(@vector)-1];
	
	return $string;
}

sub plainMap{
	my $refVector = shift;
	my $refMap = shift;
	my @vector = @{$refVector};
	my %hash = %{$refMap};
	my $string = $1 if ($vector[0][0]=~/(.+)#\w#\d/i);
	
	for my $level (1 .. (scalar(@vector)-1)){
		foreach my $concept (@{$vector[$level]}){
			if ($concept=~ /(.*)#\w#\d/i){
				$string.=",".$hash{$1};
			}
		}
	}
	return ($string."\n");
}

sub vectorToMap{
	my $refVector = shift;
	my @vector = @{$refVector};
	my %toret;

	for my $pos ( 0 .. (scalar(@vector)-1) ){
		$toret{$vector[$pos]}=0;
	}
	return %toret;
}

sub readEMLfromExtractedConcepts{
	my $path = shift;
	my @csvLines;
	
	open (my $data, $path) or return undef;
	my $line = <$data>; #avoid the first line. Is the column description.

	while($line = <$data>){
		chomp $line;
		my @fields = undef;
		if ( (@fields = split /,/, $line) and defined ($fields[2]) ){
			my @concepts = split / /, $fields[2];
			push @csvLines, [ $fields[0], $fields[1], [@concepts] ];
		}
	}
	close $data;
	
	return @csvLines;
}
#########################################
