require 'spec_helper'
require 'fakefs/spec_helpers'

require 'bosh/dev/stemcell_environment'

module Bosh::Dev
  describe StemcellEnvironment do
    include FakeFS::SpecHelpers

    let(:infrastructure) { 'aws' }

    subject do
      StemcellEnvironment.new('basic', infrastructure)
    end

    before do
      ENV.stub(:to_hash).and_return({
                                      'WORKSPACE' => '/fake_WORKSPACE',
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

    describe '#publish' do
      let(:candidate) { instance_double('Bosh::Dev::Build') }
      let(:stemcell) { instance_double('Bosh::Dev::Stemcell') }
      let(:pipeline) { instance_double('Bosh::Dev::Pipeline', publish_stemcell: nil) }

      before do
        Bosh::Dev::Build.stub(:candidate).and_return(candidate)

        Bosh::Dev::Stemcell.stub(:from_jenkins_build).
          with(subject.infrastructure, subject.stemcell_type, candidate).and_return(stemcell)

        Bosh::Dev::Pipeline.stub(:new).and_return(pipeline)
      end

      context 'when a stemcell has been built' do
        let(:candidate_artifacts) { instance_double('Bosh::Dev::CandidateArtifacts', publish: true) }

        before do
          FileUtils.mkdir_p(File.join(subject.directory, 'work', 'work'))
          FileUtils.touch(File.join(subject.directory, 'work', 'work', 'fake-stemcell.tgz'))

          Bosh::Dev::CandidateArtifacts.stub(:new).with('/fake_WORKSPACE/fake-stemcell.tgz').and_return(candidate_artifacts)
        end

        it 'copies the stemcell into the workspace' do
          expect {
            subject.publish
          }.to change { File.exists?('/fake_WORKSPACE/fake-stemcell.tgz') }.to(true)
        end

        it 'publishes the generated stemcell' do
          pipeline.should_receive(:publish_stemcell).with(stemcell)
          subject.publish
        end

        context 'and the infrastrcture is aws' do
          it 'publishes an aws light stemcell' do
            candidate_artifacts.should_receive(:publish)

            subject.publish
          end
        end

        context 'and the infrastrcture is not aws' do
          let(:infrastructure) { 'vsphere' }

          it 'does nothing since other infrastructures do not have light stemcells' do
            candidate_artifacts.should_not_receive(:publish)

            subject.publish
          end
        end
      end

      context 'when a stemcell has not been built' do
        it 'does nothing' do
          FileUtils.should_not_receive(:cp)
          subject.publish
        end
      end
    end
  end
end
