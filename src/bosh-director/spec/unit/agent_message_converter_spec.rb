require 'spec_helper'

module Bosh::Director
  describe AgentMessageConverter do
    describe '.convert_old_message_to_new' do
      it 'should leave a correctly formatted no-value response alone' do
        message = { 'state' => 'running', 'value' => nil, 'agent_task_id' => 1 }
        expect(AgentMessageConverter.convert_old_message_to_new(message)).to eq(message)
      end

      it 'should leave a correctly formatted response alone' do
        message = { 'state' => 'running', 'value' => { 'key1' => 1, 'key2' => 2 },
                    'agent_task_id' => 1 }
        expect(AgentMessageConverter.convert_old_message_to_new(message)).to eq(message)
      end

      it 'should fix a message that is not wrapped in value' do
        actual = { 'key1' => 1, 'key2' => 2 }
        expected = { 'state' => 'done', 'value' => actual, 'agent_task_id' => nil }
        expect(AgentMessageConverter.convert_old_message_to_new(actual)).to eq(expected)
      end

      it 'should fix a message that is an array' do
        actual = [1, 2, 3]
        expected = { 'state' => 'done', 'value' => actual, 'agent_task_id' => nil }
        expect(AgentMessageConverter.convert_old_message_to_new(actual)).to eq(expected)
      end

      it 'should fix a message that is in the old value format' do
        actual = { 'key1' => 1, 'key2' => 2 }
        expected = { 'state' => 'done', 'value' => { 'key1' => 1, 'key2' => 2 },
                     'agent_task_id' => nil }
        expect(AgentMessageConverter.convert_old_message_to_new(actual)).to eq(expected)
      end

      it 'should fix a nil message' do
        actual = nil
        expected = { 'state' => 'done', 'value' => nil, 'agent_task_id' => nil }
        expect(AgentMessageConverter.convert_old_message_to_new(actual)).to eq(expected)
      end

      it 'should wrap a message that has no value' do
        actual = { 'state' => 'done', 'agent_task_id' => 1 }
        expect(AgentMessageConverter.convert_old_message_to_new(actual)).to eq(actual)
      end

      it 'should fix a message that has no state or agent_task_id' do
        # If there was no state, then we are assuming this was the old message
        # format.
        actual = { 'value' => 'blah' }
        expected = { 'state' => 'done', 'value' => 'blah', 'agent_task_id' => nil }
        expect(AgentMessageConverter.convert_old_message_to_new(actual)).to eq(expected)
      end

      it 'should fix a message that has only a string' do
        actual = 'something'
        expected = { 'state' => 'done', 'value' => actual, 'agent_task_id' => nil }
        expect(AgentMessageConverter.convert_old_message_to_new(actual)).to eq(expected)
      end

      it 'should fix a message that has only a float' do
        actual = 1.01
        expected = { 'state' => 'done', 'value' => actual, 'agent_task_id' => nil }
        expect(AgentMessageConverter.convert_old_message_to_new(actual)).to eq(expected)
      end
    end
  end
end
