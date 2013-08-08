require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellBuilder do
    include FakeFS::SpecHelpers

    let(:build_number) { '869' }
    let(:infrastructure) { 'vsphere' }

    let(:build) { instance_double('Bosh::Dev::Build', download_release: 'fake release path', number: build_number) }
    let(:environment) { instance_double('Bosh::Dev::StemcellEnvironment', sanitize: nil) }

    subject(:builder) do
      StemcellBuilder.new(stemcell_type, infrastructure, build)
    end

    before do
      StemcellEnvironment.stub(:new).with(builder).and_return(environment)
    end

    describe '#build' do
      let(:stemcell_micro_task) { instance_double('Rake::Task', invoke: nil) }

      context 'when building a micro stemcell' do
        let(:stemcell_type) { 'micro' }

        before do
          Rake::Task.stub(:[]).with('stemcell:micro').and_return(stemcell_micro_task)
          stemcell_micro_task.stub(:invoke).with('fake release path', 'vsphere', build_number,
                                                 'micro-bosh-stemcell-869-vsphere-esxi-ubuntu.tgz') do
            FileUtils.mkdir_p('/mnt/stemcells/vsphere-micro/work/work')
            FileUtils.touch('/mnt/stemcells/vsphere-micro/work/work/micro-bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
          end
        end

        it 'sanitizes the stemcell environment' do
          environment.should_receive(:sanitize)
          builder.build
        end

        it 'sets BUILD_PATH, WORK_PATH as expected by the "stemcell:micro" task' do
          ENV.should_receive(:[]=).with('BUILD_PATH', '/mnt/stemcells/vsphere-micro/build')
          ENV.should_receive(:[]=).with('WORK_PATH', '/mnt/stemcells/vsphere-micro/work')

          builder.build
        end

        it 'creates a micro stemcell and returns its absolute path' do
          expect(builder.build).to eq('/mnt/stemcells/vsphere-micro/work/work/micro-bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
        end

        it 'creates a micro stemcell' do
          expect {
            builder.build
          }.to change {
            File.exist?('/mnt/stemcells/vsphere-micro/work/work/micro-bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
          }.to(true)
        end

        context 'when the micro stemcell is not created' do
          before do
            stemcell_micro_task.stub(:invoke)
          end

          it 'fails early and loud' do
            expect {
              builder.build
            }.to raise_error(/micro-bosh-stemcell-869-vsphere-esxi-ubuntu\.tgz does not exist/)
          end
        end
      end

      context 'when building a basic stemcell' do
        let(:stemcell_type) { 'basic' }

        let(:stemcell_basic_task) { instance_double('Rake::Task', invoke: nil) }

        before do
          Rake::Task.stub(:[]).with('stemcell:basic').and_return(stemcell_basic_task)
          stemcell_basic_task.stub(:invoke).with('vsphere', build_number, 'bosh-stemcell-869-vsphere-esxi-ubuntu.tgz') do
            FileUtils.mkdir_p('/mnt/stemcells/vsphere-basic/work/work')
            FileUtils.touch('/mnt/stemcells/vsphere-basic/work/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
          end
        end

        it 'sanitizes the stemcell environment' do
          environment.should_receive(:sanitize)
          builder.build
        end

        it 'sets BUILD_PATH, WORK_PATH as expected by the "stemcell:micro" task' do
          ENV.should_receive(:[]=).with('BUILD_PATH', '/mnt/stemcells/vsphere-basic/build')
          ENV.should_receive(:[]=).with('WORK_PATH', '/mnt/stemcells/vsphere-basic/work')

          builder.build
        end

        it 'creates a basic stemcell and returns its absolute path' do
          expect(builder.build).to eq('/mnt/stemcells/vsphere-basic/work/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz')
        end

        it 'creates a basic stemcell' do
          expect {
            builder.build
          }.to change { File.exist?('/mnt/stemcells/vsphere-basic/work/work/bosh-stemcell-869-vsphere-esxi-ubuntu.tgz') }.to(true)
        end

        context 'when the micro stemcell is not created' do
          before do
            stemcell_basic_task.stub(:invoke)
          end

          it 'fails early and loud' do
            expect {
              builder.build
            }.to raise_error(/\/bosh-stemcell-869-vsphere-esxi-ubuntu\.tgz does not exist/)
          end
        end
      end
    end

    describe '#old_style_path' do
      context 'when build a micro non-openstack stemcell' do
        let(:stemcell_type) { 'micro' }
        let(:infrastructure) { 'aws' }

        it 'corresponds to $stemcell_tgz in stemcell_builder/stages/stemcell/apply.sh:48' do
          expect(builder.old_style_path).to eq('/mnt/stemcells/aws-micro/work/work/micro-bosh-stemcell-aws-869.tgz')
        end
      end

      context 'when building a basic openstack stemcell' do
        let(:stemcell_type) { 'basic' }
        let(:infrastructure) { 'openstack' }

        it 'corresponds to $stemcell_tgz in stemcell_builder/stages/stemcell_openstack/apply.sh:57' do
          expect(builder.old_style_path).to eq('/mnt/stemcells/openstack-basic/work/work/bosh-stemcell-openstack-kvm-869.tgz')
        end
      end
    end
  end
end
