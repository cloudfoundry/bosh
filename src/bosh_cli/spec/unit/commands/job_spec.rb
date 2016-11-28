require 'spec_helper'

module Bosh::Cli
  describe Command::Job do
    let(:command) { Command::Job.new }
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

      context 'empty string is passed for job name' do
        let(:job_name) { '' }

        it 'raises error' do
          expect{ command.generate(job_name) }.to raise_error
        end
      end

      context 'nil is passed for job name' do
        let(:job_name) { nil }

        it 'raises error' do
          expect{ command.generate(job_name) }.to raise_error
        end
      end

      context 'when job does not already exist' do
        let(:job_name) { 'non-existent-job' }
        let(:job_dir) { "jobs/#{job_name}" }

        it 'generates monit and spec files and empty templates directory' do
          command.generate(job_name)

          expect(Dir.entries(File.join(job_dir))).to match_array(['.','..','monit','spec','templates'])
          expect(Dir.entries(File.join(job_dir, 'templates'))).to match_array(['.', '..'])
        end

        it 'echoes success message' do
          expect(command).to receive(:say).with("\nGenerated skeleton for '#{job_name}' job in '#{job_dir}'")

          command.generate(job_name)
        end
      end

      context 'when job already exists' do
        let(:job_name) { 'existent-job' }
        let(:job_dir) { "jobs/#{job_name}" }

        before { FileUtils.touch(job_dir) }

        it 'raises error saying that job already exists' do
          expect { command.generate(job_name) }.to raise_error("Job '#{job_name}' already exists, please pick another name")
        end
      end
    end
  end
end
