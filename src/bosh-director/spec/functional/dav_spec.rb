require 'bosh/dev/sandbox/nginx'
require 'bosh/dev/sandbox/service'
require 'bosh/dev/sandbox/socket_connector'
require 'logging'
require 'bosh/director'
require_relative 'blobstore_shared_examples'

module Bosh::Blobstore
  describe DavcliBlobstoreClient, davcli_integration: true do
    def create_user_file(users)
      temp = Tempfile.new('users')
      users.each { |u, p| temp.write("#{u}:{PLAIN}#{p}\n") }
      temp.flush
      FileUtils.chmod(0666, temp.path)
      temp
    end

    def create_test_blob
      FileUtils.mkdir_p(File.join(@root_dir, 'a9'))
      path = File.join(@root_dir, 'a9', 'test')
      File.open(path, 'w') do |f|
        f.write('test')
      end
      FileUtils.chmod(0666, path)
      FileUtils.chmod(0777, File.join(@root_dir, 'a9'))
      path
    end

    class NginxConfig < Struct.new(:port, :root, :read_users_path, :write_users_path)
      def asset(filename)
        File.expand_path(File.join(File.dirname(__FILE__), '..', 'assets', filename))
      end

      def erb_asset(filename, binding)
        file = Tempfile.new('erb_asset')
        file.write(ERB.new(File.read(asset(filename))).result(binding))
        file.flush
        file
      end

      def render
        erb_asset('nginx.conf.erb', binding)
      end
    end

    before(:all) do
      nginx_port = 20000
      @root_dir = Dir.mktmpdir
      FileUtils.chmod(0777, @root_dir)

      @read_users = create_user_file('agent' => 'agentpass', 'director' => 'directorpass')
      read_users_path = @read_users.to_path

      @write_users = create_user_file('director' => 'directorpass')
      write_users_path = @write_users.to_path

      nginx_config_file = NginxConfig.new(nginx_port, @root_dir, read_users_path, write_users_path).render

      logger = Logging.logger(STDOUT)
      nginx = Bosh::Dev::Sandbox::Nginx.new
      @nginx_process = Bosh::Dev::Sandbox::Service.new(%W[#{nginx.executable_path} -c #{nginx_config_file.path}], {}, logger)
      socket_connector = Bosh::Dev::Sandbox::SocketConnector.new('nginx', 'localhost', nginx_port, 'unknown', logger)

      @nginx_process.start
      socket_connector.try_to_connect

      nginx_pid = File.read(File.join(@root_dir, 'nginx.pid')).strip.to_i
      @nginx_process.pid = nginx_pid
    end

    after(:all) do
      @nginx_process.stop
      FileUtils.rm_rf(@root_dir)
      @read_users.close
      @write_users.close
      @read_users.unlink
      @write_users.unlink
    end

    before(:each) do
      @test_blob_path = create_test_blob
    end

    after(:each) do
      FileUtils.rm_rf(@test_blob_path)
    end

    let(:endpoint) { 'http://localhost:20000/' }

    let(:davcli_path) do
      Dir.glob(File.join(File.dirname(__FILE__), '../../../../blobs/davcli/', 'davcli-*-linux-amd64')).first
    end

    let(:dav_options) do
      {
        endpoint: endpoint,
        user: user,
        password: password,
        davcli_path: davcli_path,
      }
    end

    let(:dav) do
      Client.create('davcli', dav_options)
    end

    let(:logger) { Logging::Logger.new('test-logger') }

    before do
      allow(Bosh::Director::Config).to receive(:logger).and_return(logger)
    end

    context 'read users' do

      context 'with authorized user' do
        let(:user) { 'agent' }
        let(:password) { 'agentpass' }

        it 'allows read' do
          expect(dav.get('test')).to eq 'test'
        end

        it 'raises a NotFound error if the key does not exist' do
          expect { dav.get('nonexistent-key') }.to raise_error(Bosh::Blobstore::NotFound, /Blobstore object 'nonexistent-key' not found/)
        end

        it 'allows checking for existance' do
          expect(dav.exists?('test')).to be(true)
        end
      end

      context 'with unauthorized user' do
        let(:user) { 'foo' }
        let(:password) { 'bar' }

        it 'does not allow read' do
          expect { dav.get('test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Getting dav blob test: Request failed, response: Response{ StatusCode: 401, Status: '401 Unauthorized' }/)
        end

        it 'does not allow checking for existence' do
          expect { dav.exists?('test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Checking if dav blob test exists: Request failed, response: Response{ StatusCode: 401, Status: '401 Unauthorized' }/)
        end
      end

    end

    context 'write users' do
      context 'with authorized user' do
        let(:user) { 'director' }
        let(:password) { 'directorpass' }

        it_behaves_like 'any blobstore client' do
          let(:blobstore) { Client.create('davcli', dav_options) }
        end
      end

      context 'with unauthorized user' do
        let(:user) { 'foo' }
        let(:password) { 'bar' }

        it 'does not allow write' do
          expect { dav.create('foo', 'test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Putting dav blob test: Request failed, response: Response{ StatusCode: 401, Status: '401 Unauthorized' }/)
        end

        it 'does not allow delete' do
          expect { dav.delete('test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Deleting blob 'test': Request failed, response: Response{ StatusCode: 401, Status: '401 Unauthorized' }/)
        end

        it 'does not allow checking for existence' do
          expect { dav.exists?('test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Checking if dav blob test exists: Request failed, response: Response{ StatusCode: 401, Status: '401 Unauthorized' }/)
        end
      end

      context 'with read only user' do
        let(:user) { 'agent' }
        let(:password) { 'agentpass' }

        it 'does not allow write' do
          expect { dav.create('foo', 'test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Putting dav blob test: Request failed, response: Response{ StatusCode: 401, Status: '401 Unauthorized' }/)
        end

        it 'does not allow delete' do
          expect { dav.delete('test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Deleting blob 'test': Request failed, response: Response{ StatusCode: 401, Status: '401 Unauthorized' }/)
        end
      end
    end
  end
end
