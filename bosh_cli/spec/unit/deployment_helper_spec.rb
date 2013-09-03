# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Cli::DeploymentHelper do
  class DeploymentHelperTester
    include Bosh::Cli::DeploymentHelper

    def initialize(fake_director)
      @fake_director = fake_director
    end

    def director
      @fake_director
    end
  end

  let(:fake_director) { double(Bosh::Cli::Director) }
  let(:tester) { DeploymentHelperTester.new(fake_director) }
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
        old_style_release_list =
            [
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
            ]
        fake_director.stub(list_releases: old_style_release_list)
      end

      it 'should have the latest version for each release' do
        tester.latest_release_versions.should == {
            'bat' => '3.1-dev',
            'bosh' => '2'
        }
      end
    end

    context 'for director version >= 1.5' do
      before do
        fake_director.stub(list_releases: release_list)
      end

      it 'should have the latest version for each release' do
        tester.latest_release_versions.should == {
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
          tester.resolve_release_aliases(@manifest)

          @manifest['release']['version'].should == '3.1-dev'
        end

      end

      context 'manifest with multiple releases' do
        before do
          @manifest = {
              'releases' => [
                  {
                      'name' => 'bat',
                      'version' => '3.1-dev'
                  },
                  {
                      'name' => 'bosh',
                      'version' => '1.2-dev'
                  }
              ]
          }
        end

        it 'should leave the versions as they are' do
          tester.resolve_release_aliases(@manifest)

          @manifest['releases'].detect { |release| release['name'] == 'bat' }['version'].should == '3.1-dev'
          @manifest['releases'].detect { |release| release['name'] == 'bosh' }['version'].should == '1.2-dev'
        end
      end
    end

    context "when some release versions are set to 'latest'" do
      before do
        @manifest = {
            'releases' => [
                {
                    'name' => 'bat',
                    'version' => '3.1-dev'
                },
                {
                    'name' => 'bosh',
                    'version' => 'latest'
                }
            ]
        }
        fake_director.stub(list_releases: release_list)
      end

      it 'should resolve the version to the latest for that release' do
        tester.resolve_release_aliases(@manifest)

        @manifest['releases'].detect { |release| release['name'] == 'bat' }['version'].should == '3.1-dev'
        @manifest['releases'].detect { |release| release['name'] == 'bosh' }['version'].should == 2
      end

      context 'when the release is not found on the director' do
        let(:release_list) { [] }

        it 'raises an error' do
          expect { tester.resolve_release_aliases(@manifest) }.to raise_error(Bosh::Cli::CliError,
                                                                              "Release 'bosh' not found on director. Unable to resolve 'latest' alias in manifest.")
        end
      end

    end

    it 'casts final release versions to Integer' do
      manifest = {'release' => {'name' => 'foo', 'version' => '12321'}}

      tester.resolve_release_aliases(manifest)

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

      manifest_file = Tempfile.new("manifest")
      YAML.dump(manifest, manifest_file)
      manifest_file.close
      director = double(Bosh::Cli::Director)

      cmd.stub(:deployment).and_return(manifest_file.path)
      cmd.stub(:director).and_return(director)

      director.should_receive(:uuid).and_return('deadcafe')

      expect {
        cmd.prepare_deployment_manifest
      }.to raise_error(/Target director UUID doesn't match/i)
    end

    it "skips director UUID check if manifest director_uuid is set to 'ignore'" do
      cmd = make_cmd
      manifest = {
        'name' => 'mycloud',
        'director_uuid' => 'ignore',
        'release' => 'latest'
      }

      manifest_file = Tempfile.new('manifest')
      YAML.dump(manifest, manifest_file)
      manifest_file.close
      director = mock(Bosh::Cli::Director)

      cmd.stub!(:deployment).and_return(manifest_file.path)
      cmd.stub!(:director).and_return(director)

      director.should_receive(:uuid).and_return('deadcafe')

      expect {
        cmd.prepare_deployment_manifest
      }.not_to raise_error
    end

    it "resolves 'latest' release alias for multiple stemcells" do
      cmd = make_cmd
      manifest = {
          'name' => 'mycloud',
          'director_uuid' => 'deadbeef',
          'release' => {'name' => 'appcloud', 'version' => 42},
          'resource_pools' => [
              {'stemcell' => {'name' => 'foo', 'version' => 'latest'}},
              {'stemcell' => {'name' => 'foo', 'version' => 22}},
              {'stemcell' => {'name' => 'bar', 'version' => 'latest'}},
          ]
      }

      manifest_file = Tempfile.new('manifest')
      Psych.dump(manifest, manifest_file)
      manifest_file.close
      director = double(Bosh::Cli::Director, :uuid => 'deadbeef')

      cmd.stub(:deployment).and_return(manifest_file.path)
      cmd.stub(:director).and_return(director)

      stemcells = [
          {'name' => 'foo', 'version' => '22.6.4'},
          {'name' => 'foo', 'version' => '22'},
          {'name' => 'bar', 'version' => '4.0.8'},
          {'name' => 'bar', 'version' => '4.1'}
      ]

      director.should_receive(:list_stemcells).and_return(stemcells)

      manifest = cmd.prepare_deployment_manifest
      manifest['resource_pools'][0]['stemcell']['version'].should == '22.6.4'
      manifest['resource_pools'][1]['stemcell']['version'].should == 22
      manifest['resource_pools'][2]['stemcell']['version'].should == 4.1
    end
  end

  describe '#job_exists_in_deployment?' do
    let(:manifest) do
      {
          'name' => 'mycloud',
          'jobs' => [
              {
                  'name' => 'job1'
              }
          ]
      }
    end

    before do
      tester.stub(prepare_deployment_manifest: manifest)
    end

    it 'should return true if job exists in deployment' do
      tester.job_exists_in_deployment?('job1').should be_true
    end

    it 'should return false if job does not exists in deployment' do
      tester.job_exists_in_deployment?('job2').should be_false
    end
  end

  describe 'job_unique_in_deployment?' do
    let(:manifest) do
      {
          'name' => 'mycloud',
          'jobs' => [
              {
                  'name' => 'job1',
                  'instances' => 1
              },
              {
                  'name' => 'job2',
                  'instances' => 2
              }
          ]
      }
    end

    before do
      tester.stub(prepare_deployment_manifest: manifest)
    end

    context 'when the job is in the manifest' do
      it 'should return true if only one instance of job in deployment' do
        expect(tester.job_unique_in_deployment?('job1')).to be_true
      end

      it 'should return false if more than one instance of job in deployment' do
        expect(tester.job_unique_in_deployment?('job2')).to be_false
      end
    end

    context 'when the job is not in the manifest' do
      it 'should return false' do
        expect(tester.job_unique_in_deployment?('job3')).to be_false
      end
    end
  end

  describe 'jobs_and_indexes' do
    let(:manifest) do
      {
          'name' => 'mycloud',
          'jobs' => [
              {
                  'name' => 'job1',
                  'instances' => 1
              },
              {
                  'name' => 'job2',
                  'instances' => 2
              }
          ]
      }
    end

    before do
      tester.stub(prepare_deployment_manifest: manifest)
    end

    it 'returns array of ["job", index]' do
      tester.jobs_and_indexes.should == [["job1", 0], ["job2", 0], ["job2", 1]]
    end
  end
end