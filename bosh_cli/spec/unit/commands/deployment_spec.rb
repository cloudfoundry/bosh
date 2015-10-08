require 'spec_helper'

describe Bosh::Cli::Command::Deployment do
  let(:director) { double(Bosh::Cli::Client::Director) }
  let(:cmd) { described_class.new(nil, director) }
  let(:release_source) { Support::FileHelpers::ReleaseDirectory.new }

  before :each do
    target = 'https://127.0.0.1:8080'
    cmd.add_option(:non_interactive, true)
    cmd.add_option(:target, target)
    cmd.add_option(:username, 'user')
    cmd.add_option(:password, 'pass')

    stub_request(:get, "#{target}/info").to_return(body: '{}')
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

  it 'gracefully handles attempts to delete a non-existent deployment' do
    expect(director).to receive(:delete_deployment)
                          .with('foo', force: false)
                          .and_raise(Bosh::Cli::ResourceNotFound)
    expect {
      cmd.delete('foo')
    }.to_not raise_error
  end

  it 'lists deployments' do
    expect(director).to receive(:list_deployments).
      and_return([{ 'name' => 'foo', 'releases' => [], 'stemcells' => [] }])

    cmd.list
  end

  describe 'deployment' do
    before { @config = Support::TestConfig.new(cmd) }
    after { @config.clean }

    context 'when target is set' do
      before do
        allow(director).to receive(:get_status).and_return({'uuid' => 'director-uuid'})
        config = @config.load
        config.target = 'https://127.0.0.1:8080'
        config.set_alias('target', 'manifest-uuid', 'url-from-config')
        config.save_ca_cert_path('/ca-cert-path-from-config', 'url-from-config')
        config.save_ca_cert_path('/fake-ca-cert')
        config.save
      end

      let(:manifest_file) do
        manifest_file = File.join(Dir.mktmpdir, 'manifest')
        write_yaml({ 'director_uuid' => 'manifest-uuid' }, manifest_file)
        manifest_file
      end

      after { FileUtils.rm_rf(manifest_file) }

      context 'when current target uuid is not the same as the uuid in manifest' do
        let(:director) { instance_double(Bosh::Cli::Client::Director) }

        it 'changes current target and ca_cert' do
          expect(Bosh::Cli::Client::Director).to receive(:new).with(
              'https://127.0.0.1:8080',
              anything,
              ca_cert: '/fake-ca-cert'
            ).and_return(director).twice # 1 time to get auth info, 2 second to get uuid

          expect(Bosh::Cli::Client::Director).to receive(:new).with(
              'url-from-config',
              anything,
              ca_cert: '/ca-cert-path-from-config'
            ).and_return(director)

          cmd.set_current(manifest_file)
          config = @config.load
          expect(config.target).to eq('url-from-config')
          expect(config.ca_cert).to eq('/ca-cert-path-from-config')
        end
      end

      it 'sets deployment manifest' do
        allow(Bosh::Cli::Client::Director).to receive(:new).and_return(director)
        cmd.set_current(manifest_file)
        config = @config.load
        expect(config.deployment).to eq(manifest_file)
      end
    end
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
      cmd.options[:dir] = release_source.path
      allow(release).to receive(:dev_name).and_return('sample-release')

      allow(cmd).to receive(:prepare_deployment_manifest).and_return(double(:manifest, hash: manifest))
      allow(cmd).to receive(:release).and_return(release)

      Dir.chdir(release_source.path) do
        cmd.validate_jobs
      end
    end
  end

  describe 'deploy' do
    it 'returns error when release has version create but no url' do
      manifest = {
        'name' => 'example',
        'releases' => [
          {
            'name' => 'sample-release',
            'version' => 'create'
          }
        ],
        'jobs' => [],
        'properties' => {}
      }

      allow(cmd).to receive(:build_manifest).and_return(double(:manifest, hash: manifest))

      expect {
        cmd.perform
      }.to raise_error(Bosh::Cli::CliError, /Expected URL.*version.*create/)
    end
  end
end
