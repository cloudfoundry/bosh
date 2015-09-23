require 'spec_helper'

describe Bosh::Cli::SSHSession do

  let(:known_hosts_file) { Tempfile.new("bosh_known_host") }
  let(:known_host_file_name) { "/home/.bosh/tmp/random_uuid_known_hosts" }
  let(:private_key_file) { Tempfile.new("private_key_file") }
  let(:private_key_file_name) { "/home/.bosh/tmp/random_uuid_key" }

  let(:fake_key) { instance_double("SSHKey", :private_key => "private_key", :ssh_public_key => "public_key") }

  before do
    allow(ENV).to receive(:[])
    allow(ENV).to receive(:[]).with("HOME").and_return("/home")

    allow(SecureRandom).to receive(:uuid).and_return("random_uuid")
  end

  context 'Create SSH Session object' do
    it 'should generate a session uuid' do
      allow(File).to receive(:directory?).and_return(false)
      allow(FileUtils).to receive(:mkdir_p).with("/home/.bosh/tmp")
      allow(File).to receive(:new).with("/home/.bosh/tmp/random_uuid_key", "w", 0400).and_return(private_key_file)
      allow(SSHKey).to receive(:generate).and_return(fake_key)

      expect(SecureRandom).to receive(:uuid)
      described_class.new
    end

    it 'should generate an rsa key' do
      expect(SSHKey).to receive(:generate).with(:type => "RSA", :bits => 2048, :comment => "bosh-ssh").and_return(fake_key)

      expect(File).to receive(:directory?).and_return(false)
      expect(FileUtils).to receive(:mkdir_p).with("/home/.bosh/tmp")

      expect(File).to receive(:new).with(private_key_file_name, "w", 0400).and_return(private_key_file)
      expect(private_key_file).to receive(:puts).with("private_key")
      expect(private_key_file).to receive(:close)

      described_class.new
    end

    it 'should generate random user name' do

      expect_any_instance_of(Bosh::Cli::SSHSession).to receive(:generate_rsa_key).and_return("public_key")
      session = described_class.new
      expect(session.user).to include(Bosh::Cli::SSHSession::SSH_USER_PREFIX)
    end
  end

  context 'With Valid SSH Session object' do
    before do
      allow(SecureRandom).to receive(:uuid).and_return("random_uuid")

      allow(SSHKey).to receive(:generate).with(:type => "RSA", :bits => 2048, :comment => "bosh-ssh").and_return(fake_key)

      allow(File).to receive(:directory?).and_return(false)
      allow(FileUtils).to receive(:mkdir_p).with("/home/.bosh/tmp")

      allow(File).to receive(:new).with(private_key_file_name, "w", 0400).and_return(private_key_file)
      allow(private_key_file).to receive(:puts).with("private_key")
      allow(private_key_file).to receive(:close)

      @session_object = Bosh::Cli::SSHSession.new
    end

    it 'should return valid private key option' do
      expect(@session_object.ssh_private_key_option).to eq("-i#{private_key_file_name}")
    end

    it 'should return valid private key path' do
      expect(@session_object.ssh_private_key_path).to eq(private_key_file_name)
    end

    it 'should delete private key and known hosts file on cleanup' do
      expect(File).to receive(:exist?).twice.and_return(true)
      expect(FileUtils).to receive(:rm_rf).with(known_host_file_name)
      expect(FileUtils).to receive(:rm_rf).with(private_key_file_name)

      @session_object.cleanup
    end

    context 'without host public key' do
      before do
        @session_object.set_host_session({"ip" => "127.0.0.1"})
      end
      it "should return empty string for ssh_known_host_option" do
        expect(@session_object.ssh_known_host_option(nil)).to eq(String.new)
        expect(@session_object.ssh_known_host_option(1234)).to eq(String.new)
      end

      it "should return empty string for ssh_known_host_path" do
        expect(@session_object.ssh_known_host_path(nil)).to eq(String.new)
        expect(@session_object.ssh_known_host_path(1234)).to eq(String.new)
      end
    end

    context 'with host public key' do

      let (:host_file_dir_name) { "/home/.bosh/tmp" }

      before do
        @session_object.set_host_session({"ip" => "127.0.0.1", "host_public_key" => "public_key"} )
      end

      def expectKnownHostFileCreationWithEntry(entry)
        expect(File).to receive(:dirname).with(known_host_file_name).and_return(host_file_dir_name)
        expect(File).to receive(:directory?).and_return(false)
        expect(FileUtils).to receive(:mkdir_p).with("/home/.bosh/tmp")

        expect(File).to receive(:new).with(known_host_file_name, "w").and_return(known_hosts_file)
        expect(known_hosts_file).to receive(:puts).with(entry)
        expect(known_hosts_file).to receive(:close)
      end

      it 'create a known host file with ip'do
        expectKnownHostFileCreationWithEntry("127.0.0.1 public_key")
        value = @session_object.ssh_known_host_option(nil)
        expect(value).to eq("-o UserKnownHostsFile=#{known_host_file_name}")
      end

      it 'create a known host file with localhost when gateway port is specified'do
        expectKnownHostFileCreationWithEntry("[localhost]:1234 public_key")
        value = @session_object.ssh_known_host_option(1234)
        expect(value).to eq("-o UserKnownHostsFile=#{known_host_file_name}")
      end
    end
  end
end