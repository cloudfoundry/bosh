require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_environment'

module Bosh::Dev
  describe StemcellEnvironment do
    include FakeFS::SpecHelpers

    let(:options) do
      {
        infrastructure_name: 'aws'
      }
    end

    subject(:stemcell_environment) do
      StemcellEnvironment.new(options)
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

    describe '#sanitize' do
      let(:mnt_type) { 'ext4' }

      before do
        subject.stub(:system)
        subject.stub(:`).and_return(mnt_type)
        FileUtils.touch('leftover.tgz')
      end

      it 'removes any tgz files from current working directory' do
        expect {
          subject.sanitize
        }.to change { Dir.glob('*.tgz').size }.to(0)
      end

      it 'unmounts work/work/mnt/tmp/grub/root.img' do
        subject.should_receive(:system).with('sudo umount /mnt/stemcells/aws/work/work/mnt/tmp/grub/root.img 2> /dev/null')
        subject.sanitize
      end

      it 'unmounts work/work/mnt directory' do
        subject.should_receive(:system).with('sudo umount /mnt/stemcells/aws/work/work/mnt 2> /dev/null')
        subject.sanitize
      end

      it 'removes /mnt/stemcells/aws' do
        subject.should_receive(:system).with('sudo rm -rf /mnt/stemcells/aws')
        subject.sanitize
      end

      context 'when the mount type is btrfs' do
        let(:mnt_type) { 'btrfs' }

        it 'does not remove /mnt/stemcells/aws' do
          subject.should_not_receive(:system).with(%r{rm .* /mnt/stemcells/aws})
          subject.sanitize
        end
      end
    end
  end
end
