require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellBuilder do
    include FakeFS::SpecHelpers

    let(:build_number) { '869' }
    let(:infrastructure) { 'vsphere' }

    let(:build) { instance_double('Bosh::Dev::Build', download_release: 'fake release path', number: build_number) }
    let(:environment) do
      instance_double('Bosh::Dev::StemcellEnvironment',
                      stemcell_type: stemcell_type,
                      sanitize: nil,
                      directory: "/mnt/stemcells/#{infrastructure}-#{stemcell_type}",
                      build_path: "/mnt/stemcells/#{infrastructure}-#{stemcell_type}/build",
                      work_path: "/mnt/stemcells/#{infrastructure}-#{stemcell_type}/work",
                      stemcell_version: build_number,
                      infrastructure: infrastructure)
    end

    subject(:builder) do
      StemcellBuilder.new(environment, build)
    end

    describe '#build' do
      let(:stemcell_micro_task) { instance_double('Rake::Task', invoke: nil) }

      context 'when building a micro stemcell' do
        let(:stemcell_type) { 'micro' }

        before do
          Rake::Task.stub(:[]).with('stemcell:micro').and_return(stemcell_micro_task)
          stemcell_micro_task.stub(:invoke).with('fake release path', 'vsphere', build_number) do
            FileUtils.mkdir_p('/mnt/stemcells/vsphere-micro/work/work')
            FileUtils.touch('/mnt/stemcells/vsphere-micro/work/work/micro-bosh-stemcell-vsphere-869.tgz')
          end
        end

        it 'sanitizes the stemcell environment' do
          environment.should_receive(:sanitize)
          builder.build
        end

        it 'sets BUILD_PATH, WORK_PATH & STEMCELL_VERSION as expected by the "stemcell:micro" task' do
          ENV.should_receive(:[]=).with('BUILD_PATH', '/mnt/stemcells/vsphere-micro/build')
          ENV.should_receive(:[]=).with('WORK_PATH', '/mnt/stemcells/vsphere-micro/work')
          ENV.should_receive(:[]=).with('STEMCELL_VERSION', build_number)

          builder.build
        end

        it 'creates a micro stemcell and returns its absolute path' do
          expect(builder.build).to eq('/mnt/stemcells/vsphere-micro/work/work/micro-bosh-stemcell-vsphere-869.tgz')
        end

        context 'when the micro stemcell is not created' do
          before do
            stemcell_micro_task.stub(:invoke)
          end

          it 'fails early and loud' do
            expect {
              builder.build
            }.to raise_error(/micro-bosh-stemcell-vsphere-869\.tgz does not exist/)
          end
        end
      end

      context 'when building a basic stemcell' do
        let(:stemcell_type) { 'basic' }

        let(:stemcell_basic_task) { instance_double('Rake::Task', invoke: nil) }

        before do
          Rake::Task.stub(:[]).with('stemcell:basic').and_return(stemcell_basic_task)
          stemcell_basic_task.stub(:invoke).with('vsphere', build_number) do
            FileUtils.mkdir_p('/mnt/stemcells/vsphere-basic/work/work')
            FileUtils.touch('/mnt/stemcells/vsphere-basic/work/work/bosh-stemcell-vsphere-869.tgz')
          end
        end

        it 'sanitizes the stemcell environment' do
          environment.should_receive(:sanitize)
          builder.build
        end

        it 'sets BUILD_PATH, WORK_PATH & STEMCELL_VERSION as expected by the "stemcell:micro" task' do
          ENV.should_receive(:[]=).with('BUILD_PATH', '/mnt/stemcells/vsphere-basic/build')
          ENV.should_receive(:[]=).with('WORK_PATH', '/mnt/stemcells/vsphere-basic/work')
          ENV.should_receive(:[]=).with('STEMCELL_VERSION', build_number)

          builder.build
        end

        it 'creates a basic stemcell and returns its absolute path' do
          expect(builder.build).to eq('/mnt/stemcells/vsphere-basic/work/work/bosh-stemcell-vsphere-869.tgz')
        end

        context 'when the micro stemcell is not created' do
          before do
            stemcell_basic_task.stub(:invoke)
          end

          it 'fails early and loud' do
            expect {
              builder.build
            }.to raise_error(/\/bosh-stemcell-vsphere-869\.tgz does not exist/)
          end
        end
      end
    end

    describe '#stemcell_path' do
      before do
        FileUtils.mkdir_p(File.join(environment.work_path, 'work'))
      end

      context 'when build a micro non-openstack stemcell' do
        let(:stemcell_type) { 'micro' }
        let(:infrastructure) { 'aws' }

        it 'corresponds to $stemcell_tgz in stemcell_builder/stages/stemcell/apply.sh:48' do
          expect(builder.stemcell_path).to eq('/mnt/stemcells/aws-micro/work/work/micro-bosh-stemcell-aws-869.tgz')
        end
      end

      context 'when building a basic openstack stemcell' do
        let(:stemcell_type) { 'basic' }
        let(:infrastructure) { 'openstack' }

        it 'corresponds to $stemcell_tgz in stemcell_builder/stages/stemcell_openstack/apply.sh:57' do
          expect(builder.stemcell_path).to eq('/mnt/stemcells/openstack-basic/work/work/bosh-stemcell-openstack-kvm-869.tgz')
        end
      end
    end
  end
end
