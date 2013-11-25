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
    cmd.config.should be_a(Bosh::Cli::Config)

    cmd.target.should == 'https://localhost:8080'
    cmd.target_name.should == 'microbosh'
    cmd.deployment.should == 'test'
    cmd.username.should be_nil
    cmd.password.should be_nil
  end

  it 'respects target option' do
    add_config('target' => 'localhost:8080', 'target_name' => 'microbosh')

    cmd = make
    cmd.add_option(:target, 'new-target')

    cmd.target.should == 'https://new-target:25555'
    cmd.target_name.should == 'new-target'
  end

  it 'looks up target, deployment and credentials in the right order' do
    cmd = make

    cmd.username.should be_nil
    cmd.password.should be_nil
    old_user = ENV['BOSH_USER']
    old_password = ENV['BOSH_PASSWORD']

    begin
      ENV['BOSH_USER'] = 'foo'
      ENV['BOSH_PASSWORD'] = 'bar'
      cmd.username.should == 'foo'
      cmd.password.should == 'bar'
      other_cmd = make
      other_cmd.add_option(:username, 'new')
      other_cmd.add_option(:password, 'baz')

      other_cmd.username.should == 'new'
      other_cmd.password.should == 'baz'
    ensure
      ENV['BOSH_USER'] = old_user
      ENV['BOSH_PASSWORD'] = old_password
    end

    add_config('target' => 'localhost:8080', 'deployment' => 'test')

    cmd2 = make
    cmd2.add_option(:target, 'foo')
    cmd2.add_option(:deployment, 'bar')
    cmd2.target.should == 'https://foo:25555'
    cmd2.deployment.should == 'bar'
  end

  it 'instantiates director when needed' do
    add_config('target' => 'localhost:8080', 'deployment' => 'test')

    cmd = make
    cmd.director.should be_kind_of(Bosh::Cli::Client::Director)
    cmd.director.director_uri.should == URI.parse('https://localhost:8080')
  end

  it 'has logged_in? helper' do
    cmd = make
    cmd.logged_in?.should be(false)
    cmd.add_option(:username, 'foo')
    cmd.logged_in?.should be(false)
    cmd.add_option(:password, 'bar')
    cmd.logged_in?.should be(true)
  end
end
