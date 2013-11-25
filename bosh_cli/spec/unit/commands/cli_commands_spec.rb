# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::Cli::Command::Base do

  before :each do
    tmpdir = Dir.mktmpdir
    @config = File.join(tmpdir, 'bosh_config')
    @director = double(Bosh::Cli::Client::Director)
    Bosh::Cli::Client::Director.stub(:new).and_return(@director)
    @director.stub(:get_status).and_return('name' => 'ZB')
  end

  describe Bosh::Cli::Command::Misc do

    before :each do
      @cmd = Bosh::Cli::Command::Misc.new
      @cmd.add_option(:config, @config)
      @cmd.add_option(:non_interactive, true)
    end

    it 'sets the target' do
      @cmd.target.should be_nil
      @cmd.set_target('http://example.com:232')
      @cmd.target.should == 'http://example.com:232'
    end

    it 'normalizes target' do
      @cmd.target.should be_nil
      @cmd.set_target('test')
      @cmd.target.should == 'https://test:25555'
    end

    it 'handles director errors when setting target' do
      @director.should_receive(:get_status).and_raise(Bosh::Cli::DirectorError)

      lambda {
        @cmd.set_target('test')
      }.should raise_error(Bosh::Cli::CliError, /cannot talk to director/i)

      @cmd.target.should be_nil
    end

    it 'sets target' do
      @cmd.set_target('test')
      @cmd.target.should == 'https://test:25555'
    end

    it 'supports named targets' do
      @cmd.set_target('test', 'mytarget')
      @cmd.target.should == 'https://test:25555'

      @cmd.set_target('foo', 'myfoo')

      @cmd.set_target('mytarget')
      @cmd.target.should == 'https://test:25555'

      @cmd.set_target('myfoo')
      @cmd.target.should == 'https://foo:25555'
    end

    it 'logs user in' do
      @director.should_receive(:authenticated?).and_return(true)
      @director.should_receive(:user=).with('user')
      @director.should_receive(:password=).with('pass')
      @cmd.set_target('test')
      @cmd.login('user', 'pass')
      @cmd.logged_in?.should be(true)
      @cmd.username.should == 'user'
      @cmd.password.should == 'pass'
    end

    it 'logs user in with highline' do
      @director.should_receive(:authenticated?).and_return(true)
      @director.should_receive(:user=).with('user')
      @director.should_receive(:password=).with('pass')
      @cmd.set_target('test')
      @cmd.login(HighLine::String.new('user'), HighLine::String.new('pass'))
      @cmd.logged_in?.should be(true)
      @cmd.username.should == 'user'
      @cmd.password.should == 'pass'
      config_file = File.read(File.expand_path(@config))
      config_file.should_not match /HighLine::String/
      config_file.should include('username: user')
      config_file.should include('password: pass')
    end

    it 'logs user out' do
      @cmd.set_target('test')
      @director.should_receive(:authenticated?).and_return(true)
      @director.should_receive(:user=).with('user')
      @director.should_receive(:password=).with('pass')
      @cmd.login('user', 'pass')
      @cmd.logout
      @cmd.logged_in?.should be(false)
    end

    it 'respects director checks option when logging in' do
      @director.stub(:get_status).
          and_return({'user' => 'user', 'name' => 'ZB'})
      @director.stub(:authenticated?).and_return(true)

      @cmd.set_target('test')
      @director.should_receive(:user=).with('user')
      @director.should_receive(:password=).with('pass')
      @cmd.login('user', 'pass')
      @cmd.logged_in?.should be(true)
      @cmd.username.should == 'user'
      @cmd.password.should == 'pass'
    end
  end

  describe Bosh::Cli::Command::Stemcell do
    before :each do
      @director = double(Bosh::Cli::Client::Director)
      @director.stub(:list_stemcells).
          and_return([{'name' => 'foo', 'version' => '123'}])
      @director.should_receive(:list_stemcells)

      @cmd = Bosh::Cli::Command::Stemcell.new
      @cmd.add_option(:non_interactive, true)

      @cmd.stub(:target).and_return('test')
      @cmd.stub(:username).and_return('user')
      @cmd.stub(:password).and_return('pass')
      @cmd.stub(:director).and_return(@director)
    end

    it 'allows deleting the stemcell' do
      @director.should_receive(:delete_stemcell).with('foo', '123', :force => false)
      @cmd.delete('foo', '123')
    end

    it 'allows deleting a stemcell with force' do
      @director.should_receive(:delete_stemcell).with('foo', '123', :force => true)
      @cmd.add_option(:force, true)
      @cmd.delete('foo', '123')
    end

    it 'needs confirmation to delete stemcell' do
      @cmd.remove_option(:non_interactive)
      @director.should_not_receive(:delete_stemcell)

      @cmd.stub(:ask).and_return('')
      @cmd.delete('foo', '123')
    end

    it 'raises error when deleting if stemcell does not exist' do
      @director.should_not_receive(:delete_stemcell)

      @cmd.add_option(:non_interactive, true)
      lambda {
        @cmd.delete('foo', '111')
      }.should raise_error(Bosh::Cli::CliError,
                           "Stemcell `foo/111' does not exist")
    end
  end

  describe Bosh::Cli::Command::Release do
    before :each do
      @director = double(Bosh::Cli::Client::Director)

      @cmd = Bosh::Cli::Command::Release.new
      @cmd.add_option(:non_interactive, true)

      @cmd.stub(:target).and_return('test')
      @cmd.stub(:username).and_return('user')
      @cmd.stub(:password).and_return('pass')
      @cmd.stub(:director).and_return(@director)
    end

    it 'allows deleting the release (non-force)' do
      @director.should_receive(:delete_release).
          with('foo', :force => false, :version => nil)

      @cmd.delete('foo')
    end

    it 'allows deleting the release (force)' do
      @director.should_receive(:delete_release).
          with('foo', :force => true, :version => nil)

      @cmd.add_option(:force, true)
      @cmd.delete('foo')
    end

    it 'allows deleting a particular release version (non-force)' do
      @director.should_receive(:delete_release).
          with('foo', :force => false, :version => '42')

      @cmd.delete('foo', '42')
    end

    it 'allows deleting a particular release version (force)' do
      @director.should_receive(:delete_release).
          with('foo', :force => true, :version => '42')

      @cmd.add_option(:force, true)
      @cmd.delete('foo', '42')
    end

    it 'requires confirmation on deleting release' do
      @director.should_not_receive(:delete_release)
      @cmd.remove_option(:non_interactive)

      @cmd.stub(:ask).and_return('')
      @cmd.delete('foo')
    end

    describe 'listing releases' do
      before do
        @cmd.stub :nl
      end

      context "when the director doesn't include commit hash information (version < 1.5)" do
        let(:release) do
          {
              'name' => 'release-1',
              'versions' => ['2.1-dev', '15', '2', '1'],
              'in_use' => ['2.1-dev']
          }
        end

        let(:releases_table) do
          <<-OUT.gsub(/^\s*/, '').chomp
      +-----------+--------------------+
      | Name      | Versions           |
      +-----------+--------------------+
      | release-1 | 1, 2, 2.1-dev*, 15 |
      +-----------+--------------------+
          OUT
        end

        it 'lists releases in a nice table and include information about current deployments' do
          @director.stub(list_releases: [release])

          @cmd.should_receive(:say).with(releases_table)
          @cmd.should_receive(:say).with('(*) Currently deployed')
          @cmd.should_receive(:say).with('Releases total: 1')

          @cmd.list
        end
      end

      context 'when the director includes commit hash information (version >= 1.5)' do
        let(:release) do
          {
              'name' => 'release-1',
              'release_versions' => [
                  {'version' => '2.1-dev', 'commit_hash' => 'unknown', 'uncommitted_changes' => false, 'currently_deployed' => true, 'job_names' => ['job-1']},
                  {'version' => '15', 'commit_hash' => '1a2b3c4d', 'uncommitted_changes' => true, 'currently_deployed' => false, 'job_names' => ['job-1']},
                  {'version' => '2', 'commit_hash' => '00000000', 'uncommitted_changes' => true, 'currently_deployed' => false, 'job_names' => ['job-1']},
                  {'version' => '1', 'commit_hash' => 'unknown', 'uncommitted_changes' => false, 'currently_deployed' => false}
              ]
          }
        end

        let(:releases_table) do
          <<-OUT.gsub(/^\s*/, '').chomp
      +-----------+----------+-------------+
      | Name      | Versions | Commit Hash |
      +-----------+----------+-------------+
      | release-1 | 1        | unknown     |
      |           | 2        | 00000000+   |
      |           | 2.1-dev* | unknown     |
      |           | 15       | 1a2b3c4d+   |
      +-----------+----------+-------------+
          OUT
        end

        let(:releases_with_jobs_table) do
          <<-OUT.gsub(/^\s*/, '').chomp
      +-----------+----------+-------------+-------+
      | Name      | Versions | Commit Hash | Jobs  |
      +-----------+----------+-------------+-------+
      | release-1 | 1        | unknown     | n/a   |
      |           | 2        | 00000000+   | job-1 |
      |           | 2.1-dev* | unknown     | job-1 |
      |           | 15       | 1a2b3c4d+   | job-1 |
      +-----------+----------+-------------+-------+
          OUT
        end

        it 'lists releases in a nice table and includes information about current deployments and uncommitted changes' do
          @director.stub(list_releases: [release])

          @cmd.should_receive(:say).with(releases_table)
          @cmd.should_receive(:say).with('(*) Currently deployed')
          @cmd.should_receive(:say).with('(+) Uncommitted changes')
          @cmd.should_receive(:say).with('Releases total: 1')

          @cmd.list
        end

        it 'lists releases in a nice table and includes job names if available' do
          @director.stub(list_releases: [release])

          @cmd.should_receive(:say).with(releases_with_jobs_table)
          @cmd.should_receive(:say).with('(*) Currently deployed')
          @cmd.should_receive(:say).with('(+) Uncommitted changes')
          @cmd.should_receive(:say).with('Releases total: 1')

          @cmd.add_option(:jobs, true)
          @cmd.list
        end
      end
    end
  end

  describe Bosh::Cli::Command::BlobManagement do
    before :each do
      @cmd = Bosh::Cli::Command::BlobManagement.new
      @cmd.add_option(:non_interactive, true)

      @blob_manager = double('blob manager')
      @release = double('release')

      @cmd.should_receive(:check_if_release_dir)
      Bosh::Cli::Release.stub(:new).and_return(@release)
      Bosh::Cli::BlobManager.stub(:new).with(@release).
          and_return(@blob_manager)
    end

    it 'prints blobs status' do
      @blob_manager.should_receive(:print_status)
      @cmd.status
    end

    it 'adds blob under provided directory' do
      @blob_manager.should_receive(:add_blob).with('foo/bar.tgz', 'bar/bar.tgz')
      @cmd.add('foo/bar.tgz', 'bar')
    end

    it 'adds blob with no directory provided' do
      @blob_manager.should_receive(:add_blob).with('foo/bar.tgz', 'bar.tgz')
      @cmd.add('foo/bar.tgz')
    end

    it 'uploads blobs' do
      @blob_manager.should_receive(:print_status)
      @blob_manager.stub(:blobs_to_upload).and_return(%w(foo bar baz))
      @blob_manager.should_receive(:upload_blob).with('foo')
      @blob_manager.should_receive(:upload_blob).with('bar')
      @blob_manager.should_receive(:upload_blob).with('baz')

      @cmd.should_receive(:confirmed?).exactly(3).times.and_return(true)
      @cmd.upload
    end

    it 'syncs blobs' do
      @blob_manager.should_receive(:sync).ordered
      @blob_manager.should_receive(:print_status).ordered
      @cmd.sync
    end
  end
end
