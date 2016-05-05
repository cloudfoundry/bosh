require 'spec_helper'
require 'net/ssh/gateway'

describe Bosh::Cli::Command::Ssh do
  include FakeFS::SpecHelpers

  let(:command) { described_class.new }
  let(:net_ssh) { double('ssh') }
  let(:director) { double(Bosh::Cli::Client::Director, uuid: 'director-uuid') }
  let(:deployment) { 'mycloud' }
  let(:ssh_session) { instance_double(Bosh::Cli::SSHSession) }

  let(:manifest) do
    {
      'name' => deployment,
      'director_uuid' => 'director-uuid',
      'releases' => [],
      'jobs' => [
        {
          'name' => 'dea',
          'instances' => 1
        }
      ]
    }
  end

  before do
    allow(command).to receive_messages(director: director, public_key: 'public_key', show_current_state: nil)
    File.open('fake-deployment', 'w') { |f| f.write(manifest.to_yaml) }
    allow(command).to receive(:deployment).and_return('fake-deployment')
    allow(Process).to receive(:waitpid)

    allow(command).to receive(:encrypt_password).with('').and_return('encrypted_password')

    allow(Bosh::Cli::SSHSession).to receive(:new).and_return(ssh_session)
    allow(ssh_session).to receive(:public_key).and_return("public_key")
    allow(ssh_session).to receive(:user).and_return("testable_user")
    allow(ssh_session).to receive(:set_host_session)
    allow(ssh_session).to receive(:cleanup)
    allow(ssh_session).to receive(:ssh_private_key_option).and_return("-i/tmp/.bosh/tmp/random_uuid_key")
    allow(ssh_session).to receive(:ssh_known_host_option).and_return("")
  end

  context 'shell' do
    describe 'invalid arguments' do
      it 'should fail if there is no deployment set' do
        allow(command).to receive_messages(deployment: nil)

        expect {
          command.shell('dea/1')
        }.to raise_error(Bosh::Cli::CliError, 'Please choose deployment first')
      end

      context 'when there is only one instance with that job name in the deployment' do
        before do
          allow(director).to receive(:fetch_vm_state).and_return([{'id' => '1234-5678-9012-3456', 'index' => 0, 'job' => 'dea'}])
        end

        it 'implicitly chooses the only instance if job name not provided' do
          expect(command).not_to receive(:choose)
          expect(command).to receive(:setup_interactive_shell).with('mycloud', 'dea', 0)
          command.shell
        end
      end

      context 'when there are many instances with that job name in the deployment' do
        let(:menu) { HighLine::Menu.new }

        context 'when response contains id' do
          before do
            allow(director).to receive(:fetch_vm_state).and_return([
              {'id' => '1234-5678-9012-3456', 'index' => 0, 'job' => 'dea'},
              {'id' => '1234-5678-9012-3457', 'index' => 1, 'job' => 'dea'},
              {'id' => '1234-5678-9012-3458', 'index' => 2, 'job' => 'dea'},
              {'id' => '1234-5678-9012-3459', 'index' => 3, 'job' => 'dea'},
              {'id' => '1234-5678-9012-3450', 'index' => 4, 'job' => 'dea'},
            ])
          end

          it 'prompts for an instance if job name not given with instance id' do
            expect(command).to receive(:choose).and_yield(menu).and_return(['dea', 3])
            expect(menu).to receive(:choice).with('dea/0 (1234-5678-9012-3456)')
            expect(menu).to receive(:choice).with('dea/1 (1234-5678-9012-3457)')
            expect(menu).to receive(:choice).with('dea/2 (1234-5678-9012-3458)')
            expect(menu).to receive(:choice).with('dea/3 (1234-5678-9012-3459)')
            expect(menu).to receive(:choice).with('dea/4 (1234-5678-9012-3450)')
            expect(command).to receive(:setup_interactive_shell).with('mycloud', 'dea', 3)
            command.shell
          end
        end

        context 'when response does not contain id' do
          before do
            allow(director).to receive(:fetch_vm_state).and_return([
              {'index' => 0, 'job' => 'dea'},
              {'index' => 1, 'job' => 'dea'},
              {'index' => 2, 'job' => 'dea'},
              {'index' => 3, 'job' => 'dea'},
              {'index' => 4, 'job' => 'dea'},
            ])
          end

          it 'prompts for an instance if job name not given with instance id' do
            expect(command).to receive(:choose).and_yield(menu).and_return(['dea', 3])
            expect(menu).to receive(:choice).with('dea/0')
            expect(menu).to receive(:choice).with('dea/1')
            expect(menu).to receive(:choice).with('dea/2')
            expect(menu).to receive(:choice).with('dea/3')
            expect(menu).to receive(:choice).with('dea/4')
            expect(command).to receive(:setup_interactive_shell).with('mycloud', 'dea', 3)
            command.shell
          end
        end
      end
    end

    describe 'exec' do
      it 'should try to execute given command remotely' do
        allow(Net::SSH).to receive(:start)
        allow(director).to receive(:get_task_result_log).and_return(JSON.dump([{'status' => 'success', 'ip' => '127.0.0.1'}]))
        allow(director).to receive(:cleanup_ssh)
        expect(director).to receive(:setup_ssh).
          with('mycloud', 'dea', '0', 'testable_user', 'public_key', 'encrypted_password').
          and_return([:done, 1234])

        expect(ssh_session).to receive(:ssh_known_host_path).and_return("fake_path")
        expect(ssh_session).to receive(:ssh_private_key_path)

        command.shell('dea/0', 'ls -l')
      end
    end

    describe 'session' do
      it 'should try to setup interactive shell when a job index is given' do
        expect(command).to receive(:setup_interactive_shell).with('mycloud', 'dea', '0')
        command.shell('dea', '0')
      end

      it 'should try to setup interactive shell when a job id is given' do
        uuid = SecureRandom.uuid
        expect(command).to receive(:setup_interactive_shell).with('mycloud', 'dea', uuid)
        command.shell('dea', uuid)
      end

      it 'should try to setup interactive shell when a job index is given as part of the job name' do
        expect(command).to receive(:setup_interactive_shell).with('mycloud', 'dea', '0')
        command.shell('dea/0')
      end

      it 'should setup ssh' do
        expect(Process).to receive(:spawn).with('ssh', 'testable_user@127.0.0.1', '-i/tmp/.bosh/tmp/random_uuid_key', '-o StrictHostKeyChecking=yes', '')

        expect(director).to receive(:setup_ssh).and_return([:done, 42])
        expect(director).to receive(:get_task_result_log).with(42).
          and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
        expect(ssh_session).to receive(:set_host_session).with({'status' => 'success', 'ip' => '127.0.0.1'})
        expect(director).to receive(:cleanup_ssh)
        expect(ssh_session).to receive(:cleanup)

        command.shell('dea/0')
      end


      context 'when strict host key checking is overriden to false' do
        before do
          command.add_option(:strict_host_key_checking, 'false')
        end

        it 'should disable strict host key checking' do
          expect(Process).to receive(:spawn).with('ssh', 'testable_user@127.0.0.1', '-i/tmp/.bosh/tmp/random_uuid_key', "-o StrictHostKeyChecking=no", "")

          allow(director).to receive(:setup_ssh).and_return([:done, 42])
          allow(director).to receive(:get_task_result_log).with(42).
            and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
          allow(director).to receive(:cleanup_ssh)

          command.shell('dea/0')
        end
      end

      it 'should setup ssh with gateway from bosh director' do
        expect(Net::SSH::Gateway).to receive(:new).with('dummy-host', 'vcap', {}).and_return(net_ssh)
        expect(net_ssh).to receive(:open).with(anything, 22).and_return(2345)
        expect(Process).to receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345', '-i/tmp/.bosh/tmp/random_uuid_key', "-o StrictHostKeyChecking=yes", "")

        expect(director).to receive(:setup_ssh).and_return([:done, 42])
        expect(director).to receive(:get_task_result_log).with(42).
          and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1', 'gateway_host' => 'dummy-host', 'gateway_user' => 'vcap'}]))
        expect(director).to receive(:cleanup_ssh)
        expect(ssh_session).to receive(:cleanup)

        expect(net_ssh).to receive(:close)
        expect(net_ssh).to receive(:shutdown!)

        command.shell('dea/0')
      end

      it 'should not setup ssh with gateway from bosh director when no_gateway is specified' do
        allow(Net::SSH::Gateway).to receive(:new) { expect(true).to equal?(false) }
        expect(Process).to receive(:spawn).with('ssh', 'testable_user@127.0.0.1', "-i/tmp/.bosh/tmp/random_uuid_key", "-o StrictHostKeyChecking=yes", "")

        expect(director).to receive(:setup_ssh).and_return([:done, 42])
        expect(director).to receive(:get_task_result_log).with(42).
          and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1', 'gateway_host' => 'dummy-host', 'gateway_user' => 'vcap'}]))
        expect(director).to receive(:cleanup_ssh)
        expect(ssh_session).to receive(:cleanup)

        command.add_option(:no_gateway, true)
        command.shell('dea/0')
      end

      context 'with a gateway host' do
        let(:gateway_host) { 'gateway-host' }
        let(:gateway_user) { ENV['USER'] }

        before do
          command.add_option(:gateway_host, gateway_host)
        end

        it 'should setup ssh with gateway host' do
          expect(Net::SSH::Gateway).to receive(:new).with(gateway_host, gateway_user, {}).and_return(net_ssh)
          expect(net_ssh).to receive(:open).with(anything, 22).and_return(2345)
          expect(Process).to receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345', '-i/tmp/.bosh/tmp/random_uuid_key', "-o StrictHostKeyChecking=yes", "")

          expect(director).to receive(:setup_ssh).and_return([:done, 42])
          expect(director).to receive(:get_task_result_log).with(42).
            and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
          expect(director).to receive(:cleanup_ssh)
          expect(ssh_session).to receive(:cleanup)

          expect(net_ssh).to receive(:close)
          expect(net_ssh).to receive(:shutdown!)

          command.shell('dea/0')
        end

        it 'should still setup ssh with gateway host even if no_gateway is specified' do
          command.add_option(:no_gateway, true)

          expect(Net::SSH::Gateway).to receive(:new).with(gateway_host, gateway_user, {}).and_return(net_ssh)
          expect(net_ssh).to receive(:open).with(anything, 22).and_return(2345)
          expect(Process).to receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345', '-i/tmp/.bosh/tmp/random_uuid_key', "-o StrictHostKeyChecking=yes", "")

          expect(director).to receive(:setup_ssh).and_return([:done, 42])
          expect(director).to receive(:get_task_result_log).with(42).
            and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
          expect(director).to receive(:cleanup_ssh)
          expect(ssh_session).to receive(:cleanup)

          expect(net_ssh).to receive(:close)
          expect(net_ssh).to receive(:shutdown!)

          command.shell('dea/0')
        end

        context 'with a gateway user' do
          let(:gateway_user) { 'gateway-user' }

          before do
            command.add_option(:gateway_user, gateway_user)
          end

          it 'should setup ssh with gateway host and user' do
            expect(Net::SSH::Gateway).to receive(:new).with(gateway_host, gateway_user, {}).and_return(net_ssh)
            expect(net_ssh).to receive(:open).with(anything, 22).and_return(2345)
            expect(Process).to receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345', '-i/tmp/.bosh/tmp/random_uuid_key', "-o StrictHostKeyChecking=yes", "")

            expect(director).to receive(:setup_ssh).and_return([:done, 42])
            expect(director).to receive(:get_task_result_log).with(42).
              and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
            expect(director).to receive(:cleanup_ssh)
            expect(ssh_session).to receive(:cleanup)

            expect(net_ssh).to receive(:close)
            expect(net_ssh).to receive(:shutdown!)

            command.shell('dea/0')
          end

          it 'should setup ssh with gateway host and user and identity file' do
            expect(Net::SSH::Gateway).to receive(:new).with(gateway_host, gateway_user, {keys: ['/tmp/private_file']}).and_return(net_ssh)
            expect(net_ssh).to receive(:open).with(anything, 22).and_return(2345)
            expect(Process).to receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345', '-i/tmp/.bosh/tmp/random_uuid_key', "-o StrictHostKeyChecking=yes", "")

            expect(director).to receive(:setup_ssh).and_return([:done, 42])
            expect(director).to receive(:get_task_result_log).with(42).
              and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
            expect(director).to receive(:cleanup_ssh)
            expect(ssh_session).to receive(:cleanup)

            expect(net_ssh).to receive(:close)
            expect(net_ssh).to receive(:shutdown!)

            command.add_option(:gateway_identity_file, '/tmp/private_file')
            command.shell('dea/0')
          end

          it 'should fail to setup ssh with gateway host and user when authentication fails' do
            expect(Net::SSH::Gateway).to receive(:new).with(gateway_host, gateway_user, {}).and_raise(Net::SSH::AuthenticationFailed)

            expect(director).to receive(:setup_ssh).and_return([:done, 42])
            expect(director).to receive(:get_task_result_log).with(42).
              and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
            expect(director).to receive(:cleanup_ssh)
            expect(ssh_session).to receive(:cleanup)

            expect {
              command.shell('dea/0')
            }.to raise_error(Bosh::Cli::CliError,
              "Authentication failed with gateway #{gateway_host} and user #{gateway_user}.")
          end

          context 'when ssh gateway is setup' do
            before do
              allow(Net::SSH::Gateway).to receive(:new).with(gateway_host, gateway_user, {}).and_return(net_ssh)
              allow(net_ssh).to receive(:open).with(anything, 22).and_return(2345)
              allow(director).to receive(:setup_ssh).and_return([:done, 42])
              allow(director).to receive(:cleanup_ssh)
              allow(net_ssh).to receive(:close)
              allow(net_ssh).to receive(:shutdown!)
            end

            context 'when the gateway connection raises an Exception' do
              let(:error_message) { 'a message' }
              before do
                allow(command).to receive(:warn)
                allow(Process).to receive(:spawn)
                allow(director).to receive(:get_task_result_log).with(42).
                    and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
              end

              context 'when closing the stream' do
                before { allow(net_ssh).to receive(:close).and_raise(Exception, error_message) }

                it 'should raise the error' do
                  expect { command.shell('dea/0') }.to raise_error(Exception, 'a message')
                end

                context "with 'closed stream' in the error message" do
                  let(:error_message) { 'closed stream' }
                  it 'should suppress the error' do
                    expect { command.shell('dea/0') }.to_not raise_error
                  end
                end
              end

              context 'when shutting down the gateway' do
                before { allow(net_ssh).to receive(:shutdown!).and_raise(Exception, error_message) }

                it 'should raise the error' do
                  expect { command.shell('dea/0') }.to raise_error(Exception, 'a message')
                end

                context "with 'closed stream' in the error message" do
                  let(:error_message) { 'closed stream' }

                  it 'should suppress the error' do
                    expect { command.shell('dea/0') }.to_not raise_error
                  end
                end
              end
            end

            context 'when strict host key checking is overriden to false' do
              before do
                command.add_option(:strict_host_key_checking, 'false')
              end

              it 'should disable strict host key checking' do
                expect(Process).to receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345', '-i/tmp/.bosh/tmp/random_uuid_key', "-o StrictHostKeyChecking=no", "")
                allow(director).to receive(:get_task_result_log).with(42).
                  and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
                command.shell('dea/0')
              end
            end

            context 'when host returns a host_public_key' do
              before do
                allow(ssh_session).to receive(:ssh_known_host_option).and_return("-o UserKnownHostsFile=/tmp/.bosh/tmp/random_uuid_known_hosts")
                allow(director).to receive(:get_task_result_log).and_return(JSON.dump([{'status' => 'success', 'ip' => '127.0.0.1', 'host_public_key' => 'fake_public_key'}]))
              end

              after do
                allow(director).to receive(:get_task_result_log).and_return(JSON.dump([{'status' => 'success', 'ip' => '127.0.0.1'}]))
              end

              it 'should call ssh with bosh known hosts path' do
                expect(Process).to receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345', '-i/tmp/.bosh/tmp/random_uuid_key', '-o StrictHostKeyChecking=yes', "-o UserKnownHostsFile=/tmp/.bosh/tmp/random_uuid_known_hosts")
                command.shell('dea/0')
              end
            end
          end
        end
      end
    end
  end

  context '#scp' do
    it 'sets up ssh to copy files' do
      allow(Net::SSH).to receive(:start)
      allow(director).to receive(:get_task_result_log).and_return(JSON.dump([{'status' => 'success', 'ip' => '127.0.0.1'}]))
      allow(director).to receive(:cleanup_ssh)
      expect(director).to receive(:setup_ssh).
        with('mycloud', 'dea', '0', 'testable_user', 'public_key', 'encrypted_password').
        and_return([:done, 1234])

      command.add_option(:upload, false)
      allow(command).to receive(:job_exists_in_deployment?).and_return(true)

      expect(ssh_session).to receive(:ssh_known_host_path).and_return("fake_path")
      expect(ssh_session).to receive(:ssh_private_key_path)

      command.scp('dea', '0', 'test', 'test')
    end
  end
end
