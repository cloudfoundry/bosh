require 'spec_helper'
require 'bosh/dev/sandbox/main'

module Bosh::Dev::Sandbox
  describe Main do
    let(:uaa){ double(UaaService)}
    before do
      allow(UaaService).to receive(:new).and_return(uaa)
      allow(uaa).to receive(:port).and_return(9999)
      allow(uaa).to receive(:reconfigure)
    end

    subject(:sandbox) { Main.new({type: 'sqlite'}, nil, 0) }

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

      it 'waits for an interrupt from the user to stop' do
        allow(sandbox).to receive(:loop).and_raise(Interrupt)
        sandbox.run
        expect(sandbox).to have_received(:loop)
        expect(sandbox).to have_received(:stop)
      end

      it 'always stops the standbox' do
        allow(sandbox).to receive(:loop).and_raise('Something unexpected and bad happened')
        expect { sandbox.run }.to raise_error(/unexpected/)
        expect(sandbox).to have_received(:stop)
      end

      it 'exposes needed ENV vars for running ruby' do
        ENV['PATH'] = 'dummy-path'
        ENV['GEM_HOME'] = 'dummy-gem-home'
        ENV['GEM_PATH'] = 'dummy-gem-path'

        external_cpi_config = sandbox.director_config.external_cpi_config
        expect(external_cpi_config[:env_path]).to eq(ENV['PATH'])
        expect(external_cpi_config[:gem_home]).to eq(ENV['GEM_HOME'])
        expect(external_cpi_config[:gem_path]).to eq(ENV['GEM_PATH'])
      end
    end
  end
end
