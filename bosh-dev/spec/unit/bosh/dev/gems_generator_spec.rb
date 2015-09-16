require 'spec_helper'
require 'bosh/dev/build'
require 'bosh/dev/gems_generator'

module Bosh::Dev
  describe GemsGenerator do
    describe '#generate_and_upload' do
      subject { described_class.new(build) }
      let(:build) { instance_double('Bosh::Dev::Build', number: 456, upload_gems: nil) }

      before { allow(GemComponents).to receive_messages(new: gem_components) }
      let(:gem_components) { instance_double('Bosh::Dev::GemComponents', build_release_gems: nil) }

      before do
        allow(Rake::FileUtilsExt).to receive(:sh)
        allow(Dir).to receive(:chdir).and_yield
      end

      it 'builds all bosh gems' do
        expect(gem_components).to receive(:build_release_gems)
        subject.generate_and_upload
      end

      it 'builds gem server index' do
        expect(Dir).to receive(:chdir).with('pkg').and_yield
        expect(Bundler).to receive(:with_clean_env).and_yield
        expect(Rake::FileUtilsExt).to receive(:sh).with('gem', 'generate_index', '.')
        subject.generate_and_upload
      end

      it 'uploads all bosh gems' do
        expect(build).to receive(:upload_gems).with('.', 'gems')
        subject.generate_and_upload
      end
    end
  end
end
