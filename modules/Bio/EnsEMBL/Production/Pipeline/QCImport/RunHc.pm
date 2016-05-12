=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

    RunHc - Run the hc fat jar on a given database and report failure

=head1 DESCRIPTION

    This process relies heavily on modules found in the VersioningService repository
    It gets the appropriate data from BulkFetcher, and serialises to RDF

=cut

package Bio::EnsEMBL::Production::Pipeline::QCImport::RunHc;

use strict;
use warnings;

use parent ('Bio::EnsEMBL::Production::Pipeline::Base');
use Bio::EnsEMBL::Registry;

sub fetch_input {
    my $self = shift;
    $self->param_required('fat_jar'); 
    $self->param_required('release');
    $self->param('hc_group');
    $self->param('hc_test');
    $self->param('base_path');
}


sub run {
    my $self = shift;
    my $fat_jar = $self->param('fat_jar');
    my $release = $self->param('release');
    my $hc_group = $self->param('hc_group'); 
    my $hc_test = $self->param('hc_test');
    my $base_path = $self->param('base_path'); 
    my $pdba = $self->get_DBAdaptor('production');
    my $dba = $self->get_DBAdaptor('core'); 
    if (defined $hc_group){
      system ('java -jar '.$fat_jar.'/healthchecks-jar-with-dependencies.jar \
      -h '.$dba->host().' -P '.$dba->port().' -u '.$dba->user().' -d '.$dba->database().' \
       --prod_user '.$pdba->user().' --prod_host '.$pdba->host().' --prod_port '.$pdba->port().' \
       -g '.$hc_group.' -o '.$base_path);
    } 
    elsif (defined $hc_test) {
      system ('java -jar '.$fat_jar.'/healthchecks-jar-with-dependencies.jar \
      -h '.$dba->host().' -P '.$dba->port().' -u '.$dba->user().' -d '.$dba->database().' \
      --prod_user '.$pdba->user().' --prod_host '.$pdba->host().' --prod_port '.$pdba->port().' \
      -t '.$hc_test.' -o '.$base_path);
    }
    else {
      $self->throw("You need a test or a group to run the hcs");
    }
}


sub write_output { 
}

1;

