require 'spec_helper'
require 'bosh/dev/gems_generator'

module Bosh::Dev
  describe GemsGenerator do
    let(:gem_components) { instance_double('Bosh::Dev::GemComponents', build_release_gems: nil) }

    before do
      GemComponents.stub(new: gem_components)
      Rake::FileUtilsExt.stub(:sh)
    end

    describe '#generate_and_upload' do
      let(:version_file) { instance_double('Bosh::Dev::VersionFile', write: nil) }
      let(:candidate_build) { instance_double('Bosh::Dev::Build', number: 456, upload_gems: nil) }

      before do
        VersionFile.stub(:new).with(456).and_return(version_file)
        Build.stub(candidate: candidate_build)

        Dir.stub(:chdir).and_yield
      end

      it 'updates BOSH_VERSION' do
        version_file.should_receive(:write)

        subject.generate_and_upload
      end

      it 'builds all bosh gems' do
        gem_components.should_receive(:build_release_gems)

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
