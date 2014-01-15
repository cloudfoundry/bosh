require 'spec_helper'
require 'bosh/stemcell/definition'

module Bosh::Stemcell
  describe Definition do
    subject { Bosh::Stemcell::Definition.new(infrastructure, operating_system, agent) }

    let(:infrastructure) do
      instance_double(
        'Bosh::Stemcell::Infrastructure::Base',
        name: 'infrastructure-name',
        light?: false,
      )
    end

    let(:operating_system) do
      instance_double(
        'Bosh::Stemcell::OperatingSystem::Base',
        name: 'operating-system-name',
      )
    end

    let(:agent) do
      instance_double(
        'Bosh::Stemcell::Agent::Go'
      )
    end

    describe '.for' do
      it 'sets the infrastructure, operating system, and agent' do
        Bosh::Stemcell::Infrastructure
          .should_receive(:for)
          .with('infrastructure-name')
          .and_return(infrastructure)

        Bosh::Stemcell::OperatingSystem
          .should_receive(:for)
          .with('operating-system-name')
          .and_return(operating_system)

        Bosh::Stemcell::Agent
          .should_receive(:for)
          .with('agent-name')
          .and_return(agent)

        definition = instance_double('Bosh::Stemcell::Definition')
        Bosh::Stemcell::Definition
          .should_receive(:new)
          .with(infrastructure, operating_system, agent)
          .and_return(definition)

        Bosh::Stemcell::Definition.for('infrastructure-name', 'operating-system-name', 'agent-name')
      end
    end

    describe '#initialize' do
      its(:infrastructure)             { should == infrastructure }
      its(:operating_system)           { should == operating_system }
      its(:agent)                      { should == agent }
    end
  end
end
