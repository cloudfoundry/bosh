require 'spec_helper'
require 'bosh/stemcell/definition'

module Bosh::Stemcell
  describe Definition do
    subject(:definition) { Bosh::Stemcell::Definition.new(infrastructure, operating_system, agent) }

    let(:infrastructure) do
      instance_double(
        'Bosh::Stemcell::Infrastructure::Base',
        name: 'infrastructure-name',
        hypervisor: 'hypervisor',
        light?: false,
      )
    end

    let(:operating_system) do
      instance_double(
        'Bosh::Stemcell::OperatingSystem::Base',
        name: 'operating-system-name',
        version: 'operating-system-version',
      )
    end

    let(:agent) do
      instance_double(
        'Bosh::Stemcell::Agent::Go',
        name: 'go',
      )
    end

    describe '.for' do
      it 'sets the infrastructure, operating system, and agent' do
        expect(Bosh::Stemcell::Infrastructure)
          .to receive(:for)
          .with('infrastructure-name')
          .and_return(infrastructure)

        expect(Bosh::Stemcell::OperatingSystem)
          .to receive(:for)
          .with('operating-system-name', 'operating-system-version')
          .and_return(operating_system)

        expect(Bosh::Stemcell::Agent)
          .to receive(:for)
          .with('agent-name')
          .and_return(agent)

        definition = instance_double('Bosh::Stemcell::Definition')
        expect(Bosh::Stemcell::Definition)
          .to receive(:new)
          .with(infrastructure, operating_system, agent)
          .and_return(definition)

        Bosh::Stemcell::Definition.for(
          'infrastructure-name',
          'operating-system-name',
          'operating-system-version',
          'agent-name'
        )
      end
    end

    describe '#initialize' do
      its(:infrastructure)             { should == infrastructure }
      its(:operating_system)           { should == operating_system }
      its(:agent)                      { should == agent }
    end

    describe '#==' do
      it 'compares by value instead of reference' do
        expect_eq = [
          %w(aws centos 6.5 ruby),
          %w(vsphere ubuntu penguin go),
        ]

        expect_eq.each do |tuple|
          expect(Definition.for(*tuple)).to eq(Definition.for(*tuple))
        end

        expect_not_equal = [
          [%w(aws ubuntu penguin ruby), %w(aws centos 6.5 ruby)],
          [%w(vsphere ubuntu penguin go), %w(vsphere ubuntu penguin ruby)],
        ]
        expect_not_equal.each do |left, right|
          expect(Definition.for(*left)).to_not eq(Definition.for(*right))
        end
      end
    end

    describe '#stemcell_name' do
      context 'when the agent name is ruby' do
        before { allow(agent).to receive(:name).and_return('ruby') }

        it 'does not include the agent name in the stemcell name' do
          expect(definition.stemcell_name).to eq(
            'infrastructure-name-hypervisor-operating-system-name-operating-system-version'
          )
        end
      end

      context 'when the agent name is go' do
        it 'includes go_agent in the stemcell name' do
          expect(definition.stemcell_name).to eq(
            'infrastructure-name-hypervisor-operating-system-name-operating-system-version-go_agent'
          )
        end
      end

      context 'when the operating system has a version' do
        it 'includes version in stemcell name' do
          expect(definition.stemcell_name).to eq(
            'infrastructure-name-hypervisor-operating-system-name-operating-system-version-go_agent'
          )
        end
      end

      context 'when the operating system does not have a version' do
        before { allow(operating_system).to receive(:version).and_return(nil) }

        it 'does not include version in stemcell name' do
          expect(definition.stemcell_name).to eq(
            'infrastructure-name-hypervisor-operating-system-name-go_agent'
          )
        end
      end
    end
  end
end
