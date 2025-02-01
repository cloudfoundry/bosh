require 'spec_helper'
require 'integration_support/sandbox'
require 'integration_support/uaa_service'

module IntegrationSupport
  describe Sandbox do
    let(:env_path) { 'DUMMY_PATH' }
    let(:gem_home) { 'DUMMY_GEM_HOME' }
    let(:gem_path) { 'DUMMY_GEM_PATH' }

    subject(:sandbox) do
      Sandbox.new(
        bosh_cli: 'bosh',
        bosh_cli_sha2_mode: false,
        db_opts: { type: 'sqlite' },
        debug: nil,
        env_path: env_path,
        gem_home: gem_home,
        gem_path: gem_path,
        command_builder_class: ShellCommandBuilder,
        log_level: 'DEBUG',
        log_to_stdout: false,
        update_vm_strategy: 'create-swap-delete',
        test_env_number: 0,
      )
    end

    describe '#run' do
      before do
        allow(sandbox).to receive(:start)
        allow(sandbox).to receive(:stop)
        allow(sandbox).to receive(:loop)
      end

      it 'starts the sandbox' do
        sandbox.run
        expect(sandbox).to have_received(:start)
      end

      context 'when an exception is raised' do
        context 'that is of type `Interrupt`' do
          before do
            allow(sandbox).to receive(:loop).and_raise(Interrupt)
          end

          it 'runs loop and then stops' do
            sandbox.run
            expect(sandbox).to have_received(:loop)
            expect(sandbox).to have_received(:stop)
          end
        end
      end

      context 'that is NOT of type `Interrupt`' do
        before do
          allow(sandbox).to receive(:loop).and_raise('Something unexpected and bad happened')
        end

        it 'raises runs stops and raises the exception' do
          expect { sandbox.run }.to raise_error(/unexpected/)
          expect(sandbox).to have_received(:stop)
        end
      end
    end

    describe '#director_config' do
      describe '#external_cpi_config' do
        let(:external_cpi_config) { sandbox.director_config.external_cpi_config }

        it 'exposes needed ENV vars for running ruby' do
          expect(external_cpi_config[:env_path]).to eq(env_path)
          expect(external_cpi_config[:gem_home]).to eq(gem_home)
          expect(external_cpi_config[:gem_path]).to eq(gem_path)
        end
      end
    end
  end
end
