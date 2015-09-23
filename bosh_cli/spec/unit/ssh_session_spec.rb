require 'spec_helper'

describe Bosh::Cli::SSHSession do
  include FakeFS::SpecHelpers

  let(:known_host_file_name) { "/home/.bosh/tmp/random_uuid_known_hosts" }
  let(:private_key_file_name) { "/home/.bosh/tmp/random_uuid_key" }

  let(:fake_key) { instance_double("SSHKey", :private_key => "private_key", :ssh_public_key => "public_key") }

  before do
    allow(ENV).to receive(:[])
    allow(ENV).to receive(:[]).with("HOME").and_return("/home")

    allow(SecureRandom).to receive(:uuid).and_return("random_uuid")
  end

  context 'Create SSH Session object' do
    it 'should generate a session uuid' do
      expect(SecureRandom).to receive(:uuid)
      described_class.new
    end

    it 'should generate an rsa key' do
      expect(SSHKey).to receive(:generate).with(:type => "RSA", :bits => 2048, :comment => "bosh-ssh").and_return(fake_key)

      described_class.new
      expect(File.read(private_key_file_name)).to eq("private_key\n")
    end

    it 'should generate random user name' do
      expect_any_instance_of(Bosh::Cli::SSHSession).to receive(:generate_rsa_key).and_return("public_key")
      session = described_class.new
      expect(session.user).to include(Bosh::Cli::SSHSession::SSH_USER_PREFIX)
    end
  end

  context 'With Valid SSH Session object' do
    before do
      allow(SSHKey).to receive(:generate).with(:type => "RSA", :bits => 2048, :comment => "bosh-ssh").and_return(fake_key)
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
      before do
        @session_object.set_host_session({"ip" => "127.0.0.1", "host_public_key" => "public_key"} )
      end

      it 'create a known host file with ip'do
        value = @session_object.ssh_known_host_option(nil)
        expect(File.read(known_host_file_name)).to eq("127.0.0.1 public_key\n")
        expect(value).to eq("-o UserKnownHostsFile=#{known_host_file_name}")
      end

      it 'create a known host file with localhost when gateway port is specified'do
        value = @session_object.ssh_known_host_option(1234)
        expect(File.read(known_host_file_name)).to eq("[localhost]:1234 public_key\n")
        expect(value).to eq("-o UserKnownHostsFile=#{known_host_file_name}")
      end
    end
  end
end