require 'spec_helper'
require 'bosh/stemcell/definition'

module Bosh::Stemcell
  describe Definition do
    subject(:definition) { Bosh::Stemcell::Definition.new(infrastructure, hypervisor, operating_system, agent, light) }

    let(:infrastructure) do
      instance_double(
        'Bosh::Stemcell::Infrastructure::Base',
        name: 'infrastructure-name'
      )
    end

    let(:hypervisor) { "hypervisor" }
    let(:operating_system_version) { 'operating_system_version' }
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

    let(:light) do
      false
    end

    describe '.for' do
      it 'sets the infrastructure, hypervisor, os, os version, and agent' do
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
          .with(infrastructure, hypervisor, operating_system, agent, light)
          .and_return(definition)

        Bosh::Stemcell::Definition.for(
          'infrastructure-name',
          hypervisor,
          'operating-system-name',
          'operating-system-version',
          'agent-name',
          false,
        )
      end
    end

    describe '#initialize' do
      its(:infrastructure)             { should == infrastructure }
      its(:operating_system)           { should == operating_system }
      its(:agent)                      { should == agent }
      its(:hypervisor_name)            { should == hypervisor }
      its(:light?)                     { should == light }
    end

    describe '#==' do
      it 'compares by value instead of reference' do
        expect_eq = [
          %w(aws xen centos 6.5 go true),
          %w(vsphere esxi ubuntu penguin go false),
        ]

        expect_eq.each do |tuple|
          expect(Definition.for(*tuple)).to eq(Definition.for(*tuple))
        end

        expect_not_equal = [
          [%w(aws xen ubuntu penguin null false), %w(aws xen centos 6.5 null false)],
          [%w(aws xen ubuntu penguin null false), %w(aws xen ubuntu penguin null true)],
          [%w(vsphere esxi ubuntu penguin go false), %w(vsphere esxi ubuntu penguin null false)],
        ]
        expect_not_equal.each do |left, right|
          expect(Definition.for(*left)).to_not eq(Definition.for(*right))
        end
      end
    end

    describe '#stemcell_name' do
      subject { definition.stemcell_name }

      it { should match(infrastructure.name) }
      it { should match(hypervisor) }
      it { should match(operating_system.name) }

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

      context 'when the agent name is ruby' do
        let(:agent_name) { 'ruby' }

        it { should_not match(/agent$/) }
      end

      context 'when the operating system does not have a version' do
        before { allow(operating_system).to receive(:version).and_return(nil) }

        it { should match(/#{agent_name}_agent/) }
      end
    end
  end
end
