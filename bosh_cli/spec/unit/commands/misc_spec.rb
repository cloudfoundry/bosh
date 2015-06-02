# Copyright (c) 2009-2013 VMware, Inc.

require 'spec_helper'

describe Bosh::Cli::Command::Misc do
  include FakeFS::SpecHelpers

  let(:command) { described_class.new }
  let(:director) { instance_double(Bosh::Cli::Client::Director) }
  let(:versions_index) { instance_double(Bosh::Cli::Versions::VersionsIndex) }
  let(:release) { instance_double(Bosh::Cli::Release) }
  let(:target) { 'https://127.0.0.1:2555' }
  let(:target_name) { 'micro-fake-bosh' }
  let(:uuid) { SecureRandom.uuid }

  before do
    allow(Bosh::Cli::Client::Director).to receive(:new).and_return(director)
    allow(Bosh::Cli::Versions::VersionsIndex).to receive(:new).and_return(versions_index)
    allow(Bosh::Cli::Release).to receive(:new).and_return(release)
  end

  before do
    @config_file = File.join(Dir.mktmpdir, 'bosh_config')
    command.add_option(:config, @config_file)
  end

  describe 'status' do
    it 'should show current status' do
      allow(command).to receive(:target).and_return(target)
      allow(command).to receive(:target_url).and_return(target)
      allow(command).to receive(:deployment).and_return('deployment-file')

      allow(director).to receive(:get_status).and_return({
        'name' => target_name,
        'version' => 'v.m (release:rrrrrrrr bosh:bbbbbbbb)',
        'uuid' => uuid,
        'user' => 'fake-user',
        'cpi' => 'dummy'
      })

      expect(command).to receive(:say).with('Config')
      expect(command).to receive(:say).with(/#{@config_file}/)

      expect(command).to receive(:say).with("\n")
      expect(command).to receive(:say).with('Director')
      expect(command).to receive(:say).with(/#{target_name}/)
      expect(command).to receive(:say).with(/#{target}/)
      expect(command).to receive(:say).with(/v\.m \(release:rrrrrrrr bosh:bbbbbbbb\)/)
      expect(command).to receive(:say).with(/User.*fake-user/)
      expect(command).to receive(:say).with(/#{uuid}/)
      expect(command).to receive(:say).with(/dummy/)

      expect(command).to receive(:say).with("\n")
      expect(command).to receive(:say).with('Deployment')
      expect(command).to receive(:say).with(/deployment-file/)

      command.status
    end

    context 'when user is not provided in response' do
      it 'prints not logged in' do
        allow(command).to receive(:target).and_return(target)
        allow(command).to receive(:target_url).and_return(target)
        allow(command).to receive(:deployment).and_return('deployment-file')

        allow(director).to receive(:get_status).and_return({
              'name' => target_name,
              'version' => 'v.m (release:rrrrrrrr bosh:bbbbbbbb)',
              'uuid' => uuid,
              'cpi' => 'dummy'
            })

        allow(command).to receive(:say)
        expect(command).to receive(:say).with(/User.*not logged in/)
        command.status
      end
    end

    it 'should not show director data when target is not set' do
      allow(command).to receive(:target).and_return(nil)
      expect(director).not_to receive(:get_status)

      expect(command).to receive(:say).with('Config')
      expect(command).to receive(:say).with(/#{@config_file}/)

      expect(command).to receive(:say).with("\n")
      expect(command).to receive(:say).with('Director')
      expect(command).to receive(:say).with(/not set/)

      expect(command).to receive(:say).with("\n")
      expect(command).to receive(:say).with('Deployment')
      expect(command).to receive(:say).with(/not set/)

      command.status
    end

    it 'should not show director data when fetching director status timeouts' do
      allow(command).to receive(:target).and_return(target)
      expect(director).to receive(:get_status).and_raise(Timeout::Error)

      expect(command).to receive(:say).with('Config')
      expect(command).to receive(:say).with(/#{@config_file}/)

      expect(command).to receive(:say).with("\n")
      expect(command).to receive(:say).with('Director')
      expect(command).to receive(:say).with(/timed out fetching director status/)

      expect(command).to receive(:say).with("\n")
      expect(command).to receive(:say).with('Deployment')
      expect(command).to receive(:say).with(/not set/)

      command.status
    end

    it 'should not show director data when director raises and exception' do
      allow(command).to receive(:target).and_return(target)
      expect(director).to receive(:get_status).and_raise(Bosh::Cli::DirectorError)

      expect(command).to receive(:say).with('Config')
      expect(command).to receive(:say).with(/#{@config_file}/)

      expect(command).to receive(:say).with("\n")
      expect(command).to receive(:say).with('Director')
      expect(command).to receive(:say).with(/error fetching director status:/)

      expect(command).to receive(:say).with("\n")
      expect(command).to receive(:say).with('Deployment')
      expect(command).to receive(:say).with(/not set/)

      command.status
    end

    context '--uuid option is passed' do
      context 'can get status from director' do
        it 'prints only the director uuid' do
          command.add_option(:uuid, true)
          allow(command).to receive(:target).and_return(target)

          allow(director).to receive(:get_status).and_return({ 'uuid' => uuid })

          expect(command).to receive(:say).with(/#{uuid}/)

          command.status
        end
      end

      context 'fails to get director status' do
        it 'returns non-zero status' do
          command.add_option(:uuid, true)
          allow(command).to receive(:target).and_return(target)

          allow(director).to receive(:get_status).and_raise(Timeout::Error)

          expect(command).to receive(:err).with(/Error fetching director status:/)

          command.status
        end
      end
    end
  end

  describe '#target' do
    context 'target is set' do
      context 'without arguments' do
        before do
          File.open(@config_file, 'w+') do |f|
            f.write(<<EOS)
---
target: #{target}
target_name: #{target_name}
target_uuid: #{uuid}
EOS
          end
        end

        context 'is interactive' do
          context 'target name is set' do
            it 'decorates target with target name' do
              expect(command).to receive(:say).with("Current target is #{target} (#{target_name})")
              command.set_target
            end
          end

          context 'name is not set' do
            let(:target_name) { nil }

            it 'decorates target' do
              expect(command).to receive(:say).with("Current target is #{target}")
              command.set_target
            end
          end
        end

        context 'is non-interactive' do
          it 'does not decorates target' do
            command.add_option(:non_interactive, true)
            expect(command).to receive(:say).with("#{target}")
            command.set_target
          end
        end
      end

      context 'target is not set' do
        it 'errors' do
          expect(command).to receive(:err).with('Target not set')
          command.set_target
        end
      end
    end

    context 'when new target is passed in' do
      before do
        allow(director).to receive(:get_status).and_return({})
        command.add_option(:non_interactive, true)
      end

      it 'sets new target' do
        command.set_target 'https://fake-target:1234'
        expect(command).to receive(:say).with('https://fake-target:1234')
        command.set_target
      end

      it 'saves ca-cert' do
        command.add_option(:ca_cert, '/fake-ca-cert')
        command.set_target 'https://fake-target:1234'
        config = YAML.load(File.read(@config_file))
        expect(config['ca_cert']).to eq({'https://fake-target:1234' => '/fake-ca-cert'})
      end

      context 'when new certificate is different from old certificate' do
        it 'prints update message' do
          command.add_option(:ca_cert, '/fake-ca-cert')
          allow(command).to receive(:say)
          expect(command).to receive(:say).with(/Updating certificate file path to `\/fake-ca-cert'/)
          command.set_target 'https://fake-target:1234'
        end
      end

      context 'when new certificate is the same as old certificate' do
        it 'prints update message' do
          command.add_option(:ca_cert, '/fake-ca-cert')
          command.set_target 'https://fake-target:1234'

          expect(command).to_not receive(:say).with(/Updating certificate file path to `\/fake-ca-cert'/)
          command.set_target 'https://fake-target:1234'
        end
      end

      context 'when new target is the same as old target' do
        it 'updates ca cert path' do
          command.add_option(:ca_cert, '/fake-ca-cert')
          command.set_target 'https://fake-target:1234'
          config = YAML.load(File.read(@config_file))
          expect(config['ca_cert']).to eq({'https://fake-target:1234' => '/fake-ca-cert'})

          command.add_option(:ca_cert, '/another-ca-cert')
          command.set_target 'https://fake-target:1234'
          config = YAML.load(File.read(@config_file))
          expect(config['ca_cert']).to eq({'https://fake-target:1234' => '/another-ca-cert'})
        end
      end
    end
  end
end
