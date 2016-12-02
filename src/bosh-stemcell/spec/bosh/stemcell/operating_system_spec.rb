require 'spec_helper'
require 'bosh/stemcell/operating_system'

module Bosh::Stemcell
  describe OperatingSystem do
    describe '.for' do
      it 'returns the correct infrastrcture' do
        expect(OperatingSystem.for('centos', '99')).to be_a(OperatingSystem::Centos)
        expect(OperatingSystem.for('ubuntu', 'penguin')).to be_a(OperatingSystem::Ubuntu)
      end

      it 'raises for unknown operating system' do
        expect {
          OperatingSystem.for('BAD_OPERATING_SYSTEM', 'BAD_OS_VERSION')
        }.to raise_error(ArgumentError, /invalid operating system: BAD_OPERATING_SYSTEM/)
      end
    end
  end

  describe OperatingSystem::Base do
    describe '#initialize' do
      it 'requires :name to be specified' do
        expect {
          OperatingSystem::Base.new
        }.to raise_error /key not found: :name/
      end

      it 'requires :version to be specified' do
        expect {
          OperatingSystem::Base.new(name: 'CLOUDY_PONY_OS')
        }.to raise_error /key not found: :version/
      end
    end

    describe '#name' do
      subject { OperatingSystem::Base.new(name: 'CLOUDY_PONY_OS', version: 'HORSESHOE') }

      its(:name) { should eq('CLOUDY_PONY_OS') }
    end

    describe '#version' do
      subject { OperatingSystem::Base.new(name: 'CLOUDY_PONY_OS', version: 'HORSESHOE') }

      its(:version) { should eq('HORSESHOE') }
    end
  end

  describe OperatingSystem::Centos do
    subject { OperatingSystem::Centos.new('99') }

    its(:name) { should eq('centos') }
    it { should eq OperatingSystem.for('centos', '99') }
    it { should_not eq OperatingSystem.for('rhel', '99') }
    it { should_not eq OperatingSystem.for('ubuntu', 'penguin') }
  end

  describe OperatingSystem::Ubuntu do
    subject { OperatingSystem::Ubuntu.new('penguin') }

    its(:name) { should eq('ubuntu') }
    its(:version) { should eq('penguin') }
    it { should eq OperatingSystem.for('ubuntu', 'penguin') }
    it { should_not eq OperatingSystem.for('rhel', '99') }
    it { should_not eq OperatingSystem.for('centos', '99') }
  end

  describe OperatingSystem::Rhel do
    subject { OperatingSystem::Rhel.new('99') }

    its(:name) { should eq('rhel') }
    it { should eq OperatingSystem.for('rhel', '99') }
    it { should_not eq OperatingSystem.for('centos', '99') }
    it { should_not eq OperatingSystem.for('ubuntu', 'penguin') }
  end
end
