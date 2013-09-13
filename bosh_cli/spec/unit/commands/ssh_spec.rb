  # Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'net/ssh/gateway'

describe Bosh::Cli::Command::Ssh do
  let(:command) { described_class.new }
  let(:net_ssh) { double('ssh') }
  let(:director) { double(Bosh::Cli::Client::Director) }
  let(:deployment) { 'mycloud' }

  let(:manifest) do
    {
        'name' => deployment,
        'uuid' => 'totally-and-universally-unique',
        'jobs' => [
            {
                'name' => 'dea',
                'instances' => 1
            }
        ]
    }
  end

  before do
    command.stub(director: director,
                 public_key: 'PUBKEY',
                 prepare_deployment_manifest: manifest)

    Process.stub(:waitpid)

    command.stub(:random_ssh_username).and_return('testable_user')

  end

  context 'shell' do
    before do
      command.stub(deployment: '/yo/heres/a/path')
    end

    describe 'invalid arguments' do
      it 'should fail if there is no deployment set' do
        command.stub(deployment: nil)

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
              'uuid' => 'totally-and-universally-unique',
              'jobs' => [
                  {
                      'name' => 'uaa',
                      'instances' => 1
                  }
              ]
          }
        end

        context 'when specifying the job index' do
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
              'uuid' => 'totally-and-universally-unique',
              'jobs' => [
                  {
                      'name' => 'dea',
                      'instances' => 1
                  }
              ]
          }
        end

        it 'should implicitly chooses the only instance if job index not provided' do
          command.should_not_receive(:choose)
          command.should_receive(:setup_interactive_shell).with('dea', 0)
          command.shell('dea')
        end

        it 'should implicitly chooses the only instance if job name not provided' do
          command.should_not_receive(:choose)
          command.should_receive(:setup_interactive_shell).with('dea', 0)
          command.shell
        end
      end

      context 'when there are many instances with that job name in the deployment' do
        let(:manifest) do
          {
              'name' => deployment,
              'uuid' => 'totally-and-universally-unique',
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
          command.should_receive(:choose).and_return(['dea', 3])
          command.should_receive(:setup_interactive_shell).with('dea', 3)
          command.shell
        end
      end
    end

    describe 'exec' do
      it 'should try to execute given command remotely' do
        command.should_receive(:perform_operation).with(:exec, 'dea', 0, ['ls -l'])
        command.shell('dea/0', 'ls -l')
      end
    end

    describe 'session' do
      before do
        command.add_option(:default_password, 'password')
      end

      it 'should try to setup interactive shell when a job index is given' do
        command.should_receive(:setup_interactive_shell).with('dea', 0)
        command.shell('dea', '0')
      end

      it 'should try to setup interactive shell when a job index is given as part of the job name' do
        command.should_receive(:setup_interactive_shell).with('dea', 0)
        command.shell('dea/0')
      end

      it 'should setup ssh' do
        Process.should_receive(:spawn).with('ssh', 'testable_user@127.0.0.1')

        director.should_receive(:setup_ssh).and_return([:done, 42])
        director.should_receive(:get_task_result_log).with(42).
            and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
        director.should_receive(:cleanup_ssh)

        command.shell('dea/0')
      end

      context 'with a gateway host' do
        let(:gateway_host) { 'gateway-host' }
        let(:gateway_user) { ENV['USER'] }

        before do
          command.add_option(:gateway_host, gateway_host)
        end

        it 'should setup ssh with gateway host' do
          Net::SSH::Gateway.should_receive(:new).with(gateway_host, gateway_user, {}).and_return(net_ssh)
          net_ssh.should_receive(:open).with(anything, 22).and_return(2345)
          Process.should_receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345')

          director.should_receive(:setup_ssh).and_return([:done, 42])
          director.should_receive(:get_task_result_log).with(42).
              and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
          director.should_receive(:cleanup_ssh)

          net_ssh.should_receive(:close)
          net_ssh.should_receive(:shutdown!)

          command.shell('dea/0')
        end

        context 'with a gateway user' do
          let(:gateway_user) { 'gateway-user' }

          before do
            command.add_option(:gateway_user, gateway_user)
          end

          it 'should setup ssh with gateway host and user' do
            Net::SSH::Gateway.should_receive(:new).with(gateway_host, gateway_user, {}).and_return(net_ssh)
            net_ssh.should_receive(:open).with(anything, 22).and_return(2345)
            Process.should_receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345')

            director.should_receive(:setup_ssh).and_return([:done, 42])
            director.should_receive(:get_task_result_log).with(42).
                and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
            director.should_receive(:cleanup_ssh)

            net_ssh.should_receive(:close)
            net_ssh.should_receive(:shutdown!)

            command.shell('dea/0')
          end

          it 'should setup ssh with gateway host and user and identity file' do
            Net::SSH::Gateway.should_receive(:new).with(gateway_host, gateway_user, {keys: ['/tmp/private_file']}).and_return(net_ssh)
            net_ssh.should_receive(:open).with(anything, 22).and_return(2345)
            Process.should_receive(:spawn).with('ssh', 'testable_user@localhost', '-p', '2345')

            director.should_receive(:setup_ssh).and_return([:done, 42])
            director.should_receive(:get_task_result_log).with(42).
                and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
            director.should_receive(:cleanup_ssh)

            net_ssh.should_receive(:close)
            net_ssh.should_receive(:shutdown!)

            command.add_option(:gateway_identity_file, '/tmp/private_file')
            command.shell('dea/0')
          end

          it 'should fail to setup ssh with gateway host and user when authentication fails' do
            Net::SSH::Gateway.should_receive(:new).with(gateway_host, gateway_user, {}).and_raise(Net::SSH::AuthenticationFailed)

            director.should_receive(:setup_ssh).and_return([:done, 42])
            director.should_receive(:get_task_result_log).with(42).
                and_return(JSON.generate([{'status' => 'success', 'ip' => '127.0.0.1'}]))
            director.should_receive(:cleanup_ssh)

            expect {
              command.shell('dea/0')
            }.to raise_error(Bosh::Cli::CliError,
                             "Authentication failed with gateway #{gateway_host} and user #{gateway_user}.")
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
            'uuid' => 'totally-and-universally-unique',
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
        command.stub(:job_exists_in_deployment?).and_return(false)
        expect {
          command.scp('dea/0')
        }.to raise_error(Bosh::Cli::CliError, "Job `dea' doesn't exist")
      end
    end
  end

  context '#cleanup' do
    context 'when the job name does not exist' do
      let(:manifest) do
        {
            'name' => deployment,
            'uuid' => 'totally-and-universally-unique',
            'jobs' => [
                {
                    'name' => 'uaa',
                    'instances' => 1
                }
            ]
        }
      end

      it 'should fail to setup ssh when a job name does not exists in deployment' do
        command.stub(:job_exists_in_deployment?).and_return(false)
        expect {
          command.cleanup('dea/0')
        }.to raise_error(Bosh::Cli::CliError, "Job `dea' doesn't exist")
      end
    end
  end
end
