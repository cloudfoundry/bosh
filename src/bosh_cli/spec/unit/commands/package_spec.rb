require 'spec_helper'

module Bosh::Cli
  describe Command::Package do
    let(:command) { Command::Package.new }
    let(:director) { instance_double('Bosh::Cli::Client::Director') }

    let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }

    before do
      release_source.add_dir('jobs')
      release_source.add_dir('packages')
      release_source.add_dir('src')

      allow(command).to receive(:director).and_return(director)
      allow(command).to receive(:say)

      command.options = { dir: release_source.path }
    end

    describe 'generate' do
      before { Dir.chdir(release_source.path) }

      context 'empty string is passed for package name' do
        let(:package_name) { '' }

        it 'raises error' do
          expect{ command.generate(package_name) }.to raise_error
        end
      end

      context 'nil is passed for package name' do
        let(:package_name) { nil }

        it 'raises error' do
          expect{ command.generate(package_name) }.to raise_error
        end
      end

      context 'when package does not already exist' do
        let(:package_name) { 'non-existent-package' }
        let(:package_dir) { "packages/#{package_name}" }

        it 'generates packaging and spec files' do
          command.generate(package_name)

          expect(Dir.entries(package_dir)).to match_array(['.','..','packaging','spec'])
        end

        it 'echoes success message' do
          expect(command).to receive(:say).with("\nGenerated skeleton for '#{package_name}' package in '#{package_dir}'")

          command.generate(package_name)
        end
      end

      context 'when package already exists' do
        let(:package_name) { 'existent-package' }
        let(:package_dir) { "packages/#{package_name}" }

        before { FileUtils.touch(package_dir) }

        it 'raises error saying that package already exists' do
          expect { command.generate(package_name) }.to raise_error("Package '#{package_name}' already exists, please pick another name")
        end
      end
    end
  end
end
