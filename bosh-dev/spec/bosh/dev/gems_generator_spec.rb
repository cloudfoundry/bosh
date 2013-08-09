require 'spec_helper'
require 'bosh/dev/gems_generator'

module Bosh::Dev
  describe GemsGenerator do
    describe '#generate_and_upload' do
      let(:version_file) { instance_double('VersionFile', write: nil) }
      let(:candidate_build) { instance_double('Build', number: 456, upload_gems: nil) }
      let(:rake_task) { double('Rake::Task', invoke: nil) }

      before do
        VersionFile.stub(:new).with(456).and_return(version_file)
        Build.stub(candidate: candidate_build)

        Rake::Task.stub(:[] => rake_task)
        Dir.stub(:chdir).and_yield

        Rake::FileUtilsExt.stub(:sh)
      end

      it 'updates BOSH_VERSION' do
        version_file.should_receive(:write)

        subject.generate_and_upload
      end

      it 'builds all bosh gems' do
        Rake::Task.should_receive(:[]).with('all:finalize_release_directory').and_return(rake_task)

        subject.generate_and_upload
      end

      it 'builds gem server index' do
        Dir.should_receive(:chdir).with('pkg').and_yield
        Bundler.should_receive(:with_clean_env).and_yield

        Rake::FileUtilsExt.should_receive(:sh).with('gem', 'generate_index', '.')

        subject.generate_and_upload
      end

      it 'uploads all bosh gems' do
        candidate_build.should_receive(:upload_gems).with('.', 'gems')

        subject.generate_and_upload
      end
    end
  end
end
