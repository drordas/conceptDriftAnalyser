#!/usr/bin/perl -w

#Packages Declarations
use WordNet::QueryData;
use WordNet::Similarity;
use Data::Dumper;
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
use Text::CSV;
use Sys::Info;
use Sys::Info::Constants qw( :device_cpu );
use DateTime::Format::Mail;
use Getopt::Long qw(GetOptions);
use File::ReadBackwards;
use Scalar::Util qw(looks_like_number);
Getopt::Long::Configure qw(gnu_getopt);
#########################################

#Constant declarations
use constant false => 0;
use constant true => 1;
use constant fnames => "parsed_names.csv";
use constant feml_sorted_by_date => "1_sorted_eml_by_date.csv";
use constant fextracted_concepts => "2_extracted_concepts.csv";
use constant default_deepness => 3;
use constant default_thread_size => 1;
use constant initial_position => 0;
#########################################

#Main variables declaration
my $deepness = default_deepness;
my $start = initial_position;
my $info = Sys::Info->new;
my $cpu  = $info->device( 'CPU' );
my $stopwords = getStopWords('en');
my $wn = WordNet::QueryData->new(noload => 1);
my $thread_size = default_thread_size;
my $localdate = localtime->strftime("%Y/%m");
my $date_parser = DateTime::Format::Mail->new( loose => 1 );
my $manualStart = false;
my $inputFile = feml_sorted_by_date;
my $outputFile = fextracted_concepts;
#########################################

GetOptions(
	'input|i=s' => \$inputFile,
	'output|o=s' => \$outputFile,
	'wndeep|w=s' => \$deepness,
	'start|s=s' => \$manualStart) or die "Usage: $0 --wndeep|w VALUE --start|s VALUE\n";

#Main data types declaration
my %undefWords;
my %hashemails;
my %cache;
my @sortedHash;
my @WNTree=getSublevels($deepness);

#########################################

my $csvEMLStartTime = DateTime->now();#time;

print "   ==========================================================\n";
print "       2.1) E-MAIL TOPIC EXTRACTION    \n";
print "   ==========================================================\n";
print "    Deepness level set to $deepness\n";
print "    Reading CSV file...\n";

my @csvLines = readEMLfromCSV($inputFile);

die printf("    Cannot open csv file\n") if (!@csvLines);

my $csvEMLEndTime = DateTime->now();#time;

my $csvNamesStartTime = DateTime->now(); #time;

my @english_names = readNamesfromCSV(fnames);

my $csvNamesEndTime = DateTime->now(); #time;

die printf("    Cannot read english proper names file\n") if(!@english_names);

my $elapsed_eml = $csvEMLEndTime - $csvEMLStartTime;
my $elapsed_names = $csvNamesEndTime - $csvNamesStartTime;

my $numEml = 0;
my $HTMLParser = HTML::Restrict->new();
my $errorParsed = 0;
my $correctParsed = 0;
my $totalConcepts = 0;
my $weekdays = "Mon|Tue|Wed|Thu|Sat|Sun|Monday|Tuesday|Thursday|Saturday|Sunday";
my $months = "Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|January|February|March|April|May|June|July|August|September|October|November|December";
my $surnames = "(?:allen|carson|donoho|griffith|hyatt|lewis|mckay|pimenov|sager|shively|swerzbin|whitt|arnold|cash|dorland|grigsby|hyvl|linder|mclaughlin|platter|";
$surnames.="arora|causholli|ermis|guzman|jones|lokay|merriss|presto|salisbury|slinger|taylor|williams|badeer|corman|farmer|haedicke|kaminski|lokey|meyers|quenet|";
$surnames.="sanchez|smith|tholt|wolfe|bailey|crandell|fischer|hain|kean|love|thurston|quigley|sanders|solberg|thomas|ybarbo|bass|cuilla|forney|harris|keavey|lucci|";
$surnames.="motley|rapp|scholtes|south|townsend|zipper|baughman|dasovich|fossum|hayslett|keiser|maggi|neal|reitmeyer|schoolcraft|staab|tycholiz|zufferli|beck|davis-d|";
$surnames.="gang|heard|king|mann|nemec|richey|schwieger|stclair|ward|benson|dean|gay|hendrickson|kitchen|martin|panus|ring|scott|steffes|watson|blair|delainey|";
$surnames.="hernandez|kuykendall|parks|ring|semperger|stepenovitch|weldon|brawner|derrick|germany|hodge|lavorato|mccarty|pereira|rodrique|shackleton|stokley|whalley|";
$surnames.="dickson|gilbertsmith|holst|mcconnell|perlingiere|rogers|shankman|storey|whalley|campbell|donohoe|giron|horton|lenhart|mckay|phanis|ruscitti|";
$surnames.="white|saibi|skilling|symes|williams|geaccone|shapiro|sturm|will)";

my $others= "http|ftp|https|image|email|mail|html|Subject|From";

######### MAIN PROGRAM #############

my $start_time = DateTime->now();

if ( ($manualStart == 0) or ($manualStart >= scalar(@csvLines)) ){
	if (!-e $outputFile or -z $outputFile){
		$start = 0;
		open (my $fh, '>', fextracted_concepts) or die printf("    Cannot open output file\n");
		print $fh "email_id,Y/M,Concepts\n";
		close $fh;
	}else{
		my @last = split /,/, File::ReadBackwards->new($outputFile)->readline;
		$start = ($last[0]+1) if (looks_like_number($last[0]));
	}
	
	if ($start == 0){
		print "    No previous computations done.\n    Starting with email_id = ".${$csvLines[$start]}[0]."\n\n";
	}else{
		print "    Computations made until email_id = ".${$csvLines[$start-1]}[0].".\n\t      Continuing with email_id = ".${$csvLines[$start]}[0]."\n\n";
	}
}else { 
	$start=$manualStart;
	printf("1-ENTRO AQUI!!!!"); 
	if (!-e $outputFile or -z $outputFile){
		printf("1.1-ENTRO AQUI!!!!"); 
		open (my $fh, '>', fextracted_concepts) or die printf("    Cannot open output file\n");
		print $fh "email_id,Y/M,Concepts\n";
		close $fh;
	}
	printf("2-ENTRO AQUI!!!!"); 
	printf("    Manual Start Activaded: Starting from position: $start\n");
}

$/ = undef;

for my $actualEmail ($start .. (scalar(@csvLines)-1) ){
	my @ref = @{$csvLines[$actualEmail]};

	printf ("    Computing Email: ".$actualEmail."/".scalar(@csvLines)." [email_id = ".$ref[0]."]");
	my $email_id = $ref[0];
	my $email_date = $ref[1];
	my $email_path = $ref[2];
		
	#print "[MAIN][INFO]->[1] - Reading filename\n";
	open my $fh,"<", $email_path or die "Unable to open file: $email_path";
	my $raw_eml = <$fh>;
	close($fh);	

	#print "[MAIN][INFO]->[2] - Parsing email\n";
	my $email = Email::Simple->new($raw_eml);	
	
	if ( defined($email->header("Content-Type")) and ($email->header("Content-Type") =~ /text\/plain/i) )
	{
		my $body = $email->body; 
		my $removed_HTMLTags = undef;
		
		if (defined ($removed_HTMLTags = $HTMLParser->process($email->body)) and (my @body_words = $removed_HTMLTags =~ /(\w+(?:'\w+)*)/g) )
		{
			my %hashwords = ();
			foreach my $actualWord (@body_words){
				$actualWord =~ s/^[_-]{2,}|[_-]{2,}$|[_-]{2,}(?=[_-])//g;
				$actualWord =~ s/(.+)'s/$1/g;
				$actualWord = lc($actualWord);
				if ( defined ($actualWord) and (length $actualWord > 3)  
					 and !($actualWord =~/\d+|\s+/) and !$stopwords->{$actualWord}
					 and !($actualWord =~/((ftp|http|https):\/\/)?(w{3}\.)?([^\s]+)+(\.\w+)(\/\w+)*\/?/i)
					 and !($actualWord =~/$weekdays|$months|$surnames|$others/i)
					 and !(grep {/$actualWord/} @english_names) )
				{
					if (!(exists($undefWords{$actualWord}))){
						if ( defined((my $noun=getNoun($actualWord))) ){
							$hashwords{$noun}=1;
						}else {$undefWords{$actualWord}=1;}
					}
				}
			}
			#print "[MAIN][INFO]->[3] - Generating Concepts\n";
			my @word2Concepts = computeConceptsAtLevel(\%hashwords,\@WNTree,\%cache,$deepness);
			conceptToCSV($email_id,$email_date,@word2Concepts);
			$totalConcepts += scalar(@word2Concepts);
			$correctParsed++;
			printf (".... done!!\n");
							
		}else { 
			printf (".... error: incorrect e-mail structure\n");
			$errorParsed++;
		}
	}else{  printf (".... error: incorrect e-mail header\n");
			$errorParsed++;
	}
	
	$actualEmail++;
}

my $elapsed = $start_time->subtract_datetime(DateTime->now());

printf("   ==========================================================\n");
printf("      FINISH - SUMMARY    \n");
printf("   ==========================================================\n");
printf("    => Right e-mails: ".$correctParsed." (".($correctParsed*100)/($correctParsed+$errorParsed)."%%)\n");
printf("    => Erroneus e-mails: ".$errorParsed." (".($errorParsed*100)/($correctParsed+$errorParsed)."%%)\n");
printf("    => Total e-mails: ".($correctParsed+$errorParsed)."\n");
printf("    => Total extracted topics: ".($totalConcepts)."\n");
printf("    => Average topics (per e-mail): ".($totalConcepts/($correctParsed+$errorParsed))."\n");
printf("    => Elapsed time: ".$elapsed->days."d ".$elapsed->hours."h ".$elapsed->minutes."m ".$elapsed->seconds."s\n");
printf("   ==========================================================\n");

######### END MAIN PROGRAM #############

sub readEMLfromCSV{
	my $path = shift;
	my @csvLines;
	
	open (my $data, $path) or return undef;
	my $line = <$data>; #avoid the first line. Is the column description.

	while($line = <$data>){
		chomp $line;
		my @fields = undef;
		
		if ( (@fields = split (",", $line)) ){
			push @csvLines, [ $fields[0], $fields[1], $fields[2] ];
		}#else{ print "[ERROR][TEXT::CSV] -> Cannot parse line: $line\n";}
	}
	close $data;
	
	return @csvLines;
}

sub readNamesfromCSV{
	my $path = shift;
	my @names;
	
	open (my $data, $path) or return undef;
	
	while (my $line = <$data>){
		chomp $line;
		push @names, split (",", $line);
	}
	
	close $data;
	
	return @names;
}

sub readEMLContent{
	my $path = shift;
	my $content;
	
	open (my $data, $path) or return undef;
	close ($data)
}

sub computeConceptsAtLevel{
	my $hashRef = shift;
	my $wordnetRef = shift;
	my $cacheRef = shift;
	my $deepLevel = shift;
	
	my %emailWords = %{$hashRef};
	my %conceptsMap;
	my @conceptsArray = @{$wordnetRef};
	my @toret;
	
	foreach my $concept (@{$conceptsArray[$deepLevel]}){
		my $key = $concept;
		$key = $1 if ($concept =~ /^(\w+)#n.*/i);
		foreach my $word (keys %emailWords) {
			if (wordHasConcept($cacheRef,$word,$concept,$deepLevel)){
				$conceptsMap{$key}=1;
			}else{
				if (defined($word) and belongsTo($word,$concept)){
					$conceptsMap{$key}=1;
					push @{$cacheRef->{$word}{$deepLevel}}, $concept;
				}
			}
		}
	}
	
	return (@toret = keys %conceptsMap);
}

sub computeConceptsUntilLevel{

	my $hashRef = shift;
	my $wordnetRef = shift;
	my $cacheRef = shift;
	my $deepLevel = shift;
	
	my %emailWords = %{$hashRef};
	my @conceptsArray = @{$wordnetRef};
	
	my @toret;

	for my $i (0 .. $deepLevel-1){
		my %conceptsMap;
		foreach my $concept (@{$conceptsArray[$i]}){
			my $key = $concept;
			$key = $1 if ($concept =~ /^(\w+)#n.*/i);
			foreach my $word (keys %emailWords) {
				if (wordHasConcept($cacheRef,$word,$concept,$i)){
					push @{$conceptsMap{$key}}, $word unless ( grep {$_ eq $word} @{$conceptsMap{$key}});
				}else{
					if (defined($word) and belongsTo($word,$concept)){
						push @{$conceptsMap{$key}}, $word unless ( grep {$_ eq $word} @{$conceptsMap{$key}});
						push @{$cacheRef->{$word}{$i}}, $concept;
					}
				}
			}
		}
		push @toret, \%conceptsMap;
	}
	return @toret;
}

sub wordHasConcept{
	my $hashRef = shift;
	my $word = shift;
	my $concept = shift;
	my $level = shift;
	my %cacheWords = %{$hashRef};
	
	return false if ( !exists ($cacheWords{$word}{$level}) or !defined($word) or 
	                  !defined($concept) or !defined($level));
	foreach my $cont (@{$cacheWords{$word}{$level}}){
		return true if ($cont eq $concept);
	}
	return false;
}

sub isInWordNet{
	my $word = shift;
	
	if ( defined($word) and (scalar($wn->queryWord($word)) > 0) ){
		return true; 
	}else {return false;}
}

sub getNoun{
	my $word = shift;

	if ( defined($word) ){
		my @result = $wn->queryWord($word,"also");
		
		return undef if (scalar(@result) == 0);
		
		foreach my $aux (@result){ 
			return $1 if ($aux =~ /^(\w+)#n.*/i);
		} 
	}
	return undef;
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

sub getWordnetConceptsAt{
	my $wordnetRef = shift;
	my $level = shift;
	
	my @levelArray = @{$wordnetRef};
	
	if( $level < (scalar(@levelArray)) ){
		return @{$levelArray[($level-1)]};
	}return undef;
}

sub getUpperLevel{
	my @terms = @_;
	my @toret = ();
	my %seen = ();
	my @unique = ();

	foreach my $term (@terms){	
		my @newTerms = $wn->querySense($term,"hype");
		push @toret, @newTerms;
	}
	return (keys %{{ map{$_=>1} @toret}});
}

sub belongsTo{
	my ($term, $hyper) = @_;
	my $flag = false;
	my $comp2 = $hyper;
	my $comp1 = $term;
		
	return false if (!defined($term) or !defined($hyper) or !isInWordNet($term));
	
	return true if ( $hyper =~ /entity#n#1/i );
	
	if ($term =~ /(\w+)#\w#\d/i ){
		$comp1 = $1;
	}else { $term.="#n#1"; }
	
	$comp2 = $1 if ( $hyper =~ /(\w+)#\w#\d/i );
	
	return true if ($comp1 eq $comp2);
	
	my @result = $wn->querySense($term,"hype"); 

	while ( !(grep {/entity#n#1/i} @result) and (scalar(@result)>0) ) {
		foreach my $res (@result) {
			$comp1 = $res;
			$comp1 = $1 if ( $res =~ /(\w+)#\w#\d/i );
			return true if ($comp1 eq $comp2);
		}
		@result = getUpperLevel(@result);
	}
	return false;
}

sub conceptToCSV{
	
	my ($id, $date, @AoC) = @_;
	my $size = scalar(@AoC);
	
	open (FH, '>>', fextracted_concepts) or die print "    Cannot open output file\n";
	
	if ($size == 0){
		print FH $id.",".$date.",\n";
	}else{
		print FH $id.",".$date.",";
		for my $i ( 0 .. ($size-2) ){
			print FH $AoC[$i]." ";
		}
		print FH $AoC[($size-1)]."\n";
	}
	
	close FH;
}
