require 'spec_helper'
require 'bosh/dev/stemcell_rake_methods'
require 'bosh/dev/stemcell_builder_options'
require 'bosh/dev/stemcell_environment'

module Bosh::Dev
  describe StemcellRakeMethods do
    let(:stemcell_builder_command) do
      instance_double('Bosh::Dev::BuildFromSpec', build: nil)
    end

    let(:stemcell_builder_options) do
      instance_double('Bosh::Dev::StemcellBuilderOptions')
    end

    let(:stemcell_environment) do
      instance_double('Bosh::Dev::StemcellEnvironment')
    end

    subject(:stemcell_rake_methods) do
      StemcellRakeMethods.new(stemcell_environment: stemcell_environment,
                              stemcell_builder_options: stemcell_builder_options)
    end

    describe '#build_stemcell' do
      before do
        Bosh::Dev::StemcellBuilderCommand.stub(:new).with(stemcell_environment,
                                                          stemcell_builder_options).and_return(stemcell_builder_command)
      end

      it 'builds a basic stemcell with the appropriate name and options' do
        stemcell_builder_command.should_receive(:build)

        stemcell_rake_methods.build_stemcell
      end
    end
  end
end
