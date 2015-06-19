require 'spec_helper'

describe Bosh::Cli::Command::Base do
  let(:config_file) { File.join(tmpdir, 'bosh_config') }
  let(:options) { {:config => config_file } }
  let(:tmpdir) { Dir.mktmpdir }

  before :each do
    @config = config_file
    @director = double(Bosh::Cli::Client::Director)
    allow(Bosh::Cli::Client::Director).to receive(:new).and_return(@director)
    allow(@director).to receive(:get_status).and_return('name' => 'ZB')
    allow(misc_cmd).to receive(:show_current_state)
  end

  def misc_cmd
    cmd = Bosh::Cli::Command::Misc.new
    options.each { |k, v| cmd.add_option(k, v) }
    cmd
  end

  def login_cmd
    cmd = Bosh::Cli::Command::Login.new
    options.each { |k, v| cmd.add_option(k, v) }
    cmd
  end

  describe Bosh::Cli::Command::Misc do
    context 'in non_interactive mode' do
      before(:each) { options[:non_interactive] = true }

      it 'uses NonInteractiveProgressRenderer' do
        expect(misc_cmd.progress_renderer).to be_a(Bosh::Cli::NonInteractiveProgressRenderer)
      end

      it 'sets the target' do
        expect(misc_cmd.target).to be_nil
        misc_cmd.set_target('http://example.com:232')
        expect(misc_cmd.target).to eq('http://example.com:232')
      end

      it 'normalizes target' do
        expect(misc_cmd.target).to be_nil
        misc_cmd.set_target('test')
        expect(misc_cmd.target).to eq('https://test:25555')
      end

      it 'handles director errors when setting target' do
        expect(@director).to receive(:get_status).and_raise(Bosh::Cli::DirectorError)

        expect {
          misc_cmd.set_target('test')
        }.to raise_error(Bosh::Cli::CliError, /cannot talk to director/i)

        expect(misc_cmd.target).to be_nil
      end

      it 'sets target' do
        misc_cmd.set_target('test')
        expect(misc_cmd.target).to eq('https://test:25555')
      end

      it 'supports named targets' do
        misc_cmd.set_target('test', 'mytarget')
        expect(misc_cmd.target).to eq('https://test:25555')

        misc_cmd.set_target('mytarget')
        expect(misc_cmd.target).to eq('https://test:25555')

        misc_cmd.set_target('foo', 'myfoo')
        expect(misc_cmd.target).to eq('https://foo:25555')

        misc_cmd.set_target('myfoo')
        expect(misc_cmd.target).to eq('https://foo:25555')
      end
    end

    context 'in interactive mode' do
      before :each do
        misc_cmd.add_option(:non_interactive, false)
      end

      it 'uses InteractiveProgressRenderer' do
        misc_cmd.add_option(:non_interactive, false)
        expect(misc_cmd.progress_renderer).to be_a(Bosh::Cli::InteractiveProgressRenderer)
      end
    end
  end

  describe Bosh::Cli::Command::Login do
    context 'in non_interactive mode' do
      before(:each) { options[:non_interactive] = true }

      it 'logs user in' do
        expect(@director).to receive(:login).with('user', 'pass') { true }
        misc_cmd.set_target('test')

        login_cmd.login('user', 'pass')

        expect(misc_cmd.logged_in?).to be(true)
        expect(misc_cmd.credentials.authorization_header).to eq('Basic dXNlcjpwYXNz')
      end

      it 'saves strings, not HighLine::String objects in the config' do
        expect(@director).to receive(:login).with('user', 'pass') { true }
        misc_cmd.set_target('test')

        login_cmd.login(HighLine::String.new('user'), HighLine::String.new('pass'))

        expect(misc_cmd.logged_in?).to be(true)
        expect(misc_cmd.credentials.authorization_header).to eq('Basic dXNlcjpwYXNz')
        config_file = File.read(File.expand_path(@config))
        expect(config_file).not_to match /HighLine::String/
        expect(config_file).to include('username: user')
        expect(config_file).to include('password: pass')
      end

      it 'logs user out' do
        misc_cmd.set_target('test')
        expect(@director).to receive(:login).with('user', 'pass') { true }
        login_cmd.login('user', 'pass')
        login_cmd.logout
        expect(misc_cmd.logged_in?).to be(false)
      end

      it 'respects director checks option when logging in' do
        misc_cmd.set_target('test')
        expect(@director).to receive(:login).with('user', 'pass') { true }
        login_cmd.login('user', 'pass')
        expect(misc_cmd.logged_in?).to be(true)
        expect(misc_cmd.credentials.authorization_header).to eq('Basic dXNlcjpwYXNz')
      end
    end
  end

  describe Bosh::Cli::Command::Stemcell do
    before :each do
      @director = double(Bosh::Cli::Client::Director)
      allow(@director).to receive(:list_stemcells).
          and_return([{'name' => 'foo', 'version' => '123'}])
      expect(@director).to receive(:list_stemcells)

      @cmd = Bosh::Cli::Command::Stemcell.new
      @cmd.add_option(:non_interactive, true)

      allow(@cmd).to receive(:target).and_return('test')
      allow(@cmd).to receive(:username).and_return('user')
      allow(@cmd).to receive(:password).and_return('pass')
      allow(@cmd).to receive(:director).and_return(@director)
    end

    it 'allows deleting the stemcell' do
      expect(@director).to receive(:delete_stemcell).with('foo', '123', :force => false)
      @cmd.delete('foo', '123')
    end

    it 'allows deleting a stemcell with force' do
      expect(@director).to receive(:delete_stemcell).with('foo', '123', :force => true)
      @cmd.add_option(:force, true)
      @cmd.delete('foo', '123')
    end

    it 'needs confirmation to delete stemcell' do
      @cmd.remove_option(:non_interactive)
      expect(@director).not_to receive(:delete_stemcell)

      allow(@cmd).to receive(:ask).and_return('')
      @cmd.delete('foo', '123')
    end

    it 'raises error when deleting if stemcell does not exist' do
      expect(@director).not_to receive(:delete_stemcell)

      @cmd.add_option(:non_interactive, true)
      expect {
        @cmd.delete('foo', '111')
      }.to raise_error(Bosh::Cli::CliError,
                           "Stemcell `foo/111' does not exist")
    end
  end

  describe Bosh::Cli::Command::Release::DeleteRelease do
    before do
      @director = instance_double('Bosh::Cli::Client::Director')

      @cmd = Bosh::Cli::Command::Release::DeleteRelease.new
      @cmd.add_option(:non_interactive, true)

      allow(@cmd).to receive(:target).and_return('test')
      allow(@cmd).to receive(:username).and_return('user')
      allow(@cmd).to receive(:password).and_return('pass')
      allow(@cmd).to receive(:director).and_return(@director)
    end

    it 'allows deleting the release (non-force)' do
      expect(@director).to receive(:delete_release).
          with('foo', :force => false, :version => nil)

      @cmd.delete('foo')
    end

    it 'allows deleting the release (force)' do
      expect(@director).to receive(:delete_release).
          with('foo', :force => true, :version => nil)

      @cmd.add_option(:force, true)
      @cmd.delete('foo')
    end

    it 'allows deleting a particular release version (non-force)' do
      expect(@director).to receive(:delete_release).
          with('foo', :force => false, :version => '42')

      @cmd.delete('foo', '42')
    end

    it 'allows deleting a particular release version (force)' do
      expect(@director).to receive(:delete_release).
          with('foo', :force => true, :version => '42')

      @cmd.add_option(:force, true)
      @cmd.delete('foo', '42')
    end

    it 'requires confirmation on deleting release' do
      expect(@director).not_to receive(:delete_release)
      @cmd.remove_option(:non_interactive)

      allow(@cmd).to receive(:ask).and_return('')
      @cmd.delete('foo')
    end
  end

  describe Bosh::Cli::Command::Release::ListReleases do
    before do
      @director = instance_double('Bosh::Cli::Client::Director')

      @cmd = Bosh::Cli::Command::Release::ListReleases.new
      @cmd.add_option(:non_interactive, true)

      allow(@cmd).to receive(:target).and_return('test')
      allow(@cmd).to receive(:username).and_return('user')
      allow(@cmd).to receive(:password).and_return('pass')
      allow(@cmd).to receive(:director).and_return(@director)
    end

    describe 'listing releases' do
      before do
        allow(@cmd).to receive :nl
        allow(@cmd).to receive(:show_current_state)
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
          allow(@director).to receive_messages(list_releases: [release])

          expect(@cmd).to receive(:say).with(releases_table)
          expect(@cmd).to receive(:say).with('(*) Currently deployed')
          expect(@cmd).to receive(:say).with('Releases total: 1')

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
          allow(@director).to receive_messages(list_releases: [release])

          expect(@cmd).to receive(:say).with(releases_table)
          expect(@cmd).to receive(:say).with('(*) Currently deployed')
          expect(@cmd).to receive(:say).with('(+) Uncommitted changes')
          expect(@cmd).to receive(:say).with('Releases total: 1')

          @cmd.list
        end

        it 'lists releases in a nice table and includes job names if available' do
          allow(@director).to receive_messages(list_releases: [release])

          expect(@cmd).to receive(:say).with(releases_with_jobs_table)
          expect(@cmd).to receive(:say).with('(*) Currently deployed')
          expect(@cmd).to receive(:say).with('(+) Uncommitted changes')
          expect(@cmd).to receive(:say).with('Releases total: 1')

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

      expect(@cmd).to receive(:check_if_release_dir)
      allow(Bosh::Cli::Release).to receive(:new).and_return(@release)
      allow(Bosh::Cli::BlobManager).to receive(:new).with(@release, kind_of(Integer), kind_of(Bosh::Cli::NonInteractiveProgressRenderer)).
          and_return(@blob_manager)
    end

    it 'prints blobs status' do
      expect(@blob_manager).to receive(:print_status)
      @cmd.status
    end

    it 'adds blob under provided directory' do
      expect(@blob_manager).to receive(:add_blob).with('foo/bar.tgz', 'bar/bar.tgz')
      @cmd.add('foo/bar.tgz', 'bar')
    end

    it 'adds blob with no directory provided' do
      expect(@blob_manager).to receive(:add_blob).with('foo/bar.tgz', 'bar.tgz')
      @cmd.add('foo/bar.tgz')
    end

    it 'uploads blobs' do
      expect(@blob_manager).to receive(:print_status)
      allow(@blob_manager).to receive(:blobs_to_upload).and_return(%w(foo bar baz))
      expect(@blob_manager).to receive(:upload_blob).with('foo')
      expect(@blob_manager).to receive(:upload_blob).with('bar')
      expect(@blob_manager).to receive(:upload_blob).with('baz')

      expect(@cmd).to receive(:confirmed?).exactly(3).times.and_return(true)
      @cmd.upload
    end

    it 'syncs blobs' do
      expect(@blob_manager).to receive(:sync).ordered
      expect(@blob_manager).to receive(:print_status).ordered
      @cmd.sync
    end
  end
end
