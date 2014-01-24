require 'spec_helper'
require 'bosh/stemcell/operating_system'

module Bosh::Stemcell
  describe OperatingSystem do
    describe '.for' do
      it 'returns the correct infrastrcture' do
        expect(OperatingSystem.for('centos')).to be_a(OperatingSystem::Centos)
        expect(OperatingSystem.for('ubuntu')).to be_a(OperatingSystem::Ubuntu)
      end

      it 'raises for unknown operating system' do
        expect {
          OperatingSystem.for('BAD_OPERATING_SYSTEM')
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
    end

    describe '#name' do
      subject { OperatingSystem::Base.new(name: 'CLOUDY_PONY_OS') }

      its(:name) { should eq('CLOUDY_PONY_OS') }
    end
  end

  describe OperatingSystem::Centos do
    subject { OperatingSystem::Centos.new }

    its(:name) { should eq('centos') }
    it { should eq OperatingSystem.for('centos') }
    it { should_not eq OperatingSystem.for('ubuntu') }
  end

  describe OperatingSystem::Ubuntu do
    subject { OperatingSystem::Ubuntu.new }

    its(:name) { should eq('ubuntu') }
    it { should eq OperatingSystem.for('ubuntu') }
    it { should_not eq OperatingSystem.for('centos') }
  end
end
