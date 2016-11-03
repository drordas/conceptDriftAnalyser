#!/usr/bin/perl -w

use Data::Dumper;
use DateTime::Format::Mail;
use File::Find::Rule;
use Time::Piece;
use Email::MIME;
use MIME::Parser;
use File::Slurp;
use Math::Round;
use POSIX qw/floor/;
use Lingua::StopWords qw( getStopWords );
use strict;
use warnings;
use HTML::Restrict;
use Email::Simple;
use constant false => 0;
use constant true => 1;
use Class::CSV;
use Time::Elapse;
use DateTime;

my $date_parser = DateTime::Format::Mail->new( loose => 1 );
my $stopwords = getStopWords('en');

if ( !defined $ARGV[0] ){
	printf "Corpus path is not set\n" ;
	exit;
}

my @all_folders = File::Find::Rule->directory->in($ARGV[0]);

$/ = undef;


#my $startTime = time; #gettimeofday();
my $start_time = DateTime->now();

#Time::Elapse->lapse(my $now);


$/ = undef;

open my $file_names, "<parsed_names.csv";
my $english_names = <$file_names> if ($file_names);
close $file_names;
$english_names =~ s/(,\s*)/|/g if (defined $english_names);

my %sortedHash = ();
my $HTMLParser = HTML::Restrict->new();
my $errorMails = 0;
my $surnames = "(?:allen|carson|donoho|griffith|hyatt|lewis|mckay|pimenov|sager|shively|swerzbin|whitt|arnold|cash|dorland|grigsby|hyvl|linder|mclaughlin|platter|";
$surnames.="arora|causholli|ermis|guzman|jones|lokay|merriss|presto|salisbury|slinger|taylor|williams|badeer|corman|farmer|haedicke|kaminski|lokey|meyers|quenet|";
$surnames.="sanchez|smith|tholt|wolfe|bailey|crandell|fischer|hain|kean|love|thurston|quigley|sanders|solberg|thomas|ybarbo|bass|cuilla|forney|harris|keavey|lucci|";
$surnames.="motley|rapp|scholtes|south|townsend|zipper|baughman|dasovich|fossum|hayslett|keiser|maggi|neal|reitmeyer|schoolcraft|staab|tycholiz|zufferli|beck|davis-d|";
$surnames.="gang|heard|king|mann|nemec|richey|schwieger|stclair|ward|benson|dean|gay|hendrickson|kitchen|martin|panus|ring|scott|steffes|watson|blair|delainey|";
$surnames.="hernandez|kuykendall|parks|ring|semperger|stepenovitch|weldon|brawner|derrick|germany|hodge|lavorato|mccarty|pereira|rodrique|shackleton|stokley|whalley|";
$surnames.="dickson|gilbertsmith|holst|mcconnell|perlingiere|rogers|shankman|storey|whalley|campbell|donohoe|giron|horton|lenhart|mckay|phanis|ruscitti|";
$surnames.="white|saibi|skilling|symes|williams|geaccone|shapiro|sturm|will)";

my $numFolder= 1;
my %hashEmls;
my $countEmls = 0;
######### MAIN PROGRAM #############

print "   ===========================================\n";
print "       1) CORPUS PREPOCESSING     \n";
print "   ===========================================\n";

foreach my $folder (@all_folders){
#foreach (@valid_subfolders){
	#print $numFolder."/".scalar(@all_folders)."\n";
	foreach my $filename (File::Find::Rule->file->in($folder)){
		open my $fh,"<", $filename or die 'Cannot open file';
		my $raw_eml = <$fh>;
		close ($fh);
		
		$filename =~ /.*(\d{4})\/(\d{2})/;
		my $monthyear = "$2\/$1" if ($filename =~ /.*(\d{4})\/(\d{2})/);
		my $yearmonth = "$1\/$2" if ($filename =~ /.*(\d{4})\/(\d{2})/);
		my $email = Email::Simple->new($raw_eml);
		my $localdate = localtime->strftime("%Y/%m");
		
		if ( (($localdate cmp $yearmonth) >= 0) ){
			if (exists($hashEmls{$monthyear})){
				push @{$hashEmls{$monthyear}},  $filename;	
			}else{ $hashEmls{$monthyear} = [$filename]; }
			$countEmls+=1;
		}else {
			print "\t[ERROR] - Email Date is inconsistent\n";
			$errorMails+=1;
		}
	}
	$numFolder+=1;
}

my $numDifWords = scalar(keys %hashEmls);
my $elapsed = $start_time->subtract_datetime(DateTime->now());

print "   ===========================================\n";
print "      FINISH - SUMMARY    \n";
print "   ===========================================\n";
print "    => Total emails: ".$countEmls."\n";
print "    => Num. folders: ".scalar(@all_folders)."\n";
print "    => Elapsed time: ".$elapsed->days."d ".$elapsed->hours."h ".$elapsed->minutes."m ".$elapsed->seconds."s\n";
my @sortedHash;

foreach my $datetime (sort {Time::Piece->strptime($a, '%m/%Y') <=> Time::Piece->strptime($b, '%m/%Y')} keys %hashEmls) {
	push @sortedHash, [ $datetime, [ @{$hashEmls{$datetime}} ]];
}

my $csv = Class::CSV->new (fields => [qw/id date path/]);
my $id = 0;
$csv->add_line({ id => "id", date => "eml_date", path => "eml_path" } );

foreach my $ref (@sortedHash){
	my @array = (@$ref);
	my $size = scalar(@{$array[1]});
	for my $i (0 .. $size-1){
		my $userName = "";
		$csv->add_line({ 
						id => $id,
						date => $array[0], 
						path => $array[1][$i] 
					   } );
		$id++;
	}
}
write_file('1_sorted_eml_by_date.csv',$csv->string());

print "   ===========================================\n";
