require 'spec_helper'
require 'bosh/dev/build'
require 'bosh/dev/gems_generator'

module Bosh::Dev
  describe GemsGenerator do
    describe '#generate_and_upload' do
      subject { described_class.new(build) }
      let(:build) { instance_double('Bosh::Dev::Build', number: 456, upload_gems: nil) }

      before { GemComponents.stub(new: gem_components) }
      let(:gem_components) { instance_double('Bosh::Dev::GemComponents', build_release_gems: nil) }

      before do
        Rake::FileUtilsExt.stub(:sh)
        Dir.stub(:chdir).and_yield
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
        build.should_receive(:upload_gems).with('.', 'gems')
        subject.generate_and_upload
      end
    end
  end
end
