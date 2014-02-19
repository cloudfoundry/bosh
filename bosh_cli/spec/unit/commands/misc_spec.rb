# Copyright (c) 2009-2013 VMware, Inc.

require 'spec_helper'

describe Bosh::Cli::Command::Misc do
  include FakeFS::SpecHelpers

  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Client::Director) }
  let(:versions_index) { double(Bosh::Cli::VersionsIndex) }
  let(:release) { double(Bosh::Cli::Release) }
  let(:target) { 'https://127.0.0.1:2555' }
  let(:target_name) { 'micro-fake-bosh' }
  let(:uuid) { SecureRandom.uuid }

  before do
    Bosh::Cli::Client::Director.stub(:new).and_return(director)
    Bosh::Cli::VersionsIndex.stub(:new).and_return(versions_index)
    Bosh::Cli::Release.stub(:new).and_return(release)
  end

  before do
    @config_file = File.join(Dir.mktmpdir, 'bosh_config')
  end

  describe 'status' do
    it 'should show current status' do
      command.add_option(:config, @config_file)
      command.stub(:target).and_return(target)
      command.stub(:target_url).and_return(target)
      command.stub(:deployment).and_return('deployment-file')
      command.stub(:in_release_dir?).and_return(true)

      director.should_receive(:get_status).and_return({'name' => target_name,
                                                       'version' => 'v.m (release:rrrrrrrr bosh:bbbbbbbb)',
                                                       'uuid' => uuid,
                                                       'cpi' => 'dummy'})
      release.should_receive(:dev_name).and_return('dev-name')
      release.should_receive(:final_name).and_return('final_name')
      versions_index.should_receive(:latest_version).and_return('1-dev')
      versions_index.should_receive(:latest_version).and_return('1')


      command.should_receive(:say).with('Config')
      command.should_receive(:say).with(/#{@config_file}/)

      command.should_receive(:say).with("\n")
      command.should_receive(:say).with('Director')
      command.should_receive(:say).with(/#{target_name}/)
      command.should_receive(:say).with(/#{target}/)
      command.should_receive(:say).with(/v\.m \(release:rrrrrrrr bosh:bbbbbbbb\)/)
      command.should_receive(:say).with(/User/)
      command.should_receive(:say).with(/#{uuid}/)
      command.should_receive(:say).with(/dummy/)

      command.should_receive(:say).with("\n")
      command.should_receive(:say).with('Deployment')
      command.should_receive(:say).with(/deployment-file/)

      command.should_receive(:say).with("\n")
      command.should_receive(:say).with('Release')
      command.should_receive(:say).with(/dev-name\/1-dev/)
      command.should_receive(:say).with(/final_name\/1/)

      command.status
    end

    it 'should not show director data when target is not set' do
      command.add_option(:config, @config_file)
      command.stub(:target).and_return(nil)
      director.should_not_receive(:get_status)

      command.should_receive(:say).with('Config')
      command.should_receive(:say).with(/#{@config_file}/)

      command.should_receive(:say).with("\n")
      command.should_receive(:say).with('Director')
      command.should_receive(:say).with(/not set/)

      command.should_receive(:say).with("\n")
      command.should_receive(:say).with('Deployment')
      command.should_receive(:say).with(/not set/)

      command.status
    end

    it 'should not show director data when fetching director status timeouts' do
      command.add_option(:config, @config_file)
      command.stub(:target).and_return(target)
      director.should_receive(:get_status).and_raise(TimeoutError)

      command.should_receive(:say).with('Config')
      command.should_receive(:say).with(/#{@config_file}/)

      command.should_receive(:say).with("\n")
      command.should_receive(:say).with('Director')
      command.should_receive(:say).with(/timed out fetching director status/)

      command.should_receive(:say).with("\n")
      command.should_receive(:say).with('Deployment')
      command.should_receive(:say).with(/not set/)

      command.status
    end

    it 'should not show director data when director raises and exception' do
      command.add_option(:config, @config_file)
      command.stub(:target).and_return(target)
      director.should_receive(:get_status).and_raise(Bosh::Cli::DirectorError)

      command.should_receive(:say).with('Config')
      command.should_receive(:say).with(/#{@config_file}/)

      command.should_receive(:say).with("\n")
      command.should_receive(:say).with('Director')
      command.should_receive(:say).with(/error fetching director status:/)

      command.should_receive(:say).with("\n")
      command.should_receive(:say).with('Deployment')
      command.should_receive(:say).with(/not set/)

      command.status
    end

    context '--uuid option is passed' do
      context 'can get status from director' do
        it 'prints only the director uuid' do
          command.add_option(:config, @config_file)
          command.add_option(:uuid, true)
          command.stub(:target).and_return(target)

          director.stub(:get_status).and_return({ 'uuid' => uuid })

          command.should_receive(:say).with(/#{uuid}/)

          command.status
        end
      end

      context 'fails to get director status' do
        it 'returns non-zero status' do
          command.add_option(:config, @config_file)
          command.add_option(:uuid, true)
          command.stub(:target).and_return(target)

          director.stub(:get_status).and_raise(Timeout::Error)

          command.should_receive(:err).with(/Error fetching director status:/)

          command.status
        end
      end
    end
  end

  describe '#target' do
    context 'target is set' do
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
            command.add_option(:config, @config_file)
            command.should_receive(:say).with("Current target is #{target} (#{target_name})")
            command.set_target
          end
        end

        context 'name is not set' do
          let(:target_name) { nil }

          it 'decorates target' do
            command.add_option(:config, @config_file)
            command.should_receive(:say).with("Current target is #{target}")
            command.set_target
          end
        end
      end

      context 'is non-interactive' do
        it 'does not decorates target' do
          command.add_option(:config, @config_file)
          command.add_option(:non_interactive, true)
          command.should_receive(:say).with("#{target}")
          command.set_target
        end
      end
    end

    context 'target is not set' do
      it 'errors' do
        command.add_option(:config, @config_file)
        command.should_receive(:err).with('Target not set')
        command.set_target
      end
    end
  end
end
