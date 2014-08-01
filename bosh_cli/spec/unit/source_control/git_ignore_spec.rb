require 'spec_helper'

module Bosh::Cli::SourceControl
  describe GitIgnore do
    include FakeFS::SpecHelpers
    let(:dir) { '/fake/dir' }
    let(:file_path) { File.join(dir, '.gitignore') }

    before { FileUtils.mkdir_p(dir) }

    subject(:git_ignore) { GitIgnore.new(dir) }

    describe '#update' do
      context '.gitignore does not exist' do
        it 'creates the .gitignore file and adds all desired ignore patterns' do
          git_ignore.update
          expect(File).to exist(file_path)

          found_patterns = []
          File.open(file_path, 'r').each_line { |line| found_patterns << line.chomp }
          GitIgnore::RELEASE_IGNORE_PATTERNS.each do |pattern|
            expect(found_patterns).to include(pattern)
          end
        end
      end

      context '.gitignore already exists' do
        let(:old_patterns) { ['fake/pattern', 'dev_releases'] }
        before do
          File.open(file_path, 'w') do |f|
            old_patterns.each { |pattern| f.print(pattern + "\n") }
          end
        end

        it 'updates the .gitignore file to incude all desired ignore patterns' do
          git_ignore.update

          found_patterns = []
          File.open(file_path, 'r').each_line { |line| found_patterns << line.chomp }
          GitIgnore::RELEASE_IGNORE_PATTERNS.each do |pattern|
            expect(found_patterns).to include(pattern)
          end
        end

        it 'does not remove existing ignore patterns' do
          git_ignore.update

          found_patterns = []
          File.open(file_path, 'r').each_line { |line| found_patterns << line.chomp }

          expect(found_patterns).to include(*old_patterns)
        end
      end

      context '.gitignore already has all desired ignore patterns' do
        let(:old_patterns) { ['fake/pattern', 'fake/**/glob'] }
        before do
          File.open(file_path, 'w') do |f|
            old_patterns.each { |pattern| f.print(pattern + "\n") }
            GitIgnore::RELEASE_IGNORE_PATTERNS.each { |pattern| f.print(pattern + "\n") }
          end
        end

        it 'does not change the .gitignore file' do
          content_before = File.read(file_path)

          git_ignore.update

          content_after = File.read(file_path)
          expect(content_after). to eq(content_before)
        end
      end
    end
  end
end
