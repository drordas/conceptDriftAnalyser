#!/usr/bin/perl -w


## PACKAGES DECLARATION
use Data::Dumper;
use File::ReadBackwards;
use List::MoreUtils qw(uniq);
use Scalar::Util qw(looks_like_number);
use File::Slurp;
use strict;
#use warnings;
use Values;
use Switch;
use experimental 'smartmatch';
use Term::Size 'chars';
#########################################

##Constant declarations
use constant false => 0;
use constant true => 1;
use constant input_file => "4_sort_and_joined_date.csv";
use constant default_value => 1;
use constant initial_position => 0;
use enum qw (READY NOT_PRESENT APPEAR OUTLIER SUDDEN REOCURRENT INCREMENTAL BOUNDARY GRADUAL_DOWN GRADUAL_UP);
#########################################

##MAIN PROGRAM

printf("   ==========================================================\n");
printf("       4) Concept Drift Detection    \n");
printf("   ==========================================================\n");
printf("    1- Loading topics from e-mails\n");
my @input = readEMLfromExtractedConcepts(input_file);
my %output;

#COMPUTING CONCEPT DRIFT
printf("    2- Checking for suddent drift ... ");
%output = check4SuddenDrift(\@input,\%output); 
printf("done\n    3- Checking for incremental drift ...");
%output = check4IncrementalDrift(\@input,\%output); 
printf("done\n    4- Checking gradual drift ...");
%output = check4GradualDrift(\@input,\%output); 
printf("done\n    5- Checking reocurrin drift ...");
%output = check4ReocurrinDrift(\@input,\%output); 
printf("done\n");
printResult(\%output);
#########################################

##Functions
sub check4SuddenDrift{
	my $inputRef = shift;
	my $outputRef = shift;
	my %hashOfConcepts = %{$outputRef};
	my @csv = @{$inputRef};

	for my $numConcepts ( 0 .. (getNumConcepts($inputRef))-1 ){
		my ($conceptName, @sequence) = getConceptAt($numConcepts,$inputRef);
		my $val = Values->new(0,0,0,0,0,0);
		my $actual_state = READY;
		my @stack = ();
		my @tags = ();
		my @states;
		push @stack, $val;
		foreach my $pos (0 .. scalar ((@sequence)-1)) {
			my $number = $sequence[$pos];
			my $actualValue = pop @stack;
			switch($actual_state){
				case READY 
					{
						if ($number == 0 && $actualValue->getU() > 0){
							my $new = Values->new($number,0,$actualValue->getF()+1,
											 $actualValue->getU(),$actualValue->getD(),
											 $actualValue->getC());
							push @stack, $new;
							push @states, "READY";
							$actual_state = READY;
						}elsif ($number == 0 and $actualValue->getU() == 0){
							my $new = Values->new($number,0,$actualValue->getF()+1,
											 0,$actualValue->getD(),$actualValue->getC());
							push @stack, $new;
							push @states, "NOT_PRESENT";
							$actual_state = NOT_PRESENT;
						}elsif ($number > 0){
							my $new = Values->new($number,$actualValue->getH()+1,
											 0,$actualValue->getU(),$actualValue->getD(),$actualValue->getC());
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}else{
							print("     => Unexpected error when detecting suddent drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
							die;
						}
					}
				case NOT_PRESENT 
					{
						if ($number == 0){
							my $new = Values->new($number,$actualValue->getH(),
												  $actualValue->getF()+1,
												  0,0,$actualValue->getC());
							push @stack, $new;
							push @states, "NOT_PRESENT";
							$actual_state = NOT_PRESENT;
						}elsif($number > 0){
							my $new = Values->new($number,$actualValue->getH()+1, #AQUI SE PUEDE PONER UN 1 DIRECTAMENTE.
												  0,0,$actualValue->getF()+1, #YO NO LE PODRÍA EL +1.
												  $actualValue->getC() );
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}else{
							print("     => Unexpected error when detecting suddent drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
							die;
						}
					}
				case APPEAR
					{
						if ($number == 0 and $actualValue->getH() == 1 and $actualValue->getU() == 0){
							my $new = Values->new( $number,0,1,$actualValue->getH(),
												   $actualValue->getD(),$actualValue->getC());
							push @stack, $new;
							push @states, "OUTLIER";
							$actual_state = OUTLIER;
						}elsif ( $number == 0 and $actualValue->getH() >= 1 ) {
							my $new = Values->new( $number, 0,1,
												   $actualValue->getH(),$actualValue->getD(), 
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "READY";
							$actual_state = READY;
						}elsif ( $number > 0 and ( $actualValue->getU() > 0 or 
												   $actualValue->getD() == 0) ) {
							my $new = Values->new( $number, $actualValue->getH()+1,0,
												   $actualValue->getU(),$actualValue->getD(), 
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}elsif ($number > 0 and $actualValue->getU() == 0 and 
								$actualValue->getD()>0 ) {
							my $new = Values->new( $number, $actualValue->getH()+1,0,
												   $actualValue->getU(),
												   $actualValue->getD(), 
												   $actualValue->getC() );		
							push @stack, $new;
							push @states, "SUDDEN";
							$actual_state = SUDDEN;
						}else{
							print("     => Unexpected error when detecting suddent drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");	
							die;
						}
					}
				case OUTLIER
					{
						if ($number == 0){
							my $new = Values->new( $number, 0,
												   $actualValue->getF()+1,
												   $actualValue->getU(),
												   $actualValue->getD(), 
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "OUTLIER";
							$actual_state = OUTLIER;
							push @tags, "OUTLIER" if ($pos == (scalar(@sequence)-1) );
						}elsif ($number > 0){
							my $new = Values->new( $number,1,0,
												   $actualValue->getU(),
												   $actualValue->getF(),
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}else{
							print("     => Unexpected error when detecting suddent drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
						}
					}
				case SUDDEN
					{
						if ( $number > 0 ){
							my $new = Values->new( $number,$actualValue->getH()+1,
												   0,$actualValue->getU(),
												   $actualValue->getD(),
												   $actualValue->getC() );	 
							push @stack, $new;
							push @states, "SUDDEN";
							$actual_state = SUDDEN;
							push @tags, "SUDDEN" if ($pos == (scalar(@sequence)-1));
						}elsif ( $number == 0 ) {
							my $new = Values->new( $number,0,
												   $actualValue->getF()+1,
												   $actualValue->getH(),
												   $actualValue->getD(),
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "READY";
							$actual_state = READY;
						}else{
							print("     => Unexpected error when detecting suddent drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
						}
					}
			}
		}
		if (scalar(@tags)>0){
			if (exists($hashOfConcepts{$conceptName})){
				my @output = @{$hashOfConcepts{$conceptName}};
				my @merged = keys %{{map {($_ => 1)} (@output, @tags)}};
				$hashOfConcepts{$conceptName} = \@merged;
			}else{ $hashOfConcepts{$conceptName}= \@tags; }
		}
	}
	return %hashOfConcepts;
}

sub check4IncrementalDrift{
	my $inputRef = shift;
	my $outputRef = shift;
	my %hashOfConcepts = %{$outputRef};
	my @csv = @{$inputRef};
	
	for my $numConcepts ( 0 .. (getNumConcepts($inputRef))-1 ){
		my ($conceptName, @sequence) = getConceptAt($numConcepts,$inputRef);
		my $val = Values->new(0,0,0,0,0,0);
		my $actual_state = READY;
		my @stack;
		my @tags = ();
		my @states = ();
		push @stack, $val;
		foreach my $pos (0 .. scalar ((@sequence)-1)) {
			my $number = $sequence[$pos];
			my $actualValue = pop @stack;
			switch($actual_state){
				case READY 
					{
						if ($number == 0 && $actualValue->getU() > 0){
							my $new = Values->new($number,0,$actualValue->getF()+1,
											 $actualValue->getU(),$actualValue->getD(),
											 $actualValue->getC());
							push @stack, $new;
							push @states, "READY";
							$actual_state = READY;
						}elsif ($number == 0 and $actualValue->getU() == 0){
							my $new = Values->new($number,0,$actualValue->getF()+1,
											 0,$actualValue->getD(),$actualValue->getC());
							push @stack, $new;
							push @states, "NOT_PRESENT";
							$actual_state = NOT_PRESENT;
						}elsif ($number > 0){
							my $new = Values->new($number,$actualValue->getH()+1,
											 0,$actualValue->getU(),$actualValue->getD(),$actualValue->getC());
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}else{
							print("     => Unexpected error when detecting incremental drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
							die;
						}
					}
				case NOT_PRESENT 
					{
						if ($number == 0){
							my $new = Values->new($number,$actualValue->getH(),
												  $actualValue->getF(),
												  0,0,$actualValue->getC());
							push @stack, $new;
							push @states, "NOT_PRESENT";
							$actual_state = NOT_PRESENT;
						}elsif($number > 0){
							my $new = Values->new($number,$actualValue->getH()+1,
												  0,0,$actualValue->getF(),
												  $actualValue->getC() );
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}else{
							print("     => Unexpected error when detecting incremental drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
							die;
						}
					}
				case APPEAR
					{
						if ($number == 0 and $actualValue->getH() == 1 and $actualValue->getU() == 0) {
							my $new = Values->new( $number, 0,1,
												   $actualValue->getH(),$actualValue->getD(), 
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "OUTLIER";
							$actual_state = OUTLIER;
						}elsif ( $number == 0 and ($actualValue->getU() > 0 or $actualValue->getH() > 1) ){
							my $new = Values->new( $number,0,1,$actualValue->getH(),
												   $actualValue->getD(),$actualValue->getC());
							push @stack, $new;
							push @states, "READY";
							$actual_state = READY;
						}elsif ( $number > 0 and ($number <= $actualValue->getX() or $actualValue->getC()>0) ) {
							my $new = Values->new( $number, $actualValue->getH()+1,0,
												   $actualValue->getU(),$actualValue->getD(), 
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}elsif ( $number > $actualValue->getX() and $actualValue->getC() == 0 ){
							my $new = Values->new( $number, $actualValue->getH()+1,0,
												   $actualValue->getU(),
												   $actualValue->getD(), 
												   $actualValue->getC() );		
							push @stack, $new;
							push @states, "INCREMENTAL";
							$actual_state = INCREMENTAL;
						}else{
							print("     => Unexpected error when detecting incremental drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");	
							die;
						}
					}
				case OUTLIER 
					{
						if ($number == 0){
							my $new = Values->new( $number, 0,
												   $actualValue->getF()+1,
												   $actualValue->getU(),
												   $actualValue->getD(), 
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "OUTLIER";
							$actual_state = OUTLIER;
							push @tags, "OUTLIER" if ($pos == (scalar(@sequence) -1));
						}elsif ($number > 0){
							my $new = Values->new( $number,1,0,
												   $actualValue->getU(),
												   $actualValue->getF(),
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}
					}
				case INCREMENTAL
					{
						if ( $number >= $actualValue->getX() ){
							my $new = Values->new( $number,$actualValue->getH()+1,
												   0,$actualValue->getU(),
												   $actualValue->getD(),
												   $actualValue->getC() );	 
							push @stack, $new;
							push @states, "INCREMENTAL";
							$actual_state = INCREMENTAL;
							push @tags, "INCREMENTAL" if ($pos == (scalar(@sequence)-1));
						}elsif ( $number < $actualValue->getX() ) {
							my $new = Values->new( $actualValue->getX(),
												   $actualValue->getH()+1,
												   0,$actualValue->getU(),
												   $actualValue->getD(),
												   1 );												   
							push @stack, $new;
							push @states, "READY";
							$actual_state = READY;
							push @tags, "INCREMENTAL" if ($pos == (scalar(@sequence)-1));
						}elsif ($number > 0 and $number < $actualValue->getX()*0.9 ) {
							my $new = Values->new( $number,
												   $actualValue->getH()+1,
												   0,$actualValue->getU(),
												   $actualValue->getD(),
												   1 );
							push @stack, $new;
							push @states, "READY";
							$actual_state = READY;
						}elsif ( $number == 0){
							my $new = Values->new( $number,
												   0,$actualValue->getF()+1,
												   $actualValue->getH(),
												   $actualValue->getD(),
												   1 );
							push @stack, $new;
							push @states, "READY";
							$actual_state = READY;
						}else{
							print("     => Unexpected error when detecting incremental drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
							die;
						}
					}
			}
		}
		if (scalar(@tags)>0){
			if (exists($hashOfConcepts{$conceptName})){
				my @output = @{$hashOfConcepts{$conceptName}};
				my @merged = keys %{{map {($_ => 1)} (@output, @tags)}};
				$hashOfConcepts{$conceptName} = \@merged;
			}else{ $hashOfConcepts{$conceptName}= \@tags; }
		}
	}
	
	return %hashOfConcepts;
}

sub check4GradualDrift{
	my $inputRef = shift;
	my $outputRef = shift;
	my %hashOfConcepts = %{$outputRef};
	my @csv = @{$inputRef};
	
	for my $numConcepts ( 0 .. (getNumConcepts($inputRef))-1 ){
		my ($conceptName, @sequence) = getConceptAt($numConcepts,$inputRef);
		my $val = Values->new(0,0,0,0,0,0);
		my $actual_state = READY;
		my @stack;
		my @tags = ();
		my @states = ();
		push @stack, $val;
		foreach my $pos (0 .. scalar ((@sequence)-1)) {
			my $number = $sequence[$pos];
			my $actualValue = pop @stack;
			switch($actual_state){
				case READY 
					{
						if ($number == 0 && $actualValue->getU() > 0){
							my $new = Values->new($number,0,$actualValue->getF()+1,
											 $actualValue->getU(),$actualValue->getD(),
											 $actualValue->getC());
							push @stack, $new;
							push @states, "READY";
							$actual_state = READY;
						}elsif ($number == 0 and $actualValue->getU() == 0){
							my $new = Values->new($number,0,
												  $actualValue->getF()+1,
												  0,$actualValue->getD(),
												  $actualValue->getC());		
							push @stack, $new;
							push @states, "NOT_PRESENT";
							$actual_state = NOT_PRESENT;
						}elsif ($number > 0 ){
							my $new = Values->new($number,1,
												  0,$actualValue->getU(),
												  $actualValue->getD(),
												  $actualValue->getC());		
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}else{
							print("     => Unexpected error when detecting gradual drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
							die;
						}
					}
				case NOT_PRESENT 
					{
						if ($number == 0){
							my $new = Values->new($number,$actualValue->getH(),
												  $actualValue->getF()+1,0,0,0);
							push @stack, $new;
							push @states, "NOT_PRESENT";
							$actual_state = NOT_PRESENT;
						}elsif ($number > 0){
							my $new = Values->new($number,$actualValue->getH()+1,
												  0,0,$actualValue->getF(),
												  $actualValue->getC());
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}else{
							print("     => Unexpected error when detecting incremental drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
							die;
						}
					}
				case APPEAR
					{
						if ( $number > 0 ){
							my $new = Values->new($number, $actualValue->getH()+1,
											   0,$actualValue->getU(),
											   $actualValue->getD(),0);
							push @stack, $new;
							push @states, "APPEAR";
							$actualValue = APPEAR;
						}elsif ($number == 0 and $actualValue->getH() == 1 and 
								$actualValue->getU() == 0) {
							my $new = Values->new($number,0,1,
												  $actualValue->getH(), 
												  $actualValue->getD(), 
												  $actualValue->getC());
							push @stack, $new;
							push @states, "OUTLIER";
							$actual_state=OUTLIER;
						}elsif ($number == 0 and $actualValue->getH() >= 1) {
							my $new = Values->new($number,0,1,
												  $actualValue->getH(),0,0);
							push @stack, $new;
							push @states, "GRADUAL_DOWN";
							$actual_state = GRADUAL_DOWN;
							push @tags, "GRADUAL" if($actualValue->getC() >=1 and $pos == (scalar(@sequence)-1));
						}else{
							print("     => Unexpected error when detecting incremental drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							printf("\n");
							die;	
						}
					}
				case OUTLIER 
					{
						if ($number == 0){
							my $new = Values->new( $number, 0,
												   $actualValue->getF()+1,
												   $actualValue->getU(),
												   $actualValue->getD(), 
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "OUTLIER";
							$actual_state = OUTLIER;
							push @tags, "OUTLIER" if ($pos == (scalar(@sequence) -1 ) );
							
						}elsif ($number > 0){
							my $new = Values->new( $number,1,0,
												   $actualValue->getU(),
												   $actualValue->getF(),
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}
					}
				case GRADUAL_DOWN
					{
						if ( $number > 0 ){
							my $new = Values->new( $number,1,
												   0,$actualValue->getU(),
												   $actualValue->getF(),
												   $actualValue->getC() );	 
							push @stack, $new;
							push @states, "BOUNDARY";
							$actual_state = BOUNDARY;
							push @tags, "GRADUAL" if($actualValue->getC() >=1 and $pos == (scalar(@sequence)-1));
							
						}elsif ( $number == 0 and $actualValue->getF() < $actualValue->getU() ) {
							my $new = Values->new( $number,$actualValue->getH(),
												   $actualValue->getF()+1,
												   $actualValue->getU(),
												   $actualValue->getD(),
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "GRADUAL_DOWN";
							$actual_state = GRADUAL_DOWN;
							push @tags, "GRADUAL" if($actualValue->getC() >=1 and $pos == (scalar(@sequence)-1));
						}elsif ($number == 0 and $actualValue->getF() >= $actualValue->getU() ) {
							my $new = Values->new( $number,
												   $actualValue->getH(),
												   $actualValue->getF()+1,
												   $actualValue->getU(),
												   $actualValue->getD(),
												   0 );
							push @stack, $new;
							push @states, "READY";
							$actual_state = READY;
							push @tags, "GRADUAL" if($actualValue->getC() >=1 and $pos == (scalar(@sequence)-1));
						}else{
							print("     => Unexpected error when detecting incremental drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							printf("\n");
							die;
						}
					}
				case BOUNDARY 
					{
						if ($number > 0 and $actualValue->getU() <= $actualValue->getH() ){
							my $new = Values->new( $number,
												   $actualValue->getH()+1,
												   $actualValue->getF(),
												   $actualValue->getU(),
												   $actualValue->getD(),
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "GRADUAL_UP";
							$actual_state = GRADUAL_UP;
							push @tags, "GRADUAL" if($actualValue->getC() >=1 and $pos == (scalar(@sequence)-1));
						}
						elsif ($number > 0 and $actualValue->getU() > $actualValue->getH()){
							my $new = Values->new( $number,
												   $actualValue->getH()+1,
												   $actualValue->getF(),
												   $actualValue->getU(),
												   $actualValue->getD(),
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "BOUNDARY";
							$actual_state = BOUNDARY;
							push @tags, "GRADUAL" if($actualValue->getC() >=1 and $pos == (scalar(@sequence)-1));
						}elsif ($number == 0 ) {
							my $new = Values->new( $number,
												   0,
												   1,$actualValue->getH(),
												   $actualValue->getD(),
												   0 );
							push @stack, $new;
							push @states, "READY";
							$actual_state = READY;
							push @tags, "GRADUAL" if($actualValue->getC() >=1);
						}else{
							print("     => Unexpected error when detecting incremental drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
							die;
						}
					}
				case GRADUAL_UP
					{
			
						if ($number > 0 ){
							my $new = Values->new($number, 
												  $actualValue->getH(),
												  $actualValue->getF()+1,
												  $actualValue->getU(),
												  $actualValue->getC());
							push @stack, $new;
							push @states, "GRADUAL_UP";
							push @tags, "GRADUAL" if($actualValue->getC() >=1 and $pos == (scalar(@sequence)-1));
							$actual_state = GRADUAL_UP;
						}elsif ($number == 0){
							my $new = Values->new($number,0,1,
												  $actualValue->getH(),
												  $actualValue->getD(),
												  $actualValue->getC()+1);
							push @stack, $new;
							push @states, "GRADUAL_DOWN";
							$actual_state = GRADUAL_DOWN;
							push @tags, "GRADUAL" if($actualValue->getC() >=1 and $pos == (scalar(@sequence)-1));
						}else{
							print("     => Unexpected error when detecting incremental drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
							die;
						}
					}
			}
		}
		if (scalar(@tags)>0){
			if (exists($hashOfConcepts{$conceptName})){
				my @output = @{$hashOfConcepts{$conceptName}};
				my @merged = keys %{{map {($_ => 1)} (@output, @tags)}};
				$hashOfConcepts{$conceptName} = \@merged;
			}else{ $hashOfConcepts{$conceptName}= \@tags; }
		}
	}
	
	return %hashOfConcepts;
}

sub check4ReocurrinDrift{
	my $inputRef = shift;
	my $outputRef = shift;
	my %hashOfConcepts = %{$outputRef};
	my @csv = @{$inputRef};
	
	for my $numConcepts ( 0 .. (getNumConcepts($inputRef))-1 ){
		my ($conceptName, @sequence) = getConceptAt($numConcepts,$inputRef);
		my $val = Values->new(0,0,0,0,0,0);
		my $actual_state = READY;
		my @stack;
		my @tags = ();
		my @states = ();
		push @stack, $val;
			foreach my $pos (0 .. scalar ((@sequence)-1)) {
			my $number = $sequence[$pos];
			my $actualValue = pop @stack;
			switch($actual_state){
				case READY 
					{
						if ($number == 0 && $actualValue->getU() > 0){
							my $new = Values->new($number,0,$actualValue->getF()+1,
											 $actualValue->getU(),$actualValue->getD(),
											 $actualValue->getC());
							push @stack, $new;
							push @states, "READY";
							$actual_state = READY;
						}elsif ($number == 0 and $actualValue->getU() == 0){
							my $new = Values->new($number,0,
												  $actualValue->getF()+1,
												  0,$actualValue->getD(),
												  $actualValue->getC());		
							push @stack, $new;
							push @states, "NOT_PRESENT";
							$actual_state = NOT_PRESENT;
						}elsif ($number > 0 ){
							my $new = Values->new($number,1,
												  0,$actualValue->getU(),
												  $actualValue->getD(),
												  $actualValue->getC());		
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}else{
							print("     => Unexpected error when detecting reocurring drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
							die;
						}
					}
				case NOT_PRESENT 
					{
						if ($number == 0){
							my $new = Values->new($number,$actualValue->getH(),
												  $actualValue->getF()+1,0,0,0);
							push @stack, $new;
							push @states, "NOT_PRESENT";
							$actual_state = NOT_PRESENT;
						}elsif ($number > 0){
							my $new = Values->new($number,$actualValue->getH()+1,
												  0,0,$actualValue->getF(),
												  $actualValue->getC());
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}else{
							print("     => Unexpected error when detecting reocurring drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							print("\n");
							die;
						}
					}
				case APPEAR
					{
						if ( $number > 0 ){
							my $new = Values->new($number, $actualValue->getH()+1,
											   0,$actualValue->getU(),
											   $actualValue->getD(),0);
							push @stack, $new;
							push @states, "APPEAR";
							$actualValue = APPEAR;
						}elsif ($number == 0 and $actualValue->getH() == 1 and $actualValue->getU() == 0) {
							my $new = Values->new($number,0,1,
												  $actualValue->getH(), 
												  $actualValue->getD(), 
												  $actualValue->getC());
							push @stack, $new;
							push @states, "OUTLIER";
							$actual_state=OUTLIER;
						}elsif ( $number == 0 and ($actualValue->getH() >= 1 or $actualValue->getU() > 0) ) {
							my $new = Values->new($number,0,1,$actualValue->getH(),0,0);
							push @stack, $new;
							push @states, "REOCURRENT";
							$actual_state = REOCURRENT;
							push @tags, "REOCURRENT" if($pos == (scalar(@sequence)-1));
						}else{
							print("     => Unexpected error when detecting reocurring drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							printf("\n");
							die;	
						}
					}
				case OUTLIER 
					{
						if ($number == 0){
							my $new = Values->new( $number, 0,
												   $actualValue->getF()+1,
												   $actualValue->getU(),
												   $actualValue->getD(), 
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "OUTLIER";
							$actual_state = OUTLIER;
							push @tags, "OUTLIER" if ($pos == (scalar(@sequence)-1 ) );
						}elsif ($number > 0){
							my $new = Values->new( $number,1,0,
												   $actualValue->getU(),
												   $actualValue->getF(),
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}
					}
				case REOCURRENT
					{
						if ( $number > 0 ){
							my $new = Values->new( $number,1,
												   0,$actualValue->getU(),
												   $actualValue->getF(),
												   $actualValue->getC() );	 
							push @stack, $new;
							push @states, "APPEAR";
							$actual_state = APPEAR;
						}elsif ($number == 0 ) {
							my $new = Values->new( $number,
												   $actualValue->getH(),
												   $actualValue->getF()+1,
												   $actualValue->getU(),
												   $actualValue->getD(),
												   $actualValue->getC() );
							push @stack, $new;
							push @states, "REOCURRENT";
							$actual_state = READY;
							push @tags, "REOCURRENT" if ($pos == (scalar(@sequence)-1));
						}else{
							print("     => Unexpected error when detecting reocurring drift\n");
							print("        Stack status\n");
							$actualValue->printClass();
							printf("\n");
							die;
						}
					}
			}
		}
		if (scalar(@tags)>0){
			if (exists($hashOfConcepts{$conceptName})){
				my @output = @{$hashOfConcepts{$conceptName}};
				my @merged = keys %{{map {($_ => 1)} (@output, @tags)}};
				$hashOfConcepts{$conceptName} = \@merged;
			}else{ $hashOfConcepts{$conceptName}= \@tags; }
		}
	}
		
	return %hashOfConcepts;
}

sub readEMLfromExtractedConcepts{
	my $path = shift;
	my @dates;
	my @csvLines = ();
	open (my $data, $path) or die "Cannot open file\n";
		
	my $firstLine = <$data>;
	chomp $firstLine;
	my @arrayConcepts = split(",",$firstLine);
	my @concepts = splice @arrayConcepts, 1 ;
	push @csvLines, [ undef, \@concepts, undef ];
	
	
	while(my $line = <$data>){
		chomp $line;
		my @fields = split (",", $line);
		my $date = $fields[0];
		my @AoConcepts = splice @fields, 1 ;
		my $counter = 0;
		foreach (@AoConcepts){ $counter += $_; }
		foreach my $freq (@AoConcepts){ $freq /= $counter};
		push @csvLines, [ $date, \@AoConcepts];
	}
	
	close $data;
		
	return @csvLines;
}

sub getConceptAt{
	my $number = shift;
	my $ArrayRef = shift;
	my @array = @{$ArrayRef};
	my @toret = ();
	my $date = $array[0][0];
	my @concepts = @{$array[0][1]};
	
	if ( $number > (scalar(@concepts)-1) ){
		print "Exceed array limit\n";
		return undef;
	}
		
	for my $pos  (1 .. scalar(@array)-1){
		my @concepts = @{$array[$pos][1]};
		push @toret, $concepts[$number];
	}
	
	return ( $concepts[$number], @toret );
}

sub getNumConcepts{
	my $arrayRef = shift;
	my @array = @{$arrayRef};
	
	return scalar ( @{$array[0][1]} );
}

sub printResults{
	my $HAMhashRef = shift;
	my $SPAMhashRef = shift;
	my %HAMoutput = resultToDrift($HAMhashRef);
	my %SPAMoutput = resultToDrift($SPAMhashRef);
	
	print "=====================\n";
	print " PRINTING HAM RESULT \n";
	print "=====================\n";
	foreach my $key (sort keys %HAMoutput){
		print "[".@{$HAMoutput{$key}}."] ".$key."\n[".join(",",@{$HAMoutput{$key}})."]\n\n";
	}
	print "======================\n";
	print " PRINTING SPAM RESULT \n";
	print "======================\n";
	foreach my $key (sort keys %SPAMoutput){
		print "[".@{$SPAMoutput{$key}}."] ".$key, "\n[".join(",",@{$SPAMoutput{$key}})."]\n\n";
	}
}

sub printResult{
	my $hashRef = shift;
	my %output = resultToDrift($hashRef);
	my ($columns, $rows) = chars;
	$rows-=7;
	printf("   ==========================================================\n");
	printf("      FINISH - SUMMARY    \n");
	printf("   ==========================================================\n");
	foreach my $key (sort keys %output){
		printf("    => $key Drift; Num. Topics = ".@{$output{$key}}."\n");
		printf("       [".join(",",@{$output{$key}})."]\n\n");
	}
}

sub resultToDrift{
	my $hashRef = shift;
	my %hash = %{$hashRef};
	my %output;
	
	foreach my $key (sort (keys %hash) ){
		my @array = %hash{$key};
		push @{$output{"OUTLIER"}}, $key if ("OUTLIER" ~~ @array);
		push @{$output{"GRADUAL"}}, $key if ("GRADUAL" ~~ @array);
		push @{$output{"REOCURRENT"}}, $key if ("REOCURRENT" ~~ @array);
		push @{$output{"INCREMENTAL"}}, $key if ("INCREMENTAL" ~~ @array);
		push @{$output{"SUDDEN"}}, $key if ("SUDDEN" ~~ @array);
	}
	
	return %output;
}
