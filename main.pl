#!/usr/bin/perl -w

use strict;
use warnings;
use Switch;

use constant false => 0;
use constant true => 1;
use constant preproc_file => "1_sorted_eml_by_date.csv";
use constant raw_topics_file => "2_extracted_concepts.csv";
use constant compress_topics_file => "3_compresed_concepts.csv";
use constant sorted_topics_file => "4_sort_and_joined_date.csv";
use Scalar::Util qw (looks_like_number);
use feature qw(switch say);
#VARIABLE DEFINITIONS

my $DIRECTORY;
my $OUTPUT;
my $DEEPNESS;
my $MENU;
my $START_POSITION;
my $CONTINUE=5;
my $OPTION;
#MAIN


do{
	printf("\033[2J");
	printf("\033[0;0H");
	printf "########################\n";
	printf " CONCEPT DRIFT ANALYZER \n";
	printf "########################\n";

	print "\nMenu options:\n";
	printf "1) Corpus preprocessing\n";
	printf "2) Topics extraction\n";
	printf "3) Topic sorting\n";
	printf "4) Concept drift detection\n";
	printf "5) Exit\n";
	printf "> ";
	while (!defined ($MENU = readline(STDIN)) or $MENU!~/[1-5]/){
		printf("[ERROR] - Invalid option: Choose from 1 to 5\n");
	}

	switch($MENU){
		case /1/ 
			{
				printf("\n1) Corpus prepocesing submenu\n");
				printf("   Insert corpus directory path\n");
				do{
					printf("> ");
					$DIRECTORY=readline(STDIN);
					chomp $DIRECTORY;
				}while(!defined($DIRECTORY) or length($DIRECTORY)<=1);
				system("perl 1_extract_eml_date.pl $DIRECTORY");
				printf("   Continue [y/n]?\n");
				do{
					printf("> ");
					$CONTINUE=readline(STDIN);
					chomp $CONTINUE;
				}while($CONTINUE!~/y|n|yes|no/i);
				printf("\033[2J");
				printf("\033[0;0H");
			}
		case /2/
			{
				printf("\n2) Topics extraction submenu\n");
				if (!-e preproc_file or -z preproc_file){
					printf("[ERROR] - Corpus has not been previously preprocessed\n          Execute option 1 from menu\n");
				}else{
					if(!-e raw_topics_file or -z raw_topics_file){
						printf("   Insert start position (default is 0)\n");
						printf("> ");
						$START_POSITION = readline(STDIN);
						chomp $START_POSITION;
						$START_POSITION = 0 if(!defined($START_POSITION) or !looks_like_number($START_POSITION));
						printf("   Insert WordNet deepness (default value is 3)\n");
						printf("> ");
						$DEEPNESS=readline(STDIN);
						chomp $DEEPNESS;
						if (looks_like_number($DEEPNESS)){
							system("perl 2_eml_to_concepts.pl -s $START_POSITION -w $DEEPNESS -i ".preproc_file);
						}else{ system("perl 2_eml_to_concepts.pl -i ".preproc_file); }
						if (!-e raw_topics_file or -z raw_topics_file){
							printf("   Error obtaining topics from e-mail corpus. Exiting...");
							die;
						}else { 
							system("perl 3_compress_csv.pl"); 
						}
					}elsif (-e raw_topics_file and !-z raw_topics_file){
						printf("   Topics have been previously extracted. Ignore task? [yY/nN]\n");
						do{
							printf("> ");
							$CONTINUE=readline(STDIN);
							chomp $CONTINUE;
						}while($CONTINUE!~/y|n|yes|no/i);
						if($CONTINUE=~/n|no/i){
							printf("   Insert start position (default is 0)\n");
							printf("> ");
							$START_POSITION = readline(STDIN);
							chomp $START_POSITION;
							$START_POSITION = 0 if(!defined($START_POSITION) or !looks_like_number($START_POSITION));
							printf("   Insert WordNet deepness (default value is 3)\n");
							printf("> ");
							$DEEPNESS=readline(STDIN);
							chomp $DEEPNESS;
							if (looks_like_number($DEEPNESS)){
								system("perl 2_eml_to_concepts.pl -s $START_POSITION -w $DEEPNESS -i ".preproc_file);
							}else{ system("perl 2_eml_to_concepts.pl -i ".preproc_file); }
						}
						if (!-e raw_topics_file or -z raw_topics_file){
							printf("   Error obtaining topics from e-mail corpus. Exiting");
							die;
						}else { system("perl 3_compress_csv.pl"); }
					}
				}
				printf("   Continue [y/n]?\n");
				do{
					printf("> ");
					$CONTINUE=readline(STDIN);
					chomp $CONTINUE;
				}while($CONTINUE!~/y|n|yes|no/i);
			}
		case /3/
			{
				printf("\n3) Topics sorting submenu\n");
				my $week = false;
				my $month = true;
				my $year = true;
				if(-e sorted_topics_file and !-z sorted_topics_file){
					printf("   Topics are already sorted. Do you really want to sort them again? [yY/nN]\n");
					do{
						printf("> ");
						$CONTINUE=readline(STDIN);
						chomp $CONTINUE;
					}while($CONTINUE!~/y|n|yes|no/i);
					if ($CONTINUE=~/y|yes/i){
						printf("   Insert sorting criteria. [w= week, m= month y= year] (default is month and year)\n");
						do{
							printf("> ");
							$CONTINUE=readline(STDIN);
							chomp $CONTINUE;
						}while($CONTINUE!~/w|m|y/i);
						system("rm ".sorted_topics_file);
						for ($CONTINUE){
							when (/wmy|wym|mwy|myw|ywm|ymw/) { system("perl 4_sort_and_join_concepts.pl -w -m -y"); }
							when (/my|ym/) { system("perl 4_sort_and_join_concepts.pl -m -y"); }
							when (/wy|yw/) { system("perl 4_sort_and_join_concepts.pl -w -y"); }
							when (/wm|mw/) { system("perl 4_sort_and_join_concepts.pl -w -m"); }
							when (/w/) { system("perl 4_sort_and_join_concepts.pl -w"); }
							when (/m/) { system("perl 4_sort_and_join_concepts.pl -m"); }
							when (/y/) { system("perl 4_sort_and_join_concepts.pl -y"); }
							default { system("perl 4_sort_and_join_concepts.pl -m -y"); }
						}
					}
				}elsif (!-e preproc_file or -z preproc_file){ 
					printf("   Corpus is not pre-processed. Select option 1 from menu\n");
				}
				elsif( (!-e raw_topics_file or -z raw_topics_file) and 
					   (!-e compress_topics_file or -z compress_topics_file)){
					printf("   Topics are not extracted from email corpus. Select option 2 from menu\n");
				}else{
					printf("   Insert sorting criteria. [w= week, m= month y= year] (default is month and year\n");
					do{
						printf("> ");
						$CONTINUE=readline(STDIN);
						chomp $CONTINUE;
					}while($CONTINUE!~/w|m|y/i);
					for ($CONTINUE){
						when (/wmy|wym|mwy|myw|ywm|ymw/) { system("perl 4_sort_and_join_concepts.pl -w -m -y"); }
						when (/my|ym/) { system("perl 4_sort_and_join_concepts.pl -m -y"); }
						when (/wy|yw/) { system("perl 4_sort_and_join_concepts.pl -w -y"); }
						when (/wm|mw/) { system("perl 4_sort_and_join_concepts.pl -w -m"); }
						when (/w/) { system("perl 4_sort_and_join_concepts.pl -w"); }
						when (/m/) { system("perl 4_sort_and_join_concepts.pl -m"); }
						when (/y/) { system("perl 4_sort_and_join_concepts.pl -y"); }
						default { system("perl 4_sort_and_join_concepts.pl -m -y"); }
					}
				}
				printf("   Continue [y/n]?\n");
				do{
					printf("> ");
					$CONTINUE=readline(STDIN);
					chomp $CONTINUE;
				}while($CONTINUE!~/y|n|yes|no/i);
			}
		case /4/
			{
				printf("\n4) Concept drift detection submenu\n");
				if (!-e preproc_file or -z preproc_file){
					printf("   Corpus is not pre-processed. Select option 1 from menu\n");
				}elsif ( (!-e raw_topics_file or -z raw_topics_file) and 
						 (!-e compress_topics_file or -z compress_topics_file) ){
					printf("   Topics are not extracted from email corpus. Select option 2 from menu\n");
				}elsif(!-e sorted_topics_file or -z sorted_topics_file){
					printf("   Topics are not sorted. Select option 3 from menu\n");
				}else{
					system("perl 5_automaton.pl");
				}
				printf("   Continue [y/n]?\n");
				do{
					printf("> ");
					$CONTINUE=readline(STDIN);
					chomp $CONTINUE;
				}while($CONTINUE!~/y|n|yes|no/i);
			}
	}
}while ($CONTINUE=~/y|yes/i);

printf "Ruano-Ordas, D., Mendez, J.R., Fdez-Riverola, F. (2016)\n";
printf "University of Vigo - SING Research Group\n";
	

