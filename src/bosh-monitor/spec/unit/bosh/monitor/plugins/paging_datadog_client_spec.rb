require 'spec_helper'

class FakeDatadogClient
  def emit_points_called?
    @emit_points_called || false
  end

  def emit_points(_metric, _points, _options = {})
    @emit_points_called = true
  end

  attr_reader :last_event

  def emit_event(event)
    @last_event = event
  end
end

describe PagingDatadogClient do
  let(:datadog_recipient) { 'pagerduty-bosh-service' }
  let(:wrapped_client) { FakeDatadogClient.new }
  let(:paging_client) { PagingDatadogClient.new(datadog_recipient, wrapped_client) }

  describe 'delegating to the wrapped client' do
    describe 'unmodified calls' do
      it "doesn't modify the #emit_points calls and passes them through" do
        paging_client.emit_points('fake.metric', [Time.now.to_i, 25], {})
        expect(wrapped_client.emit_points_called?).to be(true)
      end
    end

    describe 'modified calls' do
      let(:priority) { 'normal' }
      let(:alert) do
        Dogapi::Event.new(
          'message',
          date_happened: Time.now.to_i - 300,
          priority: priority,
          tags: %w[some tags],
        )
      end

      context 'with a normal priority alert' do
        let(:priority) { 'normal' }

        it 'adds the datadog recipient to the end of the message' do
          paging_client.emit_event(alert)
          expect(wrapped_client.last_event.msg_text).to eq("message @#{datadog_recipient}")
        end
      end

      context 'with a low prioity alert' do
        let(:priority) { 'low' }

        it 'does not add the datadog recipient to the end of the message' do
          paging_client.emit_event(alert)
          expect(wrapped_client.last_event.msg_text).not_to include("@#{datadog_recipient}")
        end
      end

      it 'keeps the rest of the attributes the same' do
        alert_hash = alert.to_hash
        alert_hash.delete(:msg_text)
        paging_client.emit_event(alert)

        last_hash = wrapped_client.last_event.to_hash
        last_hash.delete(:msg_text)
        expect(last_hash).to eq(alert_hash)
      end
    end
  end
end
