require 'spec_helper'
require 'bosh/stemcell/definition'

module Bosh::Stemcell
  describe Definition do
    subject(:definition) { Bosh::Stemcell::Definition.new(infrastructure, hypervisor, operating_system, agent, light) }

    let(:infrastructure) do
      instance_double(
        'Bosh::Stemcell::Infrastructure::Base',
        name: 'infrastructure-name',
        hypervisor: 'hypervisor-name',
        default_disk_format: 'default-disk-format'
      )
    end

    let(:hypervisor) { "hypervisor" }
    let(:operating_system_version) { 'operating_system_version' }
    let(:operating_system) do
      instance_double(
        'Bosh::Stemcell::OperatingSystem::Base',
        name: 'operating-system-name',
        version: operating_system_version,
      )
    end

    let(:agent_name) { "go" }
    let(:agent) do
      instance_double(
        'Bosh::Stemcell::Agent::Go',
        name: agent_name,
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
      its(:infrastructure) { should == infrastructure }
      its(:operating_system) { should == operating_system }
      its(:agent) { should == agent }
      its(:hypervisor_name) { should == hypervisor }
      its(:light?) { should == light }
    end

    describe '#==' do
      it 'compares by value instead of reference' do
        expect_eq = [
          %w(aws xen centos 7 go true),
          %w(vsphere esxi ubuntu penguin go false),
        ]

        expect_eq.each do |tuple|
          expect(Definition.for(*tuple)).to eq(Definition.for(*tuple))
        end

        expect_not_equal = [
          [['aws', 'xen', 'ubuntu', 'penguin', 'null', false], ['aws', 'xen', 'centos', '7', 'null', false]],
          [['aws', 'xen', 'ubuntu', 'penguin', 'null', false], ['aws', 'xen', 'ubuntu', 'penguin', 'null', true]],
          [
            ['vsphere', 'esxi', 'ubuntu', 'penguin', 'go', false],
            ['vsphere', 'esxi', 'ubuntu', 'penguin', 'null', false]
          ],
        ]
        expect_not_equal.each do |left, right|
          expect(Definition.for(*left)).to_not eq(Definition.for(*right))
        end
      end
    end

    describe '#stemcell_name' do
      it 'builds a name from the infrastructure, hypervisor, os, agent, and disk format' do
        expect(definition.stemcell_name('disk-format')).to eq(
          'infrastructure-name-hypervisor-operating-system-name-operating_system_version-go_agent-disk-format'
        )
      end

      context 'the os doesnt have a version' do
        let(:operating_system_version) { nil }

        it 'leaves off the os version' do
          expect(definition.stemcell_name('disk-format')).to eq(
            'infrastructure-name-hypervisor-operating-system-name-go_agent-disk-format'
          )
        end
      end

      context 'the agent name is ruby' do
        let(:agent_name) { 'ruby' }

        it 'leaves it off' do
          expect(definition.stemcell_name('disk-format')).to eq(
            'infrastructure-name-hypervisor-operating-system-name-operating_system_version-disk-format'
          )
        end
      end

      context 'the disk format is the default' do
        it 'leaves it off' do
          expect(definition.stemcell_name('default-disk-format')).to eq(
            'infrastructure-name-hypervisor-operating-system-name-operating_system_version-go_agent'
          )
        end
      end
    end

    describe 'disk_formats' do
      it 'delegates to infrastructure#disk_formats' do
        expect(infrastructure).to receive(:disk_formats).and_return(['format1', 'format2'])

        expect(definition.disk_formats).to eq(['format1', 'format2'])
      end
    end

    describe '#light?' do
      context 'when it is true' do
        let(:light) { true }
        its(:light?) { should eq(true) }
      end

      context 'when not provided' do
        let(:light) { nil }
        its(:light?) { should eq(false) }
      end

      context 'when it is empty' do
        let(:light) { '' }
        its(:light?) { should eq(false) }
      end

      context 'when it is false' do
        let(:light) { false }
        its(:light?) { should eq(false) }
      end
    end
  end
end
