require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellBuilder do
    include FakeFS::SpecHelpers

    let(:build_number) { '869' }
    let(:build) { instance_double('Bosh::Dev::Build', download_release: 'fake release path', number: build_number) }

    subject(:builder) do
      StemcellBuilder.new(environment, build)
    end

    describe '#micro' do
      let(:environment) do
        instance_double('Bosh::Dev::StemcellEnvironment',
                        stemcell_type: 'micro',
                        sanitize: nil,
                        directory: '/environment',
                        build_path: '/environment/build',
                        work_path: '/environment/work',
                        stemcell_version: build_number,
                        infrastructure: 'vsphere')
      end

      let(:stemcell_micro_task) { instance_double('Rake::Task', invoke: nil) }

      before do
        Rake::Task.stub(:[]).with('stemcell:micro').and_return(stemcell_micro_task)
      end

      it 'sanitizes the stemcell environment' do
        environment.should_receive(:sanitize)
        builder.micro
      end

      it 'sets BUILD_PATH, WORK_PATH & STEMCELL_VERSION as expected by the "stemcell:micro" task' do
        ENV.should_receive(:[]=).with('BUILD_PATH', '/environment/build')
        ENV.should_receive(:[]=).with('WORK_PATH', '/environment/work')
        ENV.should_receive(:[]=).with('STEMCELL_VERSION', build_number)

        builder.micro
      end

      it 'creates a micro stemcell' do
        stemcell_micro_task.should_receive(:invoke).with('fake release path', 'vsphere', build_number)
        builder.micro
      end

      it 'returns the absolute path to the the new stemcell' do
        expect(builder.micro).to eq('/environment/work/work/micro-bosh-stemcell-vsphere-869.tgz')
      end
    end

    describe '#basic' do
      let(:environment) do
        instance_double('Bosh::Dev::StemcellEnvironment',
                        stemcell_type: 'basic',
                        sanitize: nil,
                        directory: '/environment',
                        build_path: '/environment/build',
                        work_path: '/environment/work',
                        stemcell_version: build_number,
                        infrastructure: 'vsphere')
      end

      let(:stemcell_basic_task) { instance_double('Rake::Task', invoke: nil) }

      before do
        Rake::Task.stub(:[]).with('stemcell:basic').and_return(stemcell_basic_task)
      end

      it 'sanitizes the stemcell environment' do
        environment.should_receive(:sanitize)
        builder.basic
      end

      it 'sets BUILD_PATH, WORK_PATH & STEMCELL_VERSION as expected by the "stemcell:micro" task' do
        ENV.should_receive(:[]=).with('BUILD_PATH', '/environment/build')
        ENV.should_receive(:[]=).with('WORK_PATH', '/environment/work')
        ENV.should_receive(:[]=).with('STEMCELL_VERSION', build_number)

        builder.basic
      end

      it 'creates a basic stemcell' do
        stemcell_basic_task.should_receive(:invoke).with('vsphere', build_number)
        builder.basic
      end

      it 'returns the absolute path to the the new stemcell' do
        expect(builder.basic).to eq('/environment/work/work/bosh-stemcell-vsphere-869.tgz')
      end
    end

    describe '#stemcell_path' do
      before do
        FileUtils.mkdir_p(File.join(environment.work_path, 'work'))
      end

      context 'when build a non-openstack stemcell' do
        let(:environment) do
          instance_double('Bosh::Dev::StemcellEnvironment',
                          stemcell_type: 'micro',
                          directory: '/mnt/stemcells/aws-micro',
                          work_path: '/mnt/stemcells/aws-micro/work',
                          build_path: '/mnt/stemcells/aws-micro/build',
                          stemcell_version: build_number,
                          infrastructure: 'aws')
        end

        it 'corresponds to $stemcell_tgz in stemcell_builder/stages/stemcell/apply.sh:48' do
          expect(builder.stemcell_path).to eq('/mnt/stemcells/aws-micro/work/work/micro-bosh-stemcell-aws-869.tgz')
        end
      end

      context 'when building an openstack stemcell' do
        let(:environment) do
          instance_double('Bosh::Dev::StemcellEnvironment',
                          stemcell_type: 'basic',
                          directory: '/mnt/stemcells/openstack-basic',
                          work_path: '/mnt/stemcells/openstack-basic/work',
                          build_path: '/mnt/stemcells/openstack-basic/build',
                          stemcell_version: build_number,
                          infrastructure: 'openstack')
        end

        it 'corresponds to $stemcell_tgz in stemcell_builder/stages/stemcell_openstack/apply.sh:57' do
          expect(builder.stemcell_path).to eq('/mnt/stemcells/openstack-basic/work/work/bosh-stemcell-openstack-kvm-869.tgz')
        end
      end
    end
  end
end
