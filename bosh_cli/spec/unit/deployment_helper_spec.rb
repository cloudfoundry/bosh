require 'spec_helper'

describe Bosh::Cli::DeploymentHelper do
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

  let(:release_list) do
    [
      {
        'name' => 'bat',
        'release_versions' => [
          {
            'version' => '1',
            'commit_hash' => 'unknown',
            'uncommitted_changes' => false,
            'currently_deployed' => false,
          },
          {
            'version' => '3.1-dev',
            'commit_hash' => 'unknown',
            'uncommitted_changes' => false,
            'currently_deployed' => false,
          },
          {
            'version' => '3',
            'commit_hash' => 'unknown',
            'uncommitted_changes' => false,
            'currently_deployed' => false,
          },
        ],
      },
      {
        'name' => 'bosh',
        'release_versions' => [
          {
            'version' => '2',
            'commit_hash' => 'unknown',
            'uncommitted_changes' => false,
            'currently_deployed' => false,
          },
          {
            'version' => '1.2-dev',
            'commit_hash' => 'unknown',
            'uncommitted_changes' => false,
            'currently_deployed' => false,
          },
        ],
      },
    ]
  end

  describe '#latest_release_versions' do
    context 'for director version < 1.5' do
      before do
        director.stub(list_releases: [
          {
            'name' => 'bat',
            'versions' => ['1', '3.1-dev', '3', '2'],
            'in_use' => ['1'],
          },
          {
            'name' => 'bosh',
            'versions' => ['2', '1.2-dev'],
            'in_use' => [],
          },
        ])
      end

      it 'should have the latest version for each release' do
        deployment_helper.latest_release_versions.should == {
          'bat' => '3.1-dev',
          'bosh' => '2'
        }
      end
    end

    context 'for director version >= 1.5' do
      before { director.stub(list_releases: release_list) }

      it 'should have the latest version for each release' do
        deployment_helper.latest_release_versions.should == {
          'bat' => '3.1-dev',
          'bosh' => '2'
        }
      end
    end
  end

  describe '#resolve_release_aliases' do
    context 'when release versions are explicit' do
      context 'when manifest has single release' do
        before do
          @manifest = {
            'release' => {
              'name' => 'bat',
              'version' => '3.1-dev'
            }
          }
        end

        it 'should leave the version as is' do
          deployment_helper.resolve_release_aliases(@manifest)
          @manifest['release']['version'].should == '3.1-dev'
        end
      end

      context 'manifest with multiple releases' do
        before do
          @manifest = {
            'releases' => [
              { 'name' => 'bat', 'version' => '3.1-dev' },
              { 'name' => 'bosh', 'version' => '1.2-dev' },
            ]
          }
        end

        it 'should leave the versions as they are' do
          deployment_helper.resolve_release_aliases(@manifest)
          @manifest['releases'].detect { |release| release['name'] == 'bat' }['version'].should == '3.1-dev'
          @manifest['releases'].detect { |release| release['name'] == 'bosh' }['version'].should == '1.2-dev'
        end
      end
    end

    context "when some release versions are set to 'latest'" do
      before do
        @manifest = {
          'releases' => [
            { 'name' => 'bat', 'version' => '3.1-dev' },
            { 'name' => 'bosh', 'version' => 'latest' },
          ]
        }
        director.stub(list_releases: release_list)
      end

      it 'should resolve the version to the latest for that release' do
        deployment_helper.resolve_release_aliases(@manifest)
        @manifest['releases'].detect { |release| release['name'] == 'bat' }['version'].should == '3.1-dev'
        @manifest['releases'].detect { |release| release['name'] == 'bosh' }['version'].should == 2
      end

      context 'when the release is not found on the director' do
        let(:release_list) { [] }

        it 'raises an error' do
          expect {
            deployment_helper.resolve_release_aliases(@manifest)
          }.to raise_error(
            Bosh::Cli::CliError,
            "Release 'bosh' not found on director. Unable to resolve 'latest' alias in manifest.",
          )
        end
      end
    end

    it 'casts final release versions to Integer' do
      manifest = { 'release' => { 'name' => 'foo', 'version' => '12321' } }
      deployment_helper.resolve_release_aliases(manifest)
      manifest['release']['version'].should == 12321
    end
  end

  describe '#prepare_deployment_manifest' do
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

      manifest_file = Tempfile.new('manifest')
      Psych.dump(manifest, manifest_file)
      manifest_file.close
      director = instance_double('Bosh::Cli::Client::Director')

      cmd.stub(:deployment).and_return(manifest_file.path)
      cmd.stub(:director).and_return(director)

      director.should_receive(:uuid).and_return('deadcafe')

      expect {
        cmd.prepare_deployment_manifest
      }.to raise_error(/Target director UUID doesn't match/i)
    end

    it "resolves 'latest' release alias for multiple stemcells" do
      cmd = make_cmd
      manifest = {
        'name' => 'mycloud',
        'director_uuid' => 'deadbeef',
        'release' => { 'name' => 'appcloud', 'version' => 42 },
        'resource_pools' => [
          { 'stemcell' => { 'name' => 'foo', 'version' => 'latest' } },
          { 'stemcell' => { 'name' => 'foo', 'version' => 22 } },
          { 'stemcell' => { 'name' => 'bar', 'version' => 'latest' } },
        ]
      }

      manifest_file = Tempfile.new('manifest')
      Psych.dump(manifest, manifest_file)
      manifest_file.close
      director = double(Bosh::Cli::Client::Director, :uuid => 'deadbeef')

      cmd.stub(:deployment).and_return(manifest_file.path)
      cmd.stub(:director).and_return(director)

      stemcells = [
        { 'name' => 'foo', 'version' => '22.6.4' },
        { 'name' => 'foo', 'version' => '22' },
        { 'name' => 'bar', 'version' => '4.0.8' },
        { 'name' => 'bar', 'version' => '4.1' }
      ]

      director.should_receive(:list_stemcells).and_return(stemcells)

      manifest = cmd.prepare_deployment_manifest
      manifest['resource_pools'][0]['stemcell']['version'].should == '22.6.4'
      manifest['resource_pools'][1]['stemcell']['version'].should == 22
      manifest['resource_pools'][2]['stemcell']['version'].should == 4.1
    end
  end

  describe '#job_exists_in_deployment?' do
    before do
      deployment_helper.stub(prepare_deployment_manifest: {
        'name' => 'mycloud',
        'jobs' => [{ 'name' => 'job1' }]
      })
    end

    it 'should return true if job exists in deployment' do
      deployment_helper.job_exists_in_deployment?('job1').should be(true)
    end

    it 'should return false if job does not exists in deployment' do
      deployment_helper.job_exists_in_deployment?('job2').should be(false)
    end
  end

  describe '#job_unique_in_deployment?' do
    before do
      deployment_helper.stub(prepare_deployment_manifest: {
        'name' => 'mycloud',
        'jobs' => [
          { 'name' => 'job1', 'instances' => 1 },
          { 'name' => 'job2', 'instances' => 2 }
        ]
      })
    end

    context 'when the job is in the manifest' do
      it 'should return true if only one instance of job in deployment' do
        expect(deployment_helper.job_unique_in_deployment?('job1')).to be(true)
      end

      it 'should return false if more than one instance of job in deployment' do
        expect(deployment_helper.job_unique_in_deployment?('job2')).to be(false)
      end
    end

    context 'when the job is not in the manifest' do
      it 'should return false' do
        expect(deployment_helper.job_unique_in_deployment?('job3')).to be(false)
      end
    end
  end

  describe '#prompt_for_job_and_index' do
    context 'when there is only 1 job instance in total' do
      before do
        deployment_helper.stub(prepare_deployment_manifest: {
          'name' => 'mycloud',
          'jobs' => [{ 'name' => 'job', 'instances' => 1 }],
        })
      end

      it 'does not prompt the user to choose a job' do
        deployment_helper.should_not_receive(:choose)
        deployment_helper.prompt_for_job_and_index
      end
    end

    context 'when there is more than 1 job instance' do
      before do
        deployment_helper.stub(prepare_deployment_manifest: {
          'name' => 'mycloud',
          'jobs' => [{ 'name' => 'job', 'instances' => 2 }],
        })
      end

      it 'prompts the user to choose one' do
        menu = double('menu')
        deployment_helper.should_receive(:choose).and_yield(menu)
        menu.should_receive(:prompt=).with('Choose an instance: ')
        menu.should_receive(:choice).with('job/0')
        menu.should_receive(:choice).with('job/1')
        deployment_helper.prompt_for_job_and_index
      end
    end
  end

  describe '#jobs_and_indexes' do
    before do
      deployment_helper.stub(prepare_deployment_manifest: {
        'name' => 'mycloud',
        'jobs' => [
          { 'name' => 'job1', 'instances' => 1 },
          { 'name' => 'job2', 'instances' => 2 },
        ]
      })
    end

    it 'returns array of ["job", index]' do
      deployment_helper.jobs_and_indexes.should == [['job1', 0], ['job2', 0], ['job2', 1]]
    end
  end

  describe '#inspect_deployment_changes' do
    context 'no changes with new manifest' do
      it 'prints out "no changes" for all manifest sections' do
        manifest = {'name' => 'fake-deployment-name'}
        current_deployment = {'manifest' => 'name: fake-deployment-name'}

        output = ""
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
