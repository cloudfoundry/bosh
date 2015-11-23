require 'spec_helper'
require 'timecop'

module Bosh::Director
  module DeploymentPlan
    describe Notifier do
      context 'event hooks' do
        let(:planner) { instance_double('Bosh::Director::DeploymentPlan::Planner', :canonical_name => 'Blorgh') }
        let(:nats_rpc) { instance_double('Bosh::Director::NatsRpc') }
        subject { Notifier.new('Blorgh', nats_rpc, logger) }

        let(:uuid) { SecureRandom.uuid }
        before do
          allow(SecureRandom).to receive(:uuid).and_return(uuid)
        end

        let(:director_config) { class_double('Bosh::Director::Config').as_stubbed_const }
        before do
          allow(director_config).to receive(:uuid) { uuid }
        end

        describe '#send_start_event' do
          let(:payload) do
            {
              'id' => SecureRandom.uuid,
              'severity' => 4, # corresponds to the `warning` severity level
              'title' => 'director - begin update deployment',
              'summary' => "Begin update deployment for '#{planner.canonical_name}' against Director '#{uuid}'",
              'created_at' => Time.now.to_i
            }
          end

          it 'sends an alert via NATS announcing the start of a deployment' do
            Timecop.freeze do
              expect(nats_rpc).to receive(:send_message).with('hm.director.alert', payload)

              subject.send_start_event
            end
          end
        end

        describe '#send_end_event' do
          let(:payload) do
            {
              'id'         => SecureRandom.uuid,
              'severity'   => 4, # corresponds to the `warning` severity level
              'title'      => 'director - finish update deployment',
              'summary'    => "Finish update deployment for '#{planner.canonical_name}' against Director '#{uuid}'",
              'created_at' => Time.now.to_i
            }
          end

          it 'sends an alert via NATS announcing the end of a deployment' do
            Timecop.freeze do
              expect(nats_rpc).to receive(:send_message).with('hm.director.alert', payload)

              subject.send_end_event
            end
          end
        end

        describe '#send_error_event' do
          let(:payload) do
            {
              'id'         => SecureRandom.uuid,
              'severity'   => 3, # corresponds to the `error` severity level
              'title'      => 'director - error during update deployment',
              'summary'    => "Error during update deployment for '#{planner.canonical_name}' against Director '#{uuid}': #<Exception: This is an exception>",
              'created_at' => Time.now.to_i
            }
          end
          let(:exception) { Exception.new('This is an exception') }

          it 'sends an alert via NATS announcing an error updating the deployment' do
            Timecop.freeze do
              expect(nats_rpc).to receive(:send_message).with('hm.director.alert', payload)

              subject.send_error_event exception
            end
          end
        end
      end
    end
  end
end
