require 'spec_helper'

describe Bosh::Cli::Command::Base do
  before do
    @runner = double(Bosh::Cli::Runner)
    @config_file = File.join(Dir.mktmpdir, 'bosh_config')
  end

  def add_config(object)
    File.open(@config_file, 'w') do |f|
      f.write(Psych.dump(object))
    end
  end

  def make
    cmd = Bosh::Cli::Command::Base.new(@runner)
    cmd.add_option(:config, @config_file)
    cmd
  end

  it 'can access configuration and respects options' do
    add_config('target' => 'localhost:8080', 'target_name' => 'microbosh', 'deployment' => 'test')

    cmd = make
    expect(cmd.config).to be_a(Bosh::Cli::Config)

    expect(cmd.target).to eq('https://localhost:8080')
    expect(cmd.target_name).to eq('microbosh')
    expect(cmd.deployment).to eq('test')
    expect(cmd.credentials).to be_nil
  end

  it 'respects target option' do
    add_config('target' => 'localhost:8080', 'target_name' => 'microbosh')

    cmd = make
    cmd.add_option(:target, 'new-target')

    expect(cmd.target).to eq('https://new-target:25555')
    expect(cmd.target_name).to eq('new-target')
  end

  it 'instantiates director when needed' do
    add_config('target' => 'localhost:8080', 'deployment' => 'test')

    cmd = make
    expect(cmd.director).to be_kind_of(Bosh::Cli::Client::Director)
    expect(cmd.director.director_uri).to eq(URI.parse('https://localhost:8080'))
  end

  it 'has logged_in? helper' do
    cmd = make
    expect(cmd.logged_in?).to be(false)
    cmd.add_option(:username, 'foo')
    expect(cmd.logged_in?).to be(false)
    cmd.add_option(:password, 'bar')
    expect(cmd.logged_in?).to be(true)
  end

  it "gives the max_parallel_downloads options to the blob manager" do
    allow(Bosh::Cli::BlobManager).to receive(:new)
    max_parallel_downloads = double(:max_parallel_downloads)
    release = double(:release)
    Bosh::Cli::Config.max_parallel_downloads = max_parallel_downloads
    cmd = make
    allow(cmd).to receive(:release).and_return(release)

    cmd.blob_manager
    expect(Bosh::Cli::BlobManager).to have_received(:new).with(release, max_parallel_downloads, anything)
    Bosh::Cli::Config.max_parallel_downloads = nil
  end

  context 'target' do
    context 'when port 443 is specified' do
      it 'persists the port within the target' do
        cmd = make
        cmd.add_option(:target, 'https://foo:443')
        expect(cmd.target).to eq('https://foo:443')
      end
    end

    context 'when port 443 is specified' do
      it 'persists the port within the target' do
        cmd = make
        cmd.add_option(:target, 'https://foo:25555')
        expect(cmd.target).to eq('https://foo:25555')
      end
    end

    context 'when a trailing slash is provided' do
      it 'strips the trailing slash' do
        cmd = make
        cmd.add_option(:target, 'https://foo/')
        expect(cmd.target).to eq('https://foo:25555')
      end
    end

    context 'when no scheme is provided' do
      it 'adds https as the default scheme' do
        cmd = make
        cmd.add_option(:target, 'foo')
        expect(cmd.target).to eq('https://foo:25555')
      end
    end
  end

  describe 'cache_dir' do
    it 'defaults to $HOME/.bosh/cache' do
      allow(Dir).to receive(:home).and_return('/fake/home/dir')
      expect(make.cache_dir).to eq('/fake/home/dir/.bosh/cache')
    end
  end

  describe 'credentials' do
    context 'when config contains UAA token' do
      let(:cmd) do
        add_config(
          'target' => 'localhost:8080',
          'auth' => {
            'https://localhost:8080' => {
              'token' => 'bearer config-token',
            }
          })
        make
      end

      it 'returns UAA credentials' do
        expect(cmd.credentials.authorization_header).to eq('bearer config-token')
      end
    end

    context 'when config does not contain UAA token' do
      let(:cmd) do
        add_config(
          'target' => 'localhost:8080',
          'auth' => {
            'https://localhost:8080' => {
              'username' => 'config-username',
              'password' => 'config-password',
            }
          })
        make
      end

      let(:authorization_header) { 'Basic ' + Base64.encode64("#{expected_username}:#{expected_password}").strip }
      let(:expected_username) { 'config-username' }
      let(:expected_password) { 'config-password' }

      context 'when user provided username option' do
        let(:expected_username) { 'option-username' }
        before { cmd.add_option(:username, expected_username) }

        it 'returns basic credentials with provided username' do
          expect(cmd.credentials.authorization_header).to eq(authorization_header)
        end
      end

      context 'when user provided password option' do
        let(:expected_password) { 'option-password' }
        before { cmd.add_option(:password, expected_password) }

        it 'returns basic credentials with provided password' do
          expect(cmd.credentials.authorization_header).to eq(authorization_header)
        end
      end

      context 'when user provided BOSH_USER env variable' do
        let(:expected_username) { 'env-username' }
        before { stub_const('ENV', {'BOSH_USER' => 'env-username'}) }

        it 'returns basic credentials with provided username' do
          expect(cmd.credentials.authorization_header).to eq(authorization_header)
        end
      end

      context 'when user provided BOSH_PASSWORD env variable' do
        let(:expected_password) { 'env-password' }
        before { stub_const('ENV', {'BOSH_PASSWORD' => expected_password}) }

        it 'returns basic credentials with provided password' do
          expect(cmd.credentials.authorization_header).to eq(authorization_header)
        end
      end

      context 'when credentials are not provided in config' do
        let(:cmd) { make }
        it 'returns nil' do
          expect(cmd.credentials).to be_nil
        end
      end
    end
  end
end
