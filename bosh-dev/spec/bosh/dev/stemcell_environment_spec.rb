require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_environment'
require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellEnvironment do
    include FakeFS::SpecHelpers

    let(:stemcell_builder) do
      instance_double('Bosh::Dev::StemcellBuilder',
                      directory: '/mnt/stemcells/aws-basic',
                      work_path: '/mnt/stemcells/aws-basic/work')
    end

    subject(:environment) do
      StemcellEnvironment.new(stemcell_builder)
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
        subject.should_receive(:system).with('sudo umount /mnt/stemcells/aws-basic/work/work/mnt/tmp/grub/root.img 2> /dev/null')
        subject.sanitize
      end

      it 'unmounts work/work/mnt directory' do
        subject.should_receive(:system).with('sudo umount /mnt/stemcells/aws-basic/work/work/mnt 2> /dev/null')
        subject.sanitize
      end

      it 'removes /mnt/stemcells/aws-basic' do
        subject.should_receive(:system).with('sudo rm -rf /mnt/stemcells/aws-basic')
        subject.sanitize
      end

      context 'when the mount type is btrfs' do
        let(:mnt_type) { 'btrfs' }

        it 'does not remove /mnt/stemcells/aws-basic' do
          subject.should_not_receive(:system).with(%r{rm .* /mnt/stemcells/aws-basic})
          subject.sanitize
        end
      end
    end
  end
end
