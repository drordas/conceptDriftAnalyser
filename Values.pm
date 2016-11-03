package Values;

## PACKAGES DECLARATION


sub new{
	my $class = shift;
	my $self = {
		_X => shift // 0,
		_H => shift // 0,
		_F => shift // 0,
		_U => shift // 0,
		_D => shift // 0,
		_C => shift // 0,
	};
	return bless $self, $class;
}

###################### GETTERS #####################

sub getX{
	my $self = shift;
	return $self->{_X};
}

sub getH{
	my $self = shift;
	return $self->{_H};
}

sub getF{
	my $self = shift;
	return $self->{_F};
}

sub getU{
	my $self = shift;
	return $self->{_U};
}

sub getD{
	my $self = shift;
	return $self->{_D};
}

sub getC{
	my $self = shift;
	return $self->{_C};
}

####################################################

###################### SETTERS #####################

sub setX{
	my ($self, $X) =@_;
	$self->{_X} = $X if defined ($X);
	#return $self->{_X};
}

sub setH{
	my ($self, $H) = @_;
	$self->{_H} = $X if defined ($H);
	#return $self->{_H};
}

sub setF{
	my ($self, $F) = @_;
	$self->{_F} = $F if defined ($F);
	#return $self->{_F};
}

sub setU{
	my ($self, $U) = @_;
	$self->{_U} = $X if defined ($U);
	#return $self->{_U};
}

sub setD{
	my ($self, $D) = @_;
	$self->{_D} = $D if defined ($D);
	#return $self->{_D};
}

sub setC{
	my ($self, $C) = @_;
	$self->{_C} = $C if defined ($C);
	#return $self->{_C};
}

sub setAll{
	my ($self, $X, $H, $F, $U, $C) = @_;
	$self->{_X} = $X if defined ($X);
	$self->{_H} = $H if defined ($H);
	$self->{_F} = $F if defined ($F);
	$self->{_U} = $U if defined ($U);
	$self->{_C} = $C if defined ($C);
	#return $self;
}

1;
####################################################

###################### SETTERS #####################
sub printClass{
	my $self = shift;
	print "X: ".$self->{_X}."\n";
	print "H: ".$self->{_H}."\n";
	print "F: ".$self->{_F}."\n";
	print "U: ".$self->{_U}."\n";
	print "D: ".$self->{_D}."\n";
	print "C: ".$self->{_C}."\n";
}
