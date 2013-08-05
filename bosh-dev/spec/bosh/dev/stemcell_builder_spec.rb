require 'spec_helper'
require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellBuilder do
    let(:build) { instance_double('Bosh::Dev::Build', download_release: 'fake release path', number: 'fake build number') }
    let(:environment) do
      instance_double('Bosh::Dev::StemcellEnvironment',
                      sanitize: nil,
                      build_path: 'fake build_path',
                      work_path: 'fake work_path',
                      stemcell_version: 'fake stemcell_version',
                      infrastructure: 'fake infrastructure')
    end

    subject(:builder) do
      StemcellBuilder.new(environment, build)
    end

    describe '#micro' do
      let(:stemcell_micro_task) { instance_double('Rake::Task', invoke: nil) }

      before do
        Rake::Task.stub(:[]).with('stemcell:micro').and_return(stemcell_micro_task)
      end

      it 'sanitizes the stemcell environment' do
        environment.should_receive(:sanitize)
        builder.micro
      end

      it 'sets BUILD_PATH, WORK_PATH & STEMCELL_VERSION as expected by the "stemcell:micro" task' do
        ENV.should_receive(:[]=).with('BUILD_PATH', 'fake build_path')
        ENV.should_receive(:[]=).with('WORK_PATH', 'fake work_path')
        ENV.should_receive(:[]=).with('STEMCELL_VERSION', 'fake stemcell_version')

        builder.micro
      end

      it 'creates a micro stemcell' do
        stemcell_micro_task.should_receive(:invoke).with('fake release path', 'fake infrastructure', 'fake build number')
        builder.micro
      end
    end

    describe '#basic' do
      let(:stemcell_basic_task) { instance_double('Rake::Task', invoke: nil) }

      before do
        Rake::Task.stub(:[]).with('stemcell:basic').and_return(stemcell_basic_task)
      end

      it 'sanitizes the stemcell environment' do
        environment.should_receive(:sanitize)
        builder.basic
      end

      it 'sets BUILD_PATH, WORK_PATH & STEMCELL_VERSION as expected by the "stemcell:micro" task' do
        ENV.should_receive(:[]=).with('BUILD_PATH', 'fake build_path')
        ENV.should_receive(:[]=).with('WORK_PATH', 'fake work_path')
        ENV.should_receive(:[]=).with('STEMCELL_VERSION', 'fake stemcell_version')

        builder.basic
      end

      it 'creates a basic stemcell' do
        stemcell_basic_task.should_receive(:invoke).with('fake infrastructure', 'fake build number')
        builder.basic
      end
    end
  end
end
