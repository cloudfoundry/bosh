require 'spec_helper'
require 'cli'

describe Bosh::Cli::Command::Locks do
  let(:command) { described_class.new }
  let(:director) { instance_double('Bosh::Cli::Client::Director') }
  let(:target) { 'http://example.org' }

  before(:each) do
    allow(command).to receive(:director).and_return(director)
    allow(command).to receive(:nl)
    allow(command).to receive(:logged_in?).and_return(true)
    command.options[:target] = target
    allow(command).to receive(:show_current_state)
  end

  describe 'list' do
    before do
      allow(director).to receive(:list_locks).and_return(locks)
    end

    context 'when there are not any locks' do
      let(:locks) { [] }

      it 'should raise a Cli Error' do
        expect { command.locks }.to raise_error(Bosh::Cli::CliError, 'No locks')
      end
    end

    context 'when there are current locks' do
      let(:lock_timeout) { Time.now.to_i }
      let(:locks) {
        [
          { 'type'  => 'deployment', 'resource' => %w(test-deployment),               'timeout' => lock_timeout },
          { 'type'  => 'stemcells',  'resource' => %w(test-stemcell 1),            'timeout' => lock_timeout },
          { 'type'  => 'release',    'resource' => %w(test-release),                  'timeout' => lock_timeout },
          { 'type'  => 'compile',    'resource' => %w(test-package test-stemcell), 'timeout' => lock_timeout },
        ]
      }

      it 'should list current locks' do
        expect(command).to receive(:say) do |s|
          expect(locks).to be_all { |lock| s.to_s.include?(lock['type']) }
          expect(locks).to be_all { |lock| s.to_s.include?(lock['resource'].join(':')) }
          expect(s.to_s).to include Time.at(lock_timeout).utc.to_s
        end
        expect(command).to receive(:say).with("Locks total: #{locks.size}")

        command.locks
      end
    end
  end
end
