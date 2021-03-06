#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use warnings;
use strict;

use Getopt::Long;
use Carp;
use Data::Dumper;
use DBI;
use Bio::EnsEMBL::Production::Utils::SchemaPatcher
  qw/list_patch_files find_missing_patches apply_patch/;
use Bio::EnsEMBL::ApiVersion qw/software_version/;
use Log::Log4perl qw/:easy/;

my $opts = {};
GetOptions( $opts,                 'host|dbhost=s',
            'port|dbport=s',       'user|dbuser=s',
            'pass|dbpass=s',       'database|dbname:s',
            'pattern|dbpattern:s', 'basedir=s',
            'verbose|v',           'version' );

if ( $opts->{verbose} ) {
  Log::Log4perl->easy_init($DEBUG);
}
else {
  Log::Log4perl->easy_init($INFO);
}

my $logger = get_logger;

if ( !defined $opts->{host} || !defined $opts->{basedir} ) {
  croak
"Usage: apply_patches.pl -host <host> -port <port> -user <user> -pass <pass> [-dbname <name>|-dbpattern <pattern>] -base_dir <ensembl dir>";
}

$opts->{version} ||= software_version;

$logger->debug("Patching databases to v$opts->{version}");

# find lists of patches for each repo
my $available_patches = {};
my $patch_dirs = {
        core          => "$opts->{basedir}/ensembl/sql",
        rnaseq        => "$opts->{basedir}/ensembl/sql",
        vega          => "$opts->{basedir}/ensembl/sql",
        cdna          => "$opts->{basedir}/ensembl/sql",
        otherfeatures => "$opts->{basedir}/ensembl/sql",
        variation     => "$opts->{basedir}/ensembl-variation/sql",
        funcgen       => "$opts->{basedir}/ensembl-funcgen/sql",
        compara       => "$opts->{basedir}/ensembl-compara/sql",
        ontology => "$opts->{basedir}/ensembl/misc-scripts/ontology/sql"
};
while ( my ( $type, $dir ) = each %$patch_dirs ) {
  $logger->info("Retrieving $type patches from $dir");
  $available_patches->{$type} = list_patch_files($dir);
}

# connect to database
$logger->info("Connecting to $opts->{host}");
my $dsn = "DBI:mysql:host=$opts->{host};port=$opts->{port}";
my $dbh = DBI->connect( $dsn, $opts->{user}, $opts->{pass} ) ||
  croak "Could not connect to $dsn: $!";

my $available_databases = [];
if ( !defined $opts->{pattern} ) {
  if ( defined $opts->{database} ) {
    $opts->{pattern} = $opts->{database};
  }
  else {
    $opts->{pattern} = '.*';
  }
}

my $sth = $dbh->prepare(q/show databases/);
$sth->execute();
while ( my $row = $sth->fetchrow_arrayref() ) {
  next unless defined $row;
  my $dbname = $row->[0];
  if ( $dbname =~ m/$opts->{pattern}/ &&
       $dbname ne 'test' &&
       $dbname ne 'mysql' &&
       $dbname ne 'performance_schema' &&
       $dbname ne 'information_schema' )
  {
    push @$available_databases, $dbname;
  }
}
$sth->finish();

my $patchN = 0;
my $dbN    = 0;
for my $database ( @{$available_databases} ) {
  $logger->debug("Considering $database");
  my $type = get_type($database);
  eval {
    if ( defined $type )
    {
      my $patches = $available_patches->{$type};
      if ( !defined $patches ) {
        $logger->warn("Cannot patch database $database of type $type");
      }
      else {
        $logger->debug("Checking patches for $type db $database");
        my $missing_patches =
          find_missing_patches( $dbh, $database, $patches,
                                $opts->{version} );
        if ( scalar(@$missing_patches) > 0 ) {
          $dbN++;
        }
        for my $missing_patch (@$missing_patches) {
          $patchN++;
          apply_patch( $dbh, $database, $missing_patch );
        }
      }
    }
  };
} ## end for my $database ( @{$available_databases...})
$logger->info(
             "Completed appying $patchN patch(es) to $dbN database(s)");

sub get_type {
  my ($dbname) = @_;
  my $type;
  if ( $dbname =~ m/ensembl_compara_.*/ ) {
    $type = 'compara';
  }
  elsif ( $dbname =~ m/.*_([a-z]+)_[0-9]+_[0-9]+(_[0-9]+)?/ ) {
    $type = $1;
  }
  return $type;
}
