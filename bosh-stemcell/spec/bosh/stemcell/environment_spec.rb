require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/stemcell/environment'

module Bosh::Stemcell
  describe Environment do
    include FakeFS::SpecHelpers

    let(:options) do
      {
        infrastructure_name: 'aws'
      }
    end

    subject(:stemcell_environment) do
      Environment.new(options)
    end

    describe '#build_path' do
      its(:build_path) { should eq '/mnt/stemcells/aws/build' }

      context 'when FAKE_MNT is set' do
        before do
          ENV.stub(to_hash: {
            'FAKE_MNT' => '/fake_mnt'
          })
        end

        its(:build_path) { should eq '/fake_mnt/stemcells/aws/build' }
      end
    end

    describe '#work_path' do
      its(:work_path) { should eq '/mnt/stemcells/aws/work' }

      context 'when FAKE_MNT is set' do
        before do
          ENV.stub(to_hash: {
            'FAKE_MNT' => '/fake_mnt'
          })
        end

        its(:work_path) { should eq '/fake_mnt/stemcells/aws/work' }
      end
    end
  end
end
