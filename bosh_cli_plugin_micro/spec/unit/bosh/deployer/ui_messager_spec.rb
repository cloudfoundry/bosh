require 'spec_helper'
require 'bosh/deployer/ui_messager'

describe Bosh::Deployer::UiMessager do
  describe '#info' do
    subject(:ui_messenger) { described_class.new(messages, options) }
    let(:messages) { { known: 'known-message-text' } }
    let(:options) { {} }

    context 'when the message is known' do
      context 'when silent option is not set' do
        it 'shows the message to the user' do
          expect(ui_messenger).to receive(:say).with('known-message-text')
          ui_messenger.info(:known)
        end
      end

      context 'when silent option is set' do
        before { options[:silent] = true }

        it 'does not show message to the user' do
          expect(ui_messenger).not_to receive(:say)
          ui_messenger.info(:known)
        end
      end
    end

    context 'when the message is unknown' do
      def self.it_raises_an_error
        it 'raises an UnknownMessageName' do
          expect { ui_messenger.info(:unknown) }
            .to raise_error(described_class::UnknownMessageName, 'unknown')
        end

        it 'does show any message to the user' do
          expect(ui_messenger).not_to receive(:say)
          expect { ui_messenger.info(:unknown) }.to raise_error # expect to silent
        end
      end

      context 'when silent option is not set' do
        it_raises_an_error
      end

      context 'when silent option is set' do
        before { options[:silent] = true }
        it_raises_an_error
      end
    end

    context 'when the message is not a symbol' do
      let(:invalid_value) { double('non-symbol') }

      def self.it_raises_an_error
        it 'raises an ArgumentError' do
          expect { ui_messenger.info(invalid_value) }
            .to raise_error(ArgumentError, 'message_name must be a Symbol')
        end

        it 'does show any message to the user' do
          expect(ui_messenger).not_to receive(:say)
          expect { ui_messenger.info(invalid_value) }.to raise_error # expect to silent
        end
      end

      context 'when silent option is not set' do
        it_raises_an_error
      end

      context 'when silent option is set' do
        before { options[:silent] = true }
        it_raises_an_error
      end
    end
  end
end
