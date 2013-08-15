require 'spec_helper'

module Bosh
  module Deployer
    describe LoggerRenderer do
      let(:logger) { instance_double('Logger', info: nil) }
      subject(:renderer) { LoggerRenderer.new }

      before do
        Config.stub(logger: logger)
      end

      describe 'lifecycle' do
        it 'intilizes to default state' do
          expect(renderer.stage).to eq('Deployer')
          expect(renderer.total).to eq(0)
          expect(renderer.index).to eq(0)
        end

        it 'can enter a new stage' do
          renderer.enter_stage('New Stage', 50)

          expect(renderer.stage).to eq('New Stage')
          expect(renderer.total).to eq(50)
          expect(renderer.index).to eq(0)
        end

        it 'can update the index of a stage' do
          renderer.enter_stage('New Stage', 50)

          logger.should_receive(:info).with('New Stage - finished a thing')

          renderer.update(:finished, 'a thing')

          expect(renderer.stage).to eq('New Stage')
          expect(renderer.total).to eq(50)
          expect(renderer.index).to eq(1)
        end
      end

      describe '#step' do
        it 'steps' do
          logger.should_receive(:info).with('Deployer - started a thing').ordered
          logger.should_receive(:info).with('doing a thing').ordered
          logger.should_receive(:info).with('Deployer - finished a thing').ordered

          result = renderer.step('a thing') do
            Config.logger.info('doing a thing')
            'results'
          end
          expect(result).to eq 'results'
        end
      end
    end
  end
end