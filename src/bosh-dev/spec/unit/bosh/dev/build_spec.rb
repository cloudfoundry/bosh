require 'spec_helper'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'
require 'bosh/dev/build'

module Bosh::Dev
  describe Build do
    include FakeFS::SpecHelpers

    describe '.build_number' do
      subject { described_class.build_number }
      before { stub_const('ENV', environment) }

      context 'when CANDIDATE_BUILD_NUMBER is set' do
        let(:environment) { {'CANDIDATE_BUILD_NUMBER' => 'candidate'} }

        it 'returns the specified build number' do
          expect(subject).to eq('candidate')
        end
      end

      context 'when CANDIDATE_BUILD_NUMBER is not set' do
        let(:environment) { {} }

        it 'returns the default build number' do
          expect(subject).to eq('0000')
        end
      end
    end

    describe '.candidate' do
      subject { described_class.candidate }

      context 'when CANDIDATE_BUILD_NUMBER and CANDIDATE_BUILD_GEM_NUMBER are set' do
        let(:environment) do
          {
            'CANDIDATE_BUILD_NUMBER' => 'candidate',
            'CANDIDATE_BUILD_GEM_NUMBER' => 'candidate_gem'
          }
        end
        before { stub_const('ENV', environment) }

        its(:number) { should eq('candidate') }
        its(:gem_number) { should eq('candidate_gem') }
      end

      context 'when CANDIDATE_BUILD_GEM_NUMBER is not set' do
        let(:environment) { {'CANDIDATE_BUILD_NUMBER' => 'candidate'} }
        before { stub_const('ENV', environment) }

        its(:number) { should eq('candidate') }
        its(:gem_number) { should eq('candidate') }
      end

      context 'when CANDIDATE_BUILD_NUMBER is not set' do
        its(:number) { should eq('0000') }
        context 'when STEMCELL_BUILD_NUMBER is set' do
          let(:environment) { {'STEMCELL_BUILD_NUMBER' => 'stemcell'} }
          before { stub_const('ENV', environment) }

          its(:number) { should eq('stemcell') }
          its(:gem_number) { should eq('stemcell') }
        end
      end
    end
  end
end

