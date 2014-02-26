require 'spec_helper'

describe Bosh::Cli::ManifestWarnings do
  let(:manifest) { {} }
  let(:warning_messages) { {} }

  subject { described_class.new(manifest) }

  before do
    stub_const('Bosh::Cli::ManifestWarnings::WARNING_MESSAGES', warning_messages)

    allow(subject).to receive(:say)
  end

  describe '#report' do
    context 'when the manifest includes the key path specified' do
      let(:manifest) {
        {
          'foo' => {
            'bar' => 'anything',
          },
        }
      }
      let(:warning_messages) {
        { 'foo.bar' => 'a warning message' }
      }

      it 'prints manifest warnings' do
        subject.report

        expect(subject).to have_received(:say).with('a warning message')
      end
    end

    context 'when the keypath is longer than an existing keypath' do
      let(:manifest) {
        {
          'foo' => {
            'bar' => 'anything'
          },
        }
      }
      let(:warning_messages) {
        { 'foo.bar.any' => 'a warning message' }
      }

      it 'does not print anything' do
        subject.report

        expect(subject).not_to have_received(:say)
      end
    end

    context 'when the key path includes an array' do
      context 'when the keypath is longer than an existing keypath' do
        let(:manifest) {
          {
            'foo' => {
              'bar' => 'anything'
            },
          }
        }
        let(:warning_messages) {
          { 'foo.bar.[]' => 'a warning message' }
        }

        it 'does not print anything' do
          subject.report

          expect(subject).not_to have_received(:say)
        end
      end

      context 'when the manifest includes the key path specified' do
        let(:manifest) {
          {
            'foo' => [
              {
                'bar' => 'anything',
              },
            ],
          }
        }
        let(:warning_messages) {
          { 'foo.[].bar' => 'a warning message' }
        }

        it 'prints manifest warnings' do
          subject.report

          expect(subject).to have_received(:say).with('a warning message')
        end
      end

      context 'when the manifest includes the key path but not as an array' do
        let(:manifest) {
          {
            'foo' => {
              'bar' => 'anything',
              '[]' => 'some value'
            },
          }
        }
        let(:warning_messages) {
          { 'foo.[]' => 'a warning message' }
        }

        it 'does not print anything' do
          subject.report

          expect(subject).not_to have_received(:say)
        end
      end
    end

    context 'when the manifest includes an array but the keypath does not' do
      let(:manifest) {
        {
          'foo' => [
            {
              'bar' => 'anything',
            },
          ],
        }
      }
      let(:warning_messages) {
        { 'foo.bar' => 'a warning message' }
      }

      it 'does not print anything' do
        subject.report

        expect(subject).not_to have_received(:say)
      end
    end

    context 'when the manifest does not include the key path' do
      let(:manifest) { {} }
      let(:warning_messages) {
        { 'baz' => 'a warning message' }
      }

      it 'does not print anything' do
        subject.report

        expect(subject).not_to have_received(:say)
      end
    end
  end
end
