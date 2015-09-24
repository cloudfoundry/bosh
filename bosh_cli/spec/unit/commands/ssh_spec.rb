require 'spec_helper'
require 'net/ssh/gateway'

describe Bosh::Cli::Command::Ssh do

  let(:command) { described_class.new }
  let(:net_ssh) { double('ssh') }
  let(:director) { double(Bosh::Cli::Client::Director, uuid: 'director-uuid') }
  let(:deployment) { 'mycloud' }

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
    allow(command).to receive_messages(director: director, public_key: 'PUBKEY', show_current_state: nil)
    File.open('fake-deployment', 'w') { |f| f.write(manifest.to_yaml) }
    allow(command).to receive(:deployment).and_return('fake-deployment')
    allow(Process).to receive(:waitpid)

    allow(File).to receive(:delete)

    allow(command).to receive(:random_ssh_username).and_return('testable_user')
    allow(command).to receive(:encrypt_password).with('password').and_return('encrypted_password')
    command.add_option(:default_password, 'password')
  end

  context 'shell' do
    describe 'invalid arguments' do
      it 'should fail if there is no deployment set' do
        allow(command).to receive_messages(deployment: nil)

        expect {
          command.shell('dea/1')
        }.to raise_error(Bosh::Cli::CliError, 'Please choose deployment first')
      end

      it 'should fail to setup ssh when a job index is not an Integer' do
        expect {
          command.shell('dea/dea')
        }.to raise_error(Bosh::Cli::CliError, 'Invalid job index, integer number expected')
      end

      context 'when there is no instance with that job name in the deployment' do
        let(:manifest) do
          {
              'name' => deployment,
              'director_uuid' => 'director-uuid',
              'releases' => [],
              'jobs' => [
                  {
                      'name' => 'uaa',
                      'instances' => 1
                  }
              ]
          }
        end

        context 'when specifying incorrect the job index' do
          it 'should fail to setup ssh' do
            expect {
              command.shell('dea/0')
            }.to raise_error(Bosh::Cli::CliError, "Job `dea' doesn't exist")
          end
        end

        context 'when not specifying the job index' do
          it 'should fail to setup ssh' do
            expect {
              command.shell('dea')
            }.to raise_error(Bosh::Cli::CliError, "Job `dea' doesn't exist")
          end
        end
      end

      context 'when there is only one instance with that job name in the deployment' do
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

        it 'should implicitly chooses the only instance if job index not provided' do
          expect(command).not_to receive(:choose)
          expect(command).to receive(:setup_interactive_shell).with('mycloud', 'dea', 0)
          command.shell('dea')
        end

        it 'should implicitly chooses the only instance if job name not provided' do
          expect(command).not_to receive(:choose)
          expect(command).to receive(:setup_interactive_shell).with('mycloud', 'dea', 0)
          command.shell
        end
      end

      context 'when there are many instances with that job name in the deployment' do
        let(:manifest) do
          {
              'name' => deployment,
              'director_uuid' => 'director-uuid',
              'releases' => [],
              'jobs' => [
                  {
                      'name' => 'dea',
                      'instances' => 5
                  }
              ]
          }
        end

        it 'should fail to setup ssh when a job index is not given' do
          expect {
            command.shell('dea')
          }.to raise_error(Bosh::Cli::CliError,
                           'You should specify the job index. There is more than one instance of this job type.')
        end

        it 'should prompt for an instance if job name not given' do
          expect(command).to receive(:choose).and_return(['dea', 3])
          expect(command).to receive(:setup_interactive_shell).with('mycloud', 'dea', 3)
          command.shell
        end
      end
    end

    describe 'exec' do
      it 'should try to execute given command remotely' do
        allow(Net::SSH).to receive(:start)
        allow(director).to receive(:get_task_result_log).and_return(JSON.dump([{'status' => 'success', 'ip' => '127.0.0.1'}]))
        allow(director).to receive(:cleanup_ssh)
        expect(director).to receive(:setup_ssh).
          with('mycloud', 'dea', 0, 'testable_user', 'PUBKEY', 'encrypted_password').
          and_return([:done, 1234])

        command.shell('dea/0', 'ls -l')
      end
    end

    describe 'session' do
      it 'should try to setup interactive shell when a job index is given' do
        expect(command).to receive(:setup_interactive_shell).with('mycloud', 'dea', 0)
        command.shell('dea', '0')
      end

      it 'should try to setup interactive shell when a job index is given as part of the job name' do
        expect(command).to receive(:setup_interactive_shell).with('mycloud', 'dea', 0)
        command.shell('dea/0')
      end

      it 'should setup ssh' do
        expect(Process).to receive(:spawn).with('ssh', 'testable_user@127.0.0.1', "-o StrictHostKeyChecking=yes", "")

        expect(director).to receive(:setup_ssh).and_return([:done, 42])
        expect(director).to receive(:get_task_result_log).with(42).
            and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
        expect(director).to receive(:cleanup_ssh)

        command.shell('dea/0')
      end

      context 'when host returns a host_public_key' do

        let(:host_file) { Tempfile.new("bosh_known_host") }

        before do
          allow(director).to receive(:setup_ssh).and_return([:done, 42])
          allow(director).to receive(:cleanup_ssh)
          allow(director).to receive(:get_task_result_log).and_return(JSON.dump([{'status' => 'success', 'ip' => '127.0.0.1', 'host_public_key' => 'fake_public_key'}]))
        end

        after do
          allow(director).to receive(:get_task_result_log).and_return(JSON.dump([{'status' => 'success', 'ip' => '127.0.0.1'}]))
        end

        it 'should create a bosh known host file' do
          expect(File).to receive(:new).and_return(host_file)
          expect(host_file).to receive(:puts).with("127.0.0.1 fake_public_key")
          expect(host_file).to receive(:close)
          expect(Process).to receive(:spawn)

          command.shell('dea/0')
        end

        it 'should call ssh with bosh known hosts path' do
          expect(Process).to receive(:spawn).with('ssh', 'testable_user@127.0.0.1', "-o StrictHostKeyChecking=yes", "-o UserKnownHostsFile=/tmp/bosh_known_host")

          command.shell('dea/0')
        end

        it 'should delete the bosh known host file on cleanup' do
           expect(File).to receive(:exist?).exactly(2).times.and_return(true)
           expect(File).to receive(:delete).with("/tmp/bosh_known_host")
           expect(Process).to receive(:spawn)

          command.shell('dea/0')
        end

      end

      context 'when strict host key checking is overriden to false' do
        before do
          command.add_option(:strict_host_key_checking, 'false')
        end

        it 'should disable strict host key checking' do
          expect(Process).to receive(:spawn).with('ssh', 'testable_user@127.0.0.1', "-o StrictHostKeyChecking=no", "")

          allow(director).to receive(:setup_ssh).and_return([:done, 42])
          allow(director).to receive(:get_task_result_log).with(42).
                                and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
          allow(director).to receive(:cleanup_ssh)

          command.shell('dea/0')
        end
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
          expect(Process).to receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345', "-o StrictHostKeyChecking=yes", "")

          expect(director).to receive(:setup_ssh).and_return([:done, 42])
          expect(director).to receive(:get_task_result_log).with(42).
              and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
          expect(director).to receive(:cleanup_ssh)

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
            expect(Process).to receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345', "-o StrictHostKeyChecking=yes", "")

            expect(director).to receive(:setup_ssh).and_return([:done, 42])
            expect(director).to receive(:get_task_result_log).with(42).
                and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
            expect(director).to receive(:cleanup_ssh)

            expect(net_ssh).to receive(:close)
            expect(net_ssh).to receive(:shutdown!)

            command.shell('dea/0')
          end

          it 'should setup ssh with gateway host and user and identity file' do
            expect(Net::SSH::Gateway).to receive(:new).with(gateway_host, gateway_user, {keys: ['/tmp/private_file']}).and_return(net_ssh)
            expect(net_ssh).to receive(:open).with(anything, 22).and_return(2345)
            expect(Process).to receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345', "-o StrictHostKeyChecking=yes", "")

            expect(director).to receive(:setup_ssh).and_return([:done, 42])
            expect(director).to receive(:get_task_result_log).with(42).
                and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
            expect(director).to receive(:cleanup_ssh)

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

            expect {
              command.shell('dea/0')
            }.to raise_error(Bosh::Cli::CliError,
                             "Authentication failed with gateway #{gateway_host} and user #{gateway_user}.")
          end

          context 'when strict host key checking is overriden to false' do
            before do
              command.add_option(:strict_host_key_checking, 'false')
            end

            it 'should disable strict host key checking' do
              allow(Net::SSH::Gateway).to receive(:new).with(gateway_host, gateway_user, {}).and_return(net_ssh)
              allow(net_ssh).to receive(:open).with(anything, 22).and_return(2345)
              expect(Process).to receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345', "-o StrictHostKeyChecking=no", "")

              allow(director).to receive(:setup_ssh).and_return([:done, 42])
              allow(director).to receive(:get_task_result_log).with(42).
                                      and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
              allow(director).to receive(:cleanup_ssh)

              allow(net_ssh).to receive(:close)
              allow(net_ssh).to receive(:shutdown!)

              command.shell('dea/0')
            end
          end
        end
      end
    end
  end

  context '#scp' do
    context 'when the job name does not exist' do
      let(:manifest) do
        {
            'name' => deployment,
            'director_uuid' => 'director-uuid',
            'releases' => [],
            'jobs' => [
                {
                    'name' => 'uaa',
                    'instances' => 1
                }
            ]
        }
      end

      it 'should fail to setup ssh when a job name does not exists in deployment' do
        command.add_option(:upload, true)
        allow(command).to receive(:job_exists_in_deployment?).and_return(false)
        expect {
          command.scp('dea/0')
        }.to raise_error(Bosh::Cli::CliError, "Job `dea' doesn't exist")
      end
    end

    it 'sets up ssh to copy files' do
      allow(Net::SSH).to receive(:start)
      allow(director).to receive(:get_task_result_log).and_return(JSON.dump([{'status' => 'success', 'ip' => '127.0.0.1'}]))
      allow(director).to receive(:cleanup_ssh)
      expect(director).to receive(:setup_ssh).
          with('mycloud', 'dea', 0, 'testable_user', 'PUBKEY', 'encrypted_password').
          and_return([:done, 1234])

      command.add_option(:upload, false)
      allow(command).to receive(:job_exists_in_deployment?).and_return(true)
      command.scp('dea', '0', 'test', 'test')
    end
  end

  context '#cleanup' do
    context 'when the job name does not exist' do
      let(:manifest) do
        {
            'name' => deployment,
            'director_uuid' => 'director-uuid',
            'releases' => [],
            'jobs' => [
                {
                    'name' => 'uaa',
                    'instances' => 1
                }
            ]
        }
      end

      it 'should fail to setup ssh when a job name does not exists in deployment' do
        allow(command).to receive(:job_exists_in_deployment?).and_return(false)
        expect {
          command.cleanup('dea/0')
        }.to raise_error(Bosh::Cli::CliError, "Job `dea' doesn't exist")
      end
    end
  end
end
