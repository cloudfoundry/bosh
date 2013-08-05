require 'spec_helper'
require 'bosh/dev/stemcell_environment'

module Bosh::Dev
  describe StemcellEnvironment do
    include FakeFS::SpecHelpers

    let(:infrastructure) { 'aws' }
    let(:build_candidate) { instance_double('Bosh::Dev::Build', download_release: 'fake release path', number: 1234) }

    subject do
      StemcellEnvironment.new('basic', infrastructure)
    end

    before do
      Bosh::Dev::Build.stub(:candidate).and_return(build_candidate)

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

    describe '#publish' do
      let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell') }
      let(:light_stemcell) { instance_double('Bosh::Stemcell::Aws::LightStemcell', write_archive: nil, path: 'fake light stemcell path') }
      let(:pipeline) { instance_double('Bosh::Dev::Pipeline', publish_stemcell: nil) }

      before do
        Bosh::Stemcell::Stemcell.stub(:new).and_return(stemcell)
        Bosh::Stemcell::Aws::LightStemcell.stub(:new).with(stemcell).and_return(light_stemcell)
        Pipeline.stub(:new).and_return(pipeline)

        stemcell_output_dir = File.join(subject.work_path, 'work')
        stemcell_path = File.join(stemcell_output_dir, 'fake-stemcell.tgz')

        FileUtils.mkdir_p(stemcell_output_dir)
        FileUtils.touch(stemcell_path)
      end

      it 'publishes the generated stemcell' do
        pipeline.should_receive(:publish_stemcell).with(stemcell)

        subject.publish
      end

      context 'when infrastrcture is aws' do
        let(:light_stemcell_stemcell) { instance_double('Bosh::Stemcell::Stemcell') }

        it 'publishes an aws light stemcell' do
          Bosh::Stemcell::Stemcell.should_receive(:new).with(light_stemcell.path).and_return(light_stemcell_stemcell)
          light_stemcell.should_receive(:write_archive)
          pipeline.should_receive(:publish_stemcell).with(light_stemcell_stemcell)

          subject.publish
        end
      end

      context 'when infrastrcture is not aws' do
        let(:infrastructure) { 'vsphere' }

        it 'does nothing since other infrastructures do not have light stemcells' do
          light_stemcell.should_not_receive(:write_archive)

          subject.publish
        end
      end
    end

    describe '#create_micro_stemcell' do
      let(:stemcell_micro_task) { instance_double('Rake::Task', invoke: nil) }

      before do
        Rake::Task.stub(:[]).with('stemcell:micro').and_return(stemcell_micro_task)
      end

      it 'sets BUILD_PATH, WORK_PATH & STEMCELL_VERSION as expected by the "stemcell:micro" task' do
        ENV.should_receive(:[]=).with('BUILD_PATH', '/mnt/stemcells/aws-basic/build')
        ENV.should_receive(:[]=).with('WORK_PATH', '/mnt/stemcells/aws-basic/work')
        ENV.should_receive(:[]=).with('STEMCELL_VERSION', 'fake-jenkins-BUILD_ID')

        subject.create_micro_stemcell
      end

      it 'creates a micro stemcell' do
        stemcell_micro_task.should_receive(:invoke).with('fake release path', 'aws', 1234)
        subject.create_micro_stemcell
      end
    end

    describe '#create_basic_stemcell' do
      let(:stemcell_basic_task) { instance_double('Rake::Task', invoke: nil) }

      before do
        Rake::Task.stub(:[]).with('stemcell:basic').and_return(stemcell_basic_task)
      end

      it 'sets BUILD_PATH, WORK_PATH & STEMCELL_VERSION as expected by the "stemcell:micro" task' do
        ENV.should_receive(:[]=).with('BUILD_PATH', '/mnt/stemcells/aws-basic/build')
        ENV.should_receive(:[]=).with('WORK_PATH', '/mnt/stemcells/aws-basic/work')
        ENV.should_receive(:[]=).with('STEMCELL_VERSION', 'fake-jenkins-BUILD_ID')

        subject.create_basic_stemcell
      end

      it 'creates a basic stemcell' do
        stemcell_basic_task.should_receive(:invoke).with('aws', 1234)
        subject.create_basic_stemcell
      end
    end
  end
end
