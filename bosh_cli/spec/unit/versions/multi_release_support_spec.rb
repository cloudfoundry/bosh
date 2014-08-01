require 'spec_helper'

module Bosh::Cli::Versions
  describe MultiReleaseSupport do
    include FakeFS::SpecHelpers

    let(:migrator) { MultiReleaseSupport.new(work_dir, default_release_name, ui) }
    let(:work_dir) { '/fake/release' }
    let(:default_release_name) { 'bosh-release' }
    let(:ui) { double('FakeUI') }

    describe '#migrate' do

      let(:final_migrator) { instance_double('Bosh::Cli::Versions::ReleasesDirMigrator') }
      let(:dev_migrator) { instance_double('Bosh::Cli::Versions::ReleasesDirMigrator') }
      let(:git_ignore) { instance_double('Bosh::Cli::SourceControl::GitIgnore') }

      before do
        final_releases_path = File.join(work_dir, 'releases')
        allow(ReleasesDirMigrator).to receive(:new).
          with(final_releases_path, default_release_name, ui, 'FINAL').
          and_return(final_migrator)

        dev_releases_path = File.join(work_dir, 'dev_releases')
        allow(ReleasesDirMigrator).to receive(:new).
          with(dev_releases_path, default_release_name, ui, 'DEV').
          and_return(dev_migrator)
      end

      def self.it_migrates_gitignores
        it 'updates the gitignores' do
          expect(Bosh::Cli::SourceControl::GitIgnore).to receive(:new).with(work_dir).
            and_return(git_ignore)
          expect(git_ignore).to receive(:update)

          migrator.migrate
        end
      end

      it 'attempts to migrate final releases & dev releases' do
        expect(final_migrator).to receive(:migrate)
        expect(dev_migrator).to receive(:migrate)

        migrator.migrate
      end

      context 'when only the final releases are migrated' do
        before do
          expect(final_migrator).to receive(:migrate).and_return(true)
          expect(dev_migrator).to receive(:migrate).and_return(false)
        end

        it_migrates_gitignores
      end

      context 'when only the dev releases are migrated' do
        before do
          expect(final_migrator).to receive(:migrate).and_return(false)
          expect(dev_migrator).to receive(:migrate).and_return(true)
        end

        it_migrates_gitignores
      end

      context 'when both final releases & dev releases are migrated' do
        before do
          allow(final_migrator).to receive(:migrate).and_return(true)
          allow(dev_migrator).to receive(:migrate).and_return(true)
        end

        it_migrates_gitignores
      end

      context 'when neither dev or final releases are migrated' do
        before do
          allow(final_migrator).to receive(:migrate).and_return(false)
          allow(dev_migrator).to receive(:migrate).and_return(false)
        end

        it 'does not the gitignores' do
          expect(Bosh::Cli::SourceControl::GitIgnore).to_not receive(:new)

          migrator.migrate
        end
      end
    end
  end
end
