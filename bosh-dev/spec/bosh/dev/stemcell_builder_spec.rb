require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellBuilder do
    include FakeFS::SpecHelpers

    let(:build) { instance_double('Bosh::Dev::Build', download_release: 'fake release path', number: 'fake build number') }
    let(:environment) do
      instance_double('Bosh::Dev::StemcellEnvironment',
                      sanitize: nil,
                      directory: '/environment',
                      build_path: '/environment/build',
                      work_path: '/environment/work',
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
        ENV.should_receive(:[]=).with('BUILD_PATH', '/environment/build')
        ENV.should_receive(:[]=).with('WORK_PATH', '/environment/work')
        ENV.should_receive(:[]=).with('STEMCELL_VERSION', 'fake stemcell_version')

        builder.micro
      end

      it 'creates a micro stemcell' do
        stemcell_micro_task.should_receive(:invoke).with('fake release path', 'fake infrastructure', 'fake build number')
        builder.micro
      end

      it 'returns the absolute path to the the new stemcell' do
        stemcell_micro_task.stub(:invoke) do
          stemcell_output_dir = File.join(environment.work_path, 'work')
          FileUtils.mkdir_p(stemcell_output_dir)

          stemcell_path = File.join(stemcell_output_dir, 'fake-micro-stemcell.tgz')
          FileUtils.touch(stemcell_path)

          nil
        end

        expect(builder.micro).to eq('/environment/work/work/fake-micro-stemcell.tgz')
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
        ENV.should_receive(:[]=).with('BUILD_PATH', '/environment/build')
        ENV.should_receive(:[]=).with('WORK_PATH', '/environment/work')
        ENV.should_receive(:[]=).with('STEMCELL_VERSION', 'fake stemcell_version')

        builder.basic
      end

      it 'creates a basic stemcell' do
        stemcell_basic_task.should_receive(:invoke).with('fake infrastructure', 'fake build number')
        builder.basic
      end

      it 'returns the absolute path to the the new stemcell' do
        stemcell_basic_task.stub(:invoke) do
          stemcell_output_dir = File.join(environment.work_path, 'work')
          FileUtils.mkdir_p(stemcell_output_dir)

          stemcell_path = File.join(stemcell_output_dir, 'fake-basic-stemcell.tgz')
          FileUtils.touch(stemcell_path)

          nil
        end

        expect(builder.basic).to eq('/environment/work/work/fake-basic-stemcell.tgz')
      end
    end

    describe '#stemcell_path' do
      before do
        FileUtils.mkdir_p(File.join(environment.work_path, 'work'))
      end

      it 'expects the stemcell to be placed by the stemcell_builder at an agreed location' do
        pending "This is the behavior we'd actually like, but we have some debt to address first"
      end

      context 'when a stemcell has not yet been created' do
        it 'is blank' do
          expect(builder.stemcell_path).to be_nil
        end
      end

      context 'once a stemcell has been created' do
        before do
          FileUtils.touch(File.join(environment.work_path, 'work', 'xyz.tgz'))
        end

        it 'is the full path to the stemcell' do
          expect(builder.stemcell_path).to eq('/environment/work/work/xyz.tgz')
        end

        context 'and more than one stemcell has been created' do
          before do
            FileUtils.touch(File.join(environment.work_path, 'work', 'abc.tgz'))
          end

          it 'coincidentally returns the full path to the first alphabetically sorted stemcell' do
            expect(builder.stemcell_path).to eq('/environment/work/work/abc.tgz')
          end
        end
      end
    end
  end
end
