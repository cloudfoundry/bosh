require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_environment'

module Bosh::Dev
  describe StemcellEnvironment do
    include FakeFS::SpecHelpers

    let(:infrastructure) { 'aws' }

    subject(:environment) do
      StemcellEnvironment.new('basic', infrastructure)
    end

    before do
      ENV.stub(:to_hash).and_return({
                                      'BUILD_ID' => 'fake-jenkins-BUILD_ID',
                                    })
    end

    its(:work_path) { should eq('/mnt/stemcells/aws-basic/work') }
    its(:build_path) { should eq('/mnt/stemcells/aws-basic/build') }
    its(:stemcell_version) { should eq('fake-jenkins-BUILD_ID') }

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
