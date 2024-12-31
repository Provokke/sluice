package Sluice;

use strict;
use warnings;

our $VERSION = '0.1.0';

my $LINE = qr{
    ^(\S+)\s+\S+\s+(\S+)\s+
    \[([^\]]+)\]\s+
    "(\S+)\s+(\S+)(?:\s+(\S+))?"\s+
    (\d{3})\s+(\d+|-)
    (?:\s+"([^"]*)"\s+"([^"]*)")?
}x;

my @FIELDS = qw(status path host method hour);

sub parse_line {
    my ($line) = @_;
    return unless defined $line && $line =~ $LINE;
    my %rec = (
        host     => $1,
        user     => $2,
        time     => $3,
        method   => $4,
        path     => $5,
        protocol => $6 // '',
        status   => $7 + 0,
        bytes    => $8 eq '-' ? 0 : $8 + 0,
        referrer => $9 // '',
        agent    => $10 // '',
    );
    return \%rec;
}

sub make_filter {
    my (%want) = @_;
    my $path = defined $want{path} ? qr/$want{path}/ : undef;
    return sub {
        my ($rec) = @_;
        return 0 if defined $want{status} && $rec->{status} != $want{status};
        return 0 if defined $want{class} && int($rec->{status} / 100) != $want{class};
        return 0 if defined $want{method} && uc $want{method} ne $rec->{method};
        return 0 if defined $want{host} && $want{host} ne $rec->{host};
        return 0 if $path && $rec->{path} !~ $path;
        return 1;
    };
}

sub new {
    my ($class, %opts) = @_;
    my $self = bless {
        filter    => $opts{filter},
        total     => 0,
        bytes     => 0,
        malformed => 0,
        map { $_ => {} } @FIELDS,
    }, $class;
    return $self;
}

sub add_line {
    my ($self, $line) = @_;
    my $rec = parse_line($line);
    unless ($rec) {
        $self->{malformed}++;
        return 0;
    }
    return 0 if $self->{filter} && !$self->{filter}->($rec);
    $self->{total}++;
    $self->{bytes} += $rec->{bytes};
    $self->{status}{ $rec->{status} }++;
    $self->{path}{ $rec->{path} }++;
    $self->{host}{ $rec->{host} }++;
    $self->{method}{ $rec->{method} }++;
    my ($hour) = $rec->{time} =~ /:(\d{2}):\d{2}:\d{2}/;
    $self->{hour}{$hour}++ if defined $hour;
    return 1;
}

sub add_handle {
    my ($self, $fh) = @_;
    while (my $line = <$fh>) {
        $line =~ s/\r?\n\z//;
        next unless length $line;
        $self->add_line($line);
    }
    return $self;
}

sub total     { $_[0]{total} }
sub bytes     { $_[0]{bytes} }
sub malformed { $_[0]{malformed} }

sub top {
    my ($self, $field, $n) = @_;
    die "unknown field: $field\n" unless grep { $_ eq $field } @FIELDS;
    my $h    = $self->{$field};
    my @keys = sort { $h->{$b} <=> $h->{$a} || $a cmp $b } keys %$h;
    $n = @keys if !defined $n || $n > @keys;
    return map { [ $_, $h->{$_} ] } @keys[ 0 .. $n - 1 ];
}

sub classes {
    my ($self) = @_;
    my %out;
    $out{ int($_ / 100) . 'xx' } += $self->{status}{$_} for keys %{ $self->{status} };
    return \%out;
}

sub error_rate {
    my ($self) = @_;
    return 0 unless $self->{total};
    my $errors = 0;
    $errors += $self->{status}{$_} for grep { $_ >= 500 } keys %{ $self->{status} };
    return $errors / $self->{total};
}

sub human_bytes {
    my ($n) = @_;
    my @units = qw(B KB MB GB TB);
    my $i = 0;
    while ($n >= 1024 && $i < $#units) {
        $n /= 1024;
        $i++;
    }
    return $i ? sprintf('%.1f %s', $n, $units[$i]) : sprintf('%d B', $n);
}

sub summary {
    my ($self, $n) = @_;
    $n //= 10;
    return {
        total      => $self->{total},
        bytes      => $self->{bytes},
        malformed  => $self->{malformed},
        error_rate => $self->error_rate,
        classes    => $self->classes,
        map { $_ => [ map { { key => $_->[0], count => $_->[1] } } $self->top($_, $n) ] } @FIELDS,
    };
}

sub report {
    my ($self, $n) = @_;
    $n //= 10;
    my @out = (
        sprintf('requests   %d', $self->{total}),
        sprintf('transfer   %s', human_bytes($self->{bytes})),
        sprintf('malformed  %d', $self->{malformed}),
        sprintf('5xx rate   %.2f%%', $self->error_rate * 100),
    );
    for my $field (@FIELDS) {
        my @rows = $field eq 'hour'
            ? sort { $a->[0] cmp $b->[0] } $self->top($field)
            : $self->top($field, $n);
        next unless @rows;
        push @out, '', $field;
        push @out, sprintf('  %8d  %s', $_->[1], $_->[0]) for @rows;
    }
    return join("\n", @out) . "\n";
}

1;

