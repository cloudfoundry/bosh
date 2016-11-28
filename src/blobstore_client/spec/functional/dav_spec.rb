require 'bosh/dev/sandbox/nginx'
require 'bosh/dev/sandbox/service'
require 'bosh/dev/sandbox/socket_connector'
require 'spec_helper'
require 'logging'

describe Bosh::Blobstore::DavBlobstoreClient, nginx: true do
  def create_user_file(users)
    temp = Tempfile.new('users')
    users.each { |u, p| temp.write("#{u}:{PLAIN}#{p}\n") }
    temp.flush
    temp
  end

  def create_test_blob
    FileUtils.mkdir_p(File.join(@root_dir, 'a9'))
    path = File.join(@root_dir, 'a9', 'test')
    File.open(path, 'w') do |f|
      f.write('test')
    end

    path
  end

  class NginxConfig < Struct.new(:port, :root, :read_users_path, :write_users_path)
    def render
      erb_asset('nginx.conf.erb', binding)
    end
  end

  before(:all) do
    nginx_port = 20000
    @root_dir = Dir.mktmpdir

    read_users = create_user_file('agent' => 'agentpass', 'director' => 'directorpass')
    read_users_path = read_users.to_path

    write_users = create_user_file('director' => 'directorpass')
    write_users_path = write_users.to_path

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
  end

  before(:each) do
    @test_blob_path = create_test_blob
  end

  after(:each) do
    FileUtils.rm_rf(@test_blob_path)
  end

  let(:endpoint) { "http://localhost:20000/" }

  subject { described_class.new(user: user, password: password, endpoint: endpoint) }

  context 'read users' do

    context 'with authorized user' do
      let(:user) { 'agent' }
      let(:password) { 'agentpass' }

      it 'allows read' do
        expect(subject.get('test')).to eq 'test'
      end

      it 'allows checking for existance' do
        expect(subject.exists?('test')).to be(true)
      end
    end

    context 'with unauthorized user' do
      let(:user) { 'foo' }
      let(:password) { 'bar' }

      it "doesn't allow read" do
        expect { subject.get('test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Could not fetch object, 401/)
      end

      it 'does not allow checking for existance' do
        expect { subject.exists?('test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Could not get object existence, 401/)
      end
    end

  end

  context 'write users' do
    context 'with authorized user' do
      let(:user) { 'director' }
      let(:password) { 'directorpass' }

      it 'allows write' do
        expect { subject.create('foo') }.to_not raise_error
      end

      it 'allows delete' do
        expect { subject.delete('test') }.to_not raise_error
      end

     it 'should raise NotFound error when deleting non-existing file' do
       expect { subject.delete('non-exist-file') }.to raise_error Bosh::Blobstore::NotFound, /Object 'non-exist-file' is not found/
     end

      it 'allows checking for existance' do
        expect(subject.exists?('test')).to be(true)
      end
    end

    context 'with unauthorized user' do
      let(:user) { 'foo' }
      let(:password) { 'bar' }

      it "doesn't allow write" do
        expect { subject.create('foo', 'test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Could not create object, 401/)
      end

      it "doesn't allow delete" do
        expect { subject.delete('test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Could not delete object, 401/)
      end

      it 'does not allow checking for existance' do
        expect { subject.exists?('test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Could not get object existence, 401/)
      end
    end

    context 'with read only user' do
      let(:user) { 'agent' }
      let(:password) { 'agentpass' }

      it "doesn't allow write" do
        expect { subject.create('foo', 'test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Could not create object, 401/)
      end

      it "doesn't allow delete" do
        expect { subject.delete('test') }.to raise_error(Bosh::Blobstore::BlobstoreError, /Could not delete object, 401/)
      end
    end
  end
end
