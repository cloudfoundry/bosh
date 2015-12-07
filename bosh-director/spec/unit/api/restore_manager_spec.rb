require 'spec_helper'

module Bosh::Director
  describe Api::RestoreManager do
    let(:restore_manager) { described_class.new }

    let(:config) { Config.load_hash(test_config) }
    let(:test_config) do
      config = Psych.load(spec_asset('test-director-config.yml'))
      config['db'].merge!({
        'user' => 'fake-user',
        'password' => 'fake-password',
        'host' => 'fake-host',
      })
      config
    end

    before do
      App.new(config)
      ENV['LD_LIBRARY_PATH'] = 'fake-path'
    end

    describe '#restore_db' do
      it 'spawns a process to restore DB' do
        expect(Process).to receive(:spawn).with(
          'sudo',
          'LD_LIBRARY_PATH=fake-path',
          'restore-db',
          'sqlite',
          'fake-host',
          'fake-user',
          'fake-password',
          '/:memory:',
          'fake-dump.tgz',
          { :out => '/dev/null' }
        )
        restore_manager.restore_db('fake-dump.tgz')
      end
    end
  end
end