# -*- encoding: utf-8 -*-
# Copyright (c) 2013 GoPivotal, Inc.

require 'spec_helper'
require 'cli'

describe Bosh::Cli::Command::Locks do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Client::Director) }
  let(:target) { 'http://example.org' }

  before(:each) do
    command.stub(:director).and_return(director)
    command.stub(:nl)
    command.stub(:logged_in? => true)
    command.options[:target] = target
  end

  describe :list do
    before do
      director.should_receive(:list_locks).and_return(locks)
    end

    context 'when there are not any locks' do
      let(:locks) { [] }

      it 'should raise a Cli Error' do
        expect do
          command.locks
        end.to raise_error(Bosh::Cli::CliError, 'No locks')
      end
    end

    context 'when there are current locks' do
      let(:lock_timeout) { Time.now.to_i }
      let(:locks) {
        [
          { 'type'  => 'deployment', 'resource' => ['test-deployment'],               'timeout' => lock_timeout },
          { 'type'  => 'stemcells',  'resource' => ['test-stemcell', '1'],            'timeout' => lock_timeout },
          { 'type'  => 'release',    'resource' => ['test-release'],                  'timeout' => lock_timeout },
          { 'type'  => 'compile',    'resource' => ['test-package', 'test-stemcell'], 'timeout' => lock_timeout },
        ]
      }

      it 'should list current locks' do
        command.should_receive(:say) do |s|
          locks.each do |lock|
            expect(s.to_s).to include lock['type']
            expect(s.to_s).to include lock['resource'].join(':')
          end
          expect(s.to_s).to include Time.at(lock_timeout).utc.to_s
        end
        command.should_receive(:say).with("Locks total: #{locks.size}")

        command.locks
      end
    end
  end
end
