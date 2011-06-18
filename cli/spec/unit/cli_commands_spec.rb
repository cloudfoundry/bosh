require "spec_helper"

describe Bosh::Cli::Command::Base do

  before :each do
    @config = File.join(Dir.mktmpdir, "bosh_config")
    @cache  = File.join(Dir.mktmpdir, "bosh_cache")
    @opts   = { :config => @config, :cache_dir => @cache }
  end

  describe Bosh::Cli::Command::Misc do

    before :each do
      @cmd = Bosh::Cli::Command::Misc.new(@opts)
      @cmd.stub!(:interactive?).and_return(false)
    end

    it "sets the target" do
      @cmd.target.should == nil
      @cmd.set_target("http://example.com:232")
      @cmd.target.should == "http://example.com:232"
    end

    it "normalizes target" do
      @cmd.target.should == nil
      @cmd.set_target("test")
      @cmd.target.should == "http://test"
    end

    it "respects director checks option when setting target" do
      @cmd.options[:director_checks] = true

      lambda {
        mock_director = mock(Object)
        mock_director.stub!(:get_status).and_raise(Bosh::Cli::DirectorError)
        Bosh::Cli::Director.should_receive(:new).with("http://test").and_return(mock_director)
        @cmd.set_target("test")
      }.should raise_error(Bosh::Cli::CliExit, "Cannot talk to director at 'http://test', please set correct target")

      @cmd.target.should == nil

      mock_director = mock(Object)
      mock_director.stub!(:get_status).and_return("name" => "ZB")
      Bosh::Cli::Director.should_receive(:new).with("http://test").and_return(mock_director)
      @cmd.set_target("test")
      @cmd.target.should == "http://test"
    end

    it "supports named targets" do
      @cmd.set_target("test", "mytarget")
      @cmd.target.should == "http://test"

      @cmd.set_target("foo", "myfoo")

      @cmd.set_target("mytarget")
      @cmd.target.should == "http://test"

      @cmd.set_target("myfoo")
      @cmd.target.should == "http://foo"
    end

    it "logs user in" do
      @cmd.set_target("test")
      @cmd.login("user", "pass")
      @cmd.logged_in?.should be_true
      @cmd.username.should == "user"
      @cmd.password.should == "pass"
    end

    it "logs user out" do
      @cmd.set_target("test")
      @cmd.login("user", "pass")
      @cmd.logout
      @cmd.logged_in?.should be_false
    end

    it "respects director checks option when logging in" do
      @cmd.options[:director_checks] = true

      mock_director = mock(Object)
      mock_director.stub(:get_status).and_return({ "user" => "user", "name" => "ZB" })
      mock_director.stub(:authenticated?).and_return(true)

      Bosh::Cli::Director.should_receive(:new).with("http://test").and_return(mock_director)
      @cmd.set_target("test")

      Bosh::Cli::Director.should_receive(:new).with("http://test", "user", "pass").and_return(mock_director)

      @cmd.login("user", "pass")
      @cmd.logged_in?.should be_true
      @cmd.username.should == "user"
      @cmd.password.should == "pass"
    end
  end

  describe Bosh::Cli::Command::Stemcell do
    before :each do
      @cmd = Bosh::Cli::Command::Stemcell.new(@opts)
    end

    it "allows deleting the stemcell" do
      mock_director = mock(Bosh::Cli::Director)
      mock_director.should_receive(:delete_stemcell).with("foo", "123")

      @cmd.stub!(:interactive?).and_return(false)
      @cmd.stub!(:target).and_return("test")
      @cmd.stub!(:username).and_return("user")
      @cmd.stub!(:password).and_return("pass")
      @cmd.stub!(:director).and_return(mock_director)
      @cmd.delete("foo", "123")
    end

    it "needs confirmation to delete stemcell" do
      mock_director = mock(Bosh::Cli::Director)
      mock_director.should_not_receive(:delete_stemcell)

      @cmd.stub!(:target).and_return("test")
      @cmd.stub!(:username).and_return("user")
      @cmd.stub!(:password).and_return("pass")
      @cmd.stub!(:director).and_return(mock_director)
      @cmd.stub!(:ask).and_return("")
      @cmd.delete("foo", "123")
    end
  end

  describe Bosh::Cli::Command::Deployment do
    before :each do
      @cmd = Bosh::Cli::Command::Deployment.new(@opts)
    end

    it "allows deleting the deployment" do
      mock_director = mock(Bosh::Cli::Director)
      mock_director.should_receive(:delete_deployment).with("foo")

      @cmd.stub!(:interactive?).and_return(false)
      @cmd.stub!(:target).and_return("test")
      @cmd.stub!(:username).and_return("user")
      @cmd.stub!(:password).and_return("pass")
      @cmd.stub!(:director).and_return(mock_director)
      @cmd.delete("foo")
    end

    it "needs confirmation to delete deployment" do
      mock_director = mock(Bosh::Cli::Director)
      mock_director.should_not_receive(:delete_deployment)

      @cmd.stub!(:target).and_return("test")
      @cmd.stub!(:username).and_return("user")
      @cmd.stub!(:password).and_return("pass")
      @cmd.stub!(:director).and_return(mock_director)
      @cmd.stub!(:ask).and_return("")
      @cmd.delete("foo")
    end
  end

  describe Bosh::Cli::Command::Release do
    before :each do
      @cmd = Bosh::Cli::Command::Release.new(@opts)
      @cmd.stub!(:target).and_return("test")
      @cmd.stub!(:username).and_return("user")
      @cmd.stub!(:password).and_return("pass")
    end

    it "allows deleting the release (non-force)" do
      mock_director = mock(Bosh::Cli::Director)
      mock_director.should_receive(:delete_release).with("foo", :force => false, :version => nil)

      @cmd.stub!(:interactive?).and_return(false)
      @cmd.stub!(:director).and_return(mock_director)
      @cmd.delete("foo")
    end

    it "allows deleting the release (non-force)" do
      mock_director = mock(Bosh::Cli::Director)
      mock_director.should_receive(:delete_release).with("foo", :force => true, :version => nil)

      @cmd.stub!(:ask).and_return("yes")
      @cmd.stub!(:director).and_return(mock_director)
      @cmd.delete("foo", "--force")
    end

    it "allows deleting a particular release version (non-force)" do
      mock_director = mock(Bosh::Cli::Director)
      mock_director.should_receive(:delete_release).with("foo", :force => false, :version => "42")

      @cmd.stub!(:ask).and_return("yes")
      @cmd.stub!(:director).and_return(mock_director)
      @cmd.delete("foo", "42")
    end

    it "allows deleting a particular release version (non-force)" do
      mock_director = mock(Bosh::Cli::Director)
      mock_director.should_receive(:delete_release).with("foo", :force => true, :version => "42")

      @cmd.stub!(:ask).and_return("yes")
      @cmd.stub!(:director).and_return(mock_director)
      @cmd.delete("foo", "42", "--force")
    end

    it "requires confirmation on deleting release" do
      mock_director = mock(Bosh::Cli::Director)
      mock_director.should_not_receive(:delete_release)
      @cmd.stub!(:director).and_return(mock_director)
      @cmd.stub!(:ask).and_return("")
      @cmd.delete("foo")
    end

  end

end


