require 'spec_helper'

describe Bosh::Cli::DeploymentHelper do
  include FakeFS::SpecHelpers

  class DeploymentHelperTester
    include Bosh::Cli::DeploymentHelper

    def initialize(director)
      @director = director
    end

    def director
      @director
    end
  end

  subject(:deployment_helper) { DeploymentHelperTester.new(director) }
  let(:director) { instance_double('Bosh::Cli::Client::Director') }

  describe '#prepare_deployment_manifest' do
    let(:manifest_warnings) { instance_double('Bosh::Cli::ManifestWarnings') }

    before do
      class_double('Bosh::Cli::ManifestWarnings').as_stubbed_const
      allow(Bosh::Cli::ManifestWarnings).to receive(:new).and_return(manifest_warnings)
      allow(manifest_warnings).to receive(:report)
    end

    def make_cmd(options = {})
      cmd = Bosh::Cli::Command::Base.new(options)
      cmd.extend(Bosh::Cli::DeploymentHelper)
      cmd
    end

    it 'checks that actual director UUID matches the one in manifest' do
      cmd = make_cmd
      manifest = {
        'name' => 'mycloud',
        'director_uuid' => 'deadbeef'
      }

      File.open('fake-deployment-file', 'w') { |f| f.write(manifest.to_yaml) }
      allow(cmd).to receive(:deployment).and_return('fake-deployment-file')

      director = instance_double('Bosh::Cli::Client::Director')
      allow(cmd).to receive(:director).and_return(director)

      expect(director).to receive(:uuid).and_return('deadcafe')

      expect {
        cmd.prepare_deployment_manifest(manifest)
      }.to raise_error(/Target director UUID doesn't match/i)
    end

    it 'reports manifest warnings' do
      cmd = make_cmd
      manifest = {
        'name' => 'mycloud',
        'director_uuid' => 'deadbeef',
        'release' => {'name' => 'appcloud', 'version' => 42}
      }

      File.open('fake-deployment-file', 'w') { |f| f.write(manifest.to_yaml) }
      director = instance_double('Bosh::Cli::Client::Director', uuid: 'deadbeef')
      allow(cmd).to receive(:deployment).and_return('fake-deployment-file')
      allow(cmd).to receive(:director).and_return(director)

      cmd.prepare_deployment_manifest(manifest)

      expect(manifest_warnings).to have_received(:report)
    end
  end

  describe '#job_exists_in_deployment?' do
    let(:manifest_hash) do
      {
        'name' => 'mycloud',
        'jobs' => [{'name' => 'job1'}]
      }
    end

    it 'should return true if job exists in deployment' do
      expect(deployment_helper.job_exists_in_deployment?(manifest_hash, 'job1')).to be(true)
    end

    it 'should return false if job does not exists in deployment' do
      expect(deployment_helper.job_exists_in_deployment?(manifest_hash, 'job2')).to be(false)
    end
  end

  describe '#job_unique_in_deployment?' do
    let(:manifest_hash) do
      {
        'name' => 'mycloud',
        'jobs' => [
          {'name' => 'job1', 'instances' => 1},
          {'name' => 'job2', 'instances' => 2}
        ]
      }
    end

    context 'when the job is in the manifest' do
      it 'should return true if only one instance of job in deployment' do
        expect(deployment_helper.job_unique_in_deployment?(manifest_hash, 'job1')).to be(true)
      end

      it 'should return false if more than one instance of job in deployment' do
        expect(deployment_helper.job_unique_in_deployment?(manifest_hash, 'job2')).to be(false)
      end
    end

    context 'when the job is not in the manifest' do
      it 'should return false' do
        expect(deployment_helper.job_unique_in_deployment?(manifest_hash, 'job3')).to be(false)
      end
    end
  end

  describe '#prompt_for_job_and_index' do
    before do
      allow(deployment_helper).to receive_messages(prepare_deployment_manifest: double(:manifest, name: 'mycloud',
      jobs: [{'name' => 'job', 'instances' => 2}]))

      allow(director).to receive(:fetch_vm_state).and_return([
        {'id' => '1234-5678-9012-3456', 'index' => 0, 'job' => 'job'},
        {'id' => '1234-5678-9012-3457', 'index' => 1, 'job' => 'job'}
      ])
    end

    it 'prompts the user to choose one' do
      menu = double('menu')
      expect(deployment_helper).to receive(:choose).and_yield(menu)
      expect(menu).to receive(:prompt=).with('Choose an instance: ')
      expect(menu).to receive(:choice).with('job/0 (1234-5678-9012-3456)')
      expect(menu).to receive(:choice).with('job/1 (1234-5678-9012-3457)')
      deployment_helper.prompt_for_job_and_index
    end
  end

  describe '#jobs_and_indexes' do
    before do
      allow(deployment_helper).to receive_messages(prepare_deployment_manifest: double(:manifest, hash: {
        'name' => 'mycloud',
        'jobs' => [
          {'name' => 'job1', 'instances' => 1},
          {'name' => 'job2', 'instances' => 2},
        ]
      }))
    end

    it 'returns array of ["job", index]' do
      expect(deployment_helper.jobs_and_indexes).to eq([['job1', 0], ['job2', 0], ['job2', 1]])
    end
  end

  describe '#inspect_deployment_changes' do
    context 'no changes with new manifest' do
      it 'prints out "no changes" for all manifest sections' do
        manifest_hash = {'name' => 'fake-deployment-name', 'releases' => []}
        File.open('fake-deployment-file', 'w') { |f| f.write(manifest_hash.to_yaml) }
        manifest = Bosh::Cli::Manifest.new('fake-deployment-file', director)
        manifest.load

        current_deployment = {'manifest' => 'name: fake-deployment-name'}

        output = ''
        allow(deployment_helper).to receive(:nl) { output += "\n" }
        allow(deployment_helper).to receive(:say) { |line| output += "#{line}\n" }

        allow(director).to receive(:get_deployment)
                             .with('fake-deployment-name')
                             .and_return(current_deployment)

        deployment_helper.inspect_deployment_changes(manifest)
        expect(output).to include("Releases\nNo changes")
        expect(output).to include("Compilation\nNo changes")
        expect(output).to include("Update\nNo changes")
        expect(output).to include("Resource pools\nNo changes")
        expect(output).to include("Networks\nNo changes")
        expect(output).to include("Jobs\nNo changes")
        expect(output).to include("Properties\nNo changes")
      end
    end
  end
end
