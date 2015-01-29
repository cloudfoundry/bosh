require 'spec_helper'

describe Bosh::Cli::Command::Deployment do
  let(:director) { double(Bosh::Cli::Client::Director) }
  let(:cmd) { described_class.new(nil, director) }
  let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }

  before :each do
    cmd.add_option(:non_interactive, true)
    cmd.add_option(:target, 'test')
    cmd.add_option(:username, 'user')
    cmd.add_option(:password, 'pass')
  end

  after do
    release_source.cleanup
  end

  it 'allows deleting the deployment' do
    expect(director).to receive(:delete_deployment).with('foo', force: false)

    cmd.delete('foo')
  end

  it 'needs confirmation to delete deployment' do
    expect(director).not_to receive(:delete_deployment)
    expect(cmd).to receive(:ask)

    cmd.remove_option(:non_interactive)
    cmd.delete('foo')
  end

  it "lists deployments and doesn't fetch manifest on new director" do
    expect(director).to receive(:list_deployments).
      and_return([{ 'name' => 'foo', 'releases' => [], 'stemcells' => [] }])
    expect(director).not_to receive(:get_deployment)

    cmd.list
  end

  it 'lists deployments and fetches manifest on old director' do
    expect(director).to receive(:list_deployments).and_return([{ 'name' => 'foo' }])
    expect(director).to receive(:get_deployment).with('foo').and_return({})

    cmd.list
  end

  describe 'bosh validate jobs' do
    let(:manifest) do
      {
        'name' => 'example',
        'release' => {
          'name' => 'sample-release',
          'version' => 'latest'
        },
        'jobs' => [
          {
            'name' => 'sample-job',
            'template' => []
          }
        ],
        'properties' => {}
      }
    end

    before do
      release_source.add_dir('jobs')
      release_source.add_dir('packages')
      release_source.add_dir('src')
      release_source.add_dir('config')
    end

    it 'does not raise with a dummy manifest' do
      # NOTE: the point is to add coverage to catch
      # the signature change to Package.discover
      release = double('release')
      allow(release).to receive(:dev_name).and_return('sample-release')

      allow(cmd).to receive(:prepare_deployment_manifest).and_return(manifest)
      allow(cmd).to receive(:work_dir).and_return(release_source.path)
      allow(cmd).to receive(:release).and_return(release)

      Dir.chdir(release_source.path) do
        cmd.validate_jobs
      end
    end
  end
end
