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
    expect(cmd.username).to be_nil
    expect(cmd.password).to be_nil
  end

  it 'respects target option' do
    add_config('target' => 'localhost:8080', 'target_name' => 'microbosh')

    cmd = make
    cmd.add_option(:target, 'new-target')

    expect(cmd.target).to eq('https://new-target:25555')
    expect(cmd.target_name).to eq('new-target')
  end

  it 'looks up target, deployment and credentials in the right order' do
    cmd = make

    expect(cmd.username).to be_nil
    expect(cmd.password).to be_nil
    old_user = ENV['BOSH_USER']
    old_password = ENV['BOSH_PASSWORD']

    begin
      ENV['BOSH_USER'] = 'foo'
      ENV['BOSH_PASSWORD'] = 'bar'
      expect(cmd.username).to eq('foo')
      expect(cmd.password).to eq('bar')
      other_cmd = make
      other_cmd.add_option(:username, 'new')
      other_cmd.add_option(:password, 'baz')

      expect(other_cmd.username).to eq('new')
      expect(other_cmd.password).to eq('baz')
    ensure
      ENV['BOSH_USER'] = old_user
      ENV['BOSH_PASSWORD'] = old_password
    end

    add_config('target' => 'localhost:8080', 'deployment' => 'test')

    cmd2 = make
    cmd2.add_option(:target, 'foo')
    cmd2.add_option(:deployment, 'bar')
    expect(cmd2.target).to eq('https://foo:25555')
    expect(cmd2.deployment).to eq('bar')
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
end
