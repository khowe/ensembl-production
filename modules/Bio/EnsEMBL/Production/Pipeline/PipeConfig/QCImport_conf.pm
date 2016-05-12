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

=cut

package Bio::EnsEMBL::Production::Pipeline::PipeConfig::QCImport_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');
use Bio::EnsEMBL::ApiVersion qw/software_version/;

sub default_options {
    my ($self) = @_;
    
    return {
      # inherit other stuff from the base class
      %{ $self->SUPER::default_options() }, 
      fat_jar => '/homes/maurel/work/ensj-healthcheck/target',
      pipeline_name => 'QC_import',
      hc_group => '',
      hc_test => '',
      exclude_tests => '',
      exclude_groups => '',
      base_path => '/nfs/nobackup/ensembl/'.$self->o('ENV', 'USER'),
      species => [],
      release => software_version(),
    };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
      # inheriting database and hive tables' creation
      @{$self->SUPER::pipeline_create_commands}, 
    ];
}

sub pipeline_analyses {
  my ($self) = @_;
  return [
     {
        -logic_name => 'ScheduleSpecies',
        -module     => 'Bio::EnsEMBL::Production::Pipeline::SpeciesFactory',
        -parameters => {
          species => $self->o('species'),
          randomize => 1,
        },
        -input_ids  => [ {} ],
        -flow_into  => {
          1 => 'RunHc',
        },
     },
       
    {
      -logic_name => 'RunHc',
      -module     => 'Bio::EnsEMBL::Production::Pipeline::QCImport::RunHc',
      -analysis_capacity => 10,
      -parameters => {
        fat_jar => $self->o('fat_jar'),
        hc_group => $self->o('hc_group'),
        hc_test  => $self->o('hc_test'),
        exclude_tests => $self->o('exclude_tests'),
        excluce_groups => $self->o('exclude_groups'),
        release => $self->o('release'),
        species => $self->o('species'),
      }
    },
  ];
}

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{ $self->SUPER::pipeline_wide_parameters() },
  };
}

# override the default method, to force an automatic loading of the registry in all workers
sub beekeeper_extra_cmdline_options {
    my $self = shift;
    return "-reg_conf ".$self->o("registry");
}

sub resource_classes {
  my $self = shift;
  return {
    %{$self->SUPER::resource_classes()},
    dump => { 'LSF' => '-q normal -M4000 -R"select[mem>4000] rusage[mem=4000]"'},
  }
}

1;
