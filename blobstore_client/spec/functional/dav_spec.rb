require 'spec_helper'

module Bosh::Blobstore
  describe DavBlobstoreClient, nginx: true do

    attr_reader :port, :root, :read_users_path, :write_users_path

    NGINX_PATH = '/usr/local/sbin/nginx'

    def create_user_file(users)
      temp = Tempfile.new('users')
      users.each { |u, p| temp.write("#{u}:{PLAIN}#{p}\n") }
      temp.flush
      temp
    end

    def create_test_blob
      FileUtils.mkdir_p(File.join(@root, 'a9'))
      path = File.join(@root, 'a9', 'test')
      File.open(path, 'w') do |f|
        f.write('test')
      end

      path
    end

    before(:all) do
      # brew install nginx --with-webdav

      @port = 20000
      @root = Dir.mktmpdir

      @read_users = create_user_file('agent' => 'agentpass', 'director' => 'directorpass')
      @read_users_path = @read_users.to_path

      @write_users = create_user_file('director' => 'directorpass')
      @write_users_path = @write_users.to_path

      @nginx_config = erb_asset('nginx.conf.erb', binding)

      @pid = Process.spawn(NGINX_PATH, '-c', @nginx_config.to_path,
                           out: $stdout, err: $stderr, in: :close)
      Process.detach(@pid)
    end

    after(:all) do
      Process.spawn(NGINX_PATH, '-s', 'stop')
      FileUtils.rm_rf(root)
      FileUtils.rm_rf(nginx_config)
      FileUtils.rm_rf(read_users_path)
      FileUtils.rm_rf(write_users_path)
    end

    before(:each) do
      @test_blob_path = create_test_blob
    end

    after(:each) do
      FileUtils.rm_rf(@test_blob_path)
    end

    let(:endpoint) { "http://localhost:#{@port}/" }

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
          expect { subject.get('test') }.to raise_error(BlobstoreError, /Could not fetch object, 401/)
        end

        it 'does not allow checking for existance' do
          expect { subject.exists?('test') }.to raise_error(BlobstoreError, /Could not get object existence, 401/)
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

        it 'allows checking for existance' do
          expect(subject.exists?('test')).to be(true)
        end
      end

      context 'with unauthorized user' do
        let(:user) { 'foo' }
        let(:password) { 'bar' }

        it "doesn't allow write" do
          expect { subject.create('foo', 'test') }.to raise_error(BlobstoreError, /Could not create object, 401/)
        end

        it "doesn't allow delete" do
          expect { subject.delete('test') }.to raise_error(BlobstoreError, /Could not delete object, 401/)
        end

        it 'does not allow checking for existance' do
          expect { subject.exists?('test') }.to raise_error(BlobstoreError, /Could not get object existence, 401/)
        end
      end

      context 'with read only user' do
        let(:user) { 'agent' }
        let(:password) { 'agentpass' }

        it "doesn't allow write" do
          expect { subject.create('foo', 'test') }.to raise_error(BlobstoreError, /Could not create object, 401/)
        end

        it "doesn't allow delete" do
          expect { subject.delete('test') }.to raise_error(BlobstoreError, /Could not delete object, 401/)
        end
      end

    end
  end
end
