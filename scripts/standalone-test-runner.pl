#!/software/bin/perl -w
# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


use strict;
use warnings;
use Pod::Usage;
use Getopt::Long qw( :config no_ignore_case );
use Log::Log4perl qw/:easy/;

sub args {
  my ($self) = @_;

  my $opts = {
  };

  my @cmd_opts = qw/
    database|d=s
    host|h=s
    port|P=i
    user|u=s
    pass|p=s
    prod_dbname|pdb=s
    prod_host|ph=s
    prod_port|pP=i
    prod_user|pu=s
    prod_pass|pp=s
    fat_jar|fj=s
    groups|g=s
    tests|t=s
    exclude_groups|G=s
    exclude_tests|T=s
    compara_db_name|cdn=s
    output|o=s
    verbose|v!
    help
    man
    /;
  GetOptions( $opts, @cmd_opts ) or pod2usage( -verbose => 1, -exitval => 1 );
  pod2usage( -verbose => 1, -exitval => 0 ) if $opts->{help};
  pod2usage( -verbose => 2, -exitval => 0 ) if $opts->{man};
  $self->{opts} = $opts;
  return;
}

sub check_opts {
  my ($self) = @_;
  my $o = $self->{opts};

  foreach my $required (qw/host database user host port prod_host prod_port prod_user fat_jar /) {
    my $msg = "Required parameter --${required} was not given";
    pod2usage( -msg => $msg, -verbose => 1, -exitval => 1 ) if !$o->{$required};
  }

  return;
}

sub run {
  my ($class) = @_;
  my $self = bless( {}, $class );
  $self->args();
  $self->check_opts();
  my $o = $self->{opts};
  Log::Log4perl->easy_init($INFO);
  my $logger = get_logger();
  
  my $java_cmd = qq/java -jar %s -h %s -d %s -P %d -u %s --prod_host %s --prod_port %d --prod_user %s/;
  my $cmd = sprintf($java_cmd,$o->{fat_jar}, $o->{host}, $o->{database}, $o->{port}, $o->{user},$o->{prod_host},$o->{prod_port},$o->{prod_user});
  $cmd .= qq/ -p $o->{pass}/ if defined $o->{pass};
  $cmd .= qq/ --prod_dbname $o->{prod_dbname}/ if defined $o->{prod_dbname};
  $cmd .= qq/ --prod_pass $o->{prod_pass}/ if defined $o->{prod_pass};
  $cmd .= qq/ --compara_dbname $o->{compara_db_name}/ if defined $o->{compara_db_name};
  $cmd .= qq/ -g $o->{groups}/ if defined $o->{groups};
  $cmd .= qq/ -t $o->{tests}/ if defined $o->{tests};
  $cmd .= qq/ -G $o->{exclude_groups}/ if defined $o->{exclude_groups};
  $cmd .= qq/ -T $o->{exclude_tests}/ if defined $o->{exclude_tests};
  $cmd .= qq/ -o $o->{output}/ if defined $o->{output};
  $cmd .= qq/ -v $o->{verbose}/ if defined $o->{verbose};
  # If verbose is defined, run the pipeline in verbose mode
  # Else don't print anything
  defined $o->{verbose} ? system ($cmd) : system ($cmd.'>/dev/null 2>&1');
  # Check the /healthchecks-jar-with-dependencies.jar exit code. If the exit code is sup to 0, then print issue. 
  # Else if the exit code is 0 all fine, the database has passed the viral hcs
  $? >> 0 ? print qq/\nIMPORTANT: There is an issue with your database, please check $o->{output} for more detail or re-run script with -verbose\n/ : print qq/\nDatabase passed vital healthchecks\n/;
  return;
}

__PACKAGE__->run();

__END__

=pod 

=head1 NAME

base_standalone-test-runner.pl

=head1 SYNOPSIS

       perl scripts/standalone-test-runner.pl -fat_jar /homes/maurel/work/ensj-healthcheck/target/healthchecks-jar-with-dependencies.jar \\
         -host mysql-eg-staging-1.ebi.ac.uk  -port 4160 -user ensro \\
         -database saccharomyces_cerevisiae_core_31_84_4 -prod_user ensro \\
         -prod_host mysql-eg-pan-prod.ebi.ac.uk -prod_port 4276 \\
         -tests SchemaPatchesApplied -output /nfs/nobackup/ensembl/maurel/failure.txt

=head1 DESCRIPTION

The following script is a perl wrapper around the Java standalone test runner (Standalone test runner). 
If a database sucessfully passed the vital hcs, the script will print a message. 
If the database contains critical issue, the script will print the location of the failure.txt file containing more details.

=over 8

=back

=head1 OPTIONS

=over 8

=item B<-fj|--fat_jar>

Location of the fat jar standalone hc java runner

=item B<-o|--output>

Name of file to write failure details to (default: failure.txt)

=item B<-G|--exclude_groups>

Specify which groups of tests should not be run. Fully qualified class names can be used as well as their short names.

=item B<-T|--exclude_tests>

Specify which tests should not be run. Fully qualified class names can be used as well as their short names.

=item B<-g|--groups>

Specify which groups of tests should be run. Fully qualified class names can be used as well as their short names.

=item B<-t|--tests>

Specify which tests should be run. Fully qualified class names can be used as well as their short names.

=item B<-d|--database>

Database to test
 
=item B<-u|--user>

Username for test database
 
=item B<-p|--pass>

Password for test database

=item B<-h|--host>

Host for test database
 
=item B<-P|--port>

Port for test database

=item B<-pdb|--prod_dbname>

Name of production database (default: ensembl_production)

=item B<-ph|--prod_host>

Production/compara master database host

=item B<-pp|--prod_pass>

Production/compara master database password

=item B<-pP|--prod_port>

Production/compara master database port

=item B<-pu|--prod_user>

Production/compara master database user

=item B<-cdb|--compara_dbname>

Name of compara master database (default: ensembl_compara_master)

=item B<--verbose>

Make the script chatty

=item B<--help>

Help message

=item B<--man>

Man page

=back

=cut

