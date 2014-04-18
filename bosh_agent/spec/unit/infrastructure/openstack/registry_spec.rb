# -*- encoding: utf-8 -*-
# Copyright (c) 2009-2013 GoPivotal, Inc.

require 'spec_helper'
require 'bosh_agent/infrastructure/openstack'

describe Bosh::Agent::Infrastructure::Openstack::Registry do
  let(:subject) { described_class }
  let(:registry_schema) { 'http' }
  let(:registry_hostname) { 'registry_endpoint' }
  let(:registry_port) { '25777' }
  let(:registry_endpoint) { "#{registry_schema}://#{registry_hostname}:#{registry_port}" }
  let(:server_name) { 'server-name' }
  let(:nameservers) { nil }
  let(:openssh_public_key) { 'openssh-public-key' }
  let(:user_data) do
    {
      'registry' => { 'endpoint' => registry_endpoint },
      'server' => { 'name' => server_name },
      'dns' => { 'nameserver' => nameservers },
      'openssh' => { 'public_key' => openssh_public_key },
      'public_keys' => { 'default' => openssh_public_key }
    }
  end

  describe :get_openssh_key do
    it 'should get openssh public key from meta-data service' do
      subject.should_receive(:get_uri)
              .with('http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key')
              .and_return(openssh_public_key)

      expect(subject.get_openssh_key).to eql(openssh_public_key)
    end

    context 'when meta-data service is unavailable' do
      it 'should get openssh public key from injected user file' do
        subject.should_receive(:get_uri)
                .with('http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key')
                .and_raise(Bosh::Agent::LoadSettingsError)

        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
            .and_return(Yajl::Encoder.encode(user_data))

        expect(subject.get_openssh_key).to eql(openssh_public_key)
      end
    end

    context 'when meta-data service does not contain a public key' do
      it 'should get openssh public key from injected user file' do
        subject.should_receive(:get_uri)
                .with('http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key')
                .and_return('')

        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
            .and_return(Yajl::Encoder.encode(user_data))

        expect(subject.get_openssh_key).to eql(openssh_public_key)
      end
    end

    context 'when injected file does not exist' do
      it 'should get openssh public key from config drive' do
        subject.should_receive(:get_uri)
                .with('http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key')
                .and_raise(Bosh::Agent::LoadSettingsError)

        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
            .and_raise(Errno::ENOENT)

        subject.should_receive(:mount_config_drive)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'mnt', 'config', 'openstack', 'latest', 'meta_data.json'))
            .and_return(Yajl::Encoder.encode(user_data))

        expect(subject.get_openssh_key).to eql(openssh_public_key)
      end
    end

    context 'when injected file does not contain a public key' do
      it 'should get openssh public key from config drive' do
        subject.should_receive(:get_uri)
                .with('http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key')
                .and_raise(Bosh::Agent::LoadSettingsError)

        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
            .and_return('')

        subject.should_receive(:mount_config_drive)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'mnt', 'config', 'openstack', 'latest', 'meta_data.json'))
            .and_return(Yajl::Encoder.encode(user_data))

        expect(subject.get_openssh_key).to eql(openssh_public_key)
      end
    end

    context 'when config-drive does not exist' do
      it 'should return nil' do
        subject.should_receive(:get_uri)
                .with('http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key')
                .and_raise(Bosh::Agent::LoadSettingsError)

        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
            .and_raise(Errno::ENOENT)

        Bosh::Exec.should_receive(:sh)
                  .with('blkid -l -t LABEL="config-2" -o device', on_error: :return)
                  .and_return(Bosh::Exec::Result.new('command', '', 1))

        expect(subject.get_openssh_key).to be_nil
      end
    end

    context 'when config-drive file does not exist' do
      it 'should return nil' do
        subject.should_receive(:get_uri)
                .with('http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key')
                .and_raise(Bosh::Agent::LoadSettingsError)

        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
        .and_raise(Errno::ENOENT)

        subject.should_receive(:mount_config_drive)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'mnt', 'config', 'openstack', 'latest', 'meta_data.json'))
            .and_raise(Errno::ENOENT)

        expect(subject.get_openssh_key).to be_nil
      end
    end

    context 'when config-drive file does not contain a public key' do
      it 'should return nil' do
        subject.should_receive(:get_uri)
                .with('http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key')
                .and_raise(Bosh::Agent::LoadSettingsError)

        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
        .and_raise(Errno::ENOENT)

        subject.should_receive(:mount_config_drive)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'mnt', 'config', 'openstack', 'latest', 'meta_data.json'))
            .and_return('')

        expect(subject.get_openssh_key).to be_nil
      end
    end
  end

  describe :get_settings do
    let(:settings) do
      {
        'vm' => { 'name' => server_name },
        'agent_id' => 'agent-id',
        'networks' => { 'default' => { 'type' => 'dynamic' } },
        'disks' => { 'system' => '/dev/xvda', 'persistent' => {} }
      }
    end
    let(:httpclient) { double('httpclient') }
    let(:status) { 200 }
    let(:body) { Yajl::Encoder.encode({ settings: Yajl::Encoder.encode(settings) }) }
    let(:response) { double('response', status: status, body: body) }
    let(:uri) { "#{registry_endpoint}/instances/#{server_name}/settings" }

    before do
      HTTPClient.stub(:new).and_return(httpclient)
      httpclient.stub(:send_timeout=)
      httpclient.stub(:receive_timeout=)
      httpclient.stub(:connect_timeout=)
      subject.user_data = nil
    end

    it 'should get agent settings' do
      subject.should_receive(:get_user_data).twice.and_return(user_data)
      httpclient.should_receive(:get).with(uri, {}, { 'Accept' => 'application/json' }).and_return(response)

      expect(subject.get_settings).to eql(settings)
    end

    it 'should raise a LoadSettingsError exception if user data does not contain registry endpoint' do
      subject.should_receive(:get_user_data).and_return(user_data.tap { |hs| hs.delete('registry') })

      expect do
        subject.get_settings
      end.to raise_error(Bosh::Agent::LoadSettingsError, /Cannot get BOSH registry endpoint from user data/)
    end

    it 'should raise a LoadSettingsError exception if user data does not contain the server name' do
      subject.should_receive(:get_user_data).twice.and_return(user_data.tap { |hs| hs.delete('server') })

      expect do
        subject.get_settings
      end.to raise_error(Bosh::Agent::LoadSettingsError, /Cannot get server name from user data/)
    end

    it 'should get registry settings from meta-data service' do
      subject.should_receive(:get_uri)
             .with('http://169.254.169.254/latest/user-data')
             .and_return(Yajl::Encoder.encode(user_data))
      subject.should_receive(:get_uri).with(uri).and_return(body)

      expect(subject.get_settings).to eql(settings)
    end

    context 'when meta-data service is unavailable' do
      it 'should get registry settings from injected user file' do
        subject.should_receive(:get_uri)
               .with('http://169.254.169.254/latest/user-data')
               .and_raise(Bosh::Agent::LoadSettingsError)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
            .and_return(Yajl::Encoder.encode(user_data))
        subject.should_receive(:get_uri).with(uri).and_return(body)

        expect(subject.get_settings).to eql(settings)
      end
    end

    context 'when meta-data service does not contain user-data' do
      it 'should get registry settings from injected user file' do
        subject.should_receive(:get_uri)
               .with('http://169.254.169.254/latest/user-data')
               .and_return(Yajl::Encoder.encode({}))
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
            .and_return(Yajl::Encoder.encode(user_data))
        subject.should_receive(:get_uri).with(uri).and_return(body)

        expect(subject.get_settings).to eql(settings)
      end
    end

    context 'when injected file does not exist' do
      it 'should get registry settings from config drive' do
        subject.should_receive(:get_uri)
               .with('http://169.254.169.254/latest/user-data')
               .and_raise(Bosh::Agent::LoadSettingsError)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
            .and_raise(Errno::ENOENT)
        subject.should_receive(:mount_config_drive)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'mnt', 'config', 'openstack', 'latest', 'user_data'))
            .and_return(Yajl::Encoder.encode(user_data))
        subject.should_receive(:get_uri).with(uri).and_return(body)

        expect(subject.get_settings).to eql(settings)
      end
    end

    context 'when injected file does not contain user-data' do
      it 'should get registry settings from config drive' do
        subject.should_receive(:get_uri)
               .with('http://169.254.169.254/latest/user-data')
               .and_raise(Bosh::Agent::LoadSettingsError)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
            .and_return(Yajl::Encoder.encode({}))
        subject.should_receive(:mount_config_drive)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'mnt', 'config', 'openstack', 'latest', 'user_data'))
            .and_return(Yajl::Encoder.encode(user_data))
        subject.should_receive(:get_uri).with(uri).and_return(body)

        expect(subject.get_settings).to eql(settings)
      end
    end

    context 'when config-drive does not exist' do
      it 'should raise a LoadSettingsError exception' do
        subject.should_receive(:get_uri)
               .with('http://169.254.169.254/latest/user-data')
               .and_raise(Bosh::Agent::LoadSettingsError)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
            .and_raise(Errno::ENOENT)
        Bosh::Exec.should_receive(:sh)
                  .with('blkid -l -t LABEL="config-2" -o device', on_error: :return)
                  .and_return(Bosh::Exec::Result.new('command', '', 1))

        expect do
          subject.get_settings
        end.to raise_error(Bosh::Agent::LoadSettingsError, /Failed to get VM user data/)
      end
    end

    context 'when config-drive file does not exist' do
      it 'should raise a LoadSettingsError exception' do
        subject.should_receive(:get_uri)
               .with('http://169.254.169.254/latest/user-data')
               .and_raise(Bosh::Agent::LoadSettingsError)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
            .and_raise(Errno::ENOENT)
        subject.should_receive(:mount_config_drive)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'mnt', 'config', 'openstack', 'latest', 'user_data'))
            .and_raise(Errno::ENOENT)

        expect do
          subject.get_settings
        end.to raise_error(Bosh::Agent::LoadSettingsError, /Failed to get VM user data/)
      end
    end

    context 'when config-drive file does not contain a user-data' do
      it 'should raise a LoadSettingsError exception' do
        subject.should_receive(:get_uri)
               .with('http://169.254.169.254/latest/user-data')
               .and_raise(Bosh::Agent::LoadSettingsError)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'var', 'vcap', 'bosh', 'user_data.json'))
            .and_raise(Errno::ENOENT)
        subject.should_receive(:mount_config_drive)
        File.should_receive(:read)
            .with(File.join(File::SEPARATOR, 'mnt', 'config', 'openstack', 'latest', 'user_data'))
            .and_return(Yajl::Encoder.encode({}))

        expect do
          subject.get_settings
        end.to raise_error(Bosh::Agent::LoadSettingsError, /Failed to get VM user data/)
      end
    end

    context 'with invalid registry data' do
      let(:body) { { settings: settings } }

      it 'should raise a LoadSettingsError exception if registry date can not be parsed' do
        subject.should_receive(:get_user_data).twice.and_return(user_data)
        httpclient.should_receive(:get).with(uri, {}, { 'Accept' => 'application/json' }).and_return(response)

        expect do
          subject.get_settings
        end.to raise_error(Bosh::Agent::LoadSettingsError, /Cannot parse data/)
      end
    end

    context 'with invalid settings' do
      let(:body) { Yajl::Encoder.encode({ settings: settings }) }

      it 'should raise a LoadSettingsError exception if settings can not be parsed' do
        subject.should_receive(:get_user_data).twice.and_return(user_data)
        httpclient.should_receive(:get).with(uri, {}, { 'Accept' => 'application/json' }).and_return(response)

        expect do
          subject.get_settings
        end.to raise_error(Bosh::Agent::LoadSettingsError, /Cannot parse data/)
      end
    end

    context 'without settings Hash' do
      let(:body) { Yajl::Encoder.encode({ sezzings: Yajl::Encoder.encode(settings) }) }

      it 'should raise a LoadSettingsError exception if settings Hash not found' do
        subject.should_receive(:get_user_data).twice.and_return(user_data)
        httpclient.should_receive(:get).with(uri, {}, { 'Accept' => 'application/json' }).and_return(response)

        expect do
          subject.get_settings
        end.to raise_error(Bosh::Agent::LoadSettingsError, /Invalid response received from BOSH registry/)
      end
    end

    context 'with dns' do
      let(:nameservers) { ['8.8.8.8'] }
      let(:resolver) { double('resolver') }
      let(:registry_ipaddress) { '1.2.3.4' }

      before do
        Resolv::DNS.stub(:new).with(nameserver: nameservers).and_return(resolver)
      end

      context 'when registry endpoint is a hostname' do
        let(:uri) { "#{registry_schema}://#{registry_ipaddress}:#{registry_port}/instances/#{server_name}/settings" }

        it 'should get agent settings' do
          subject.should_receive(:get_user_data).twice.and_return(user_data)
          httpclient.should_receive(:get).with(uri, {}, { 'Accept' => 'application/json' }).and_return(response)
          resolver.should_receive(:getaddress).with(registry_hostname).and_return(registry_ipaddress)

          expect(subject.get_settings).to eql(settings)
        end

        it 'should raise a LoadSettingsError exception if can not resolve the hostname' do
          subject.should_receive(:get_user_data).and_return(user_data)
          resolver.should_receive(:getaddress).with(registry_hostname).and_raise(Resolv::ResolvError)

          expect do
            subject.get_settings
          end.to raise_error(Bosh::Agent::LoadSettingsError, /Cannot lookup registry_endpoint using/)
        end
      end

      context 'when registry endpoint is an IP address' do
        let(:registry_hostname) { '1.2.3.4' }

        it 'should get agent settings' do
          subject.should_receive(:get_user_data).twice.and_return(user_data)
          httpclient.should_receive(:get).with(uri, {}, { 'Accept' => 'application/json' }).and_return(response)
          resolver.should_not_receive(:getaddress)

          expect(subject.get_settings).to eql(settings)
        end
      end
    end
  end
end
