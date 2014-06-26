require 'spec_helper'
require 'bosh/director/core/templates/source_erb'
require 'logger'

module Bosh::Director::Core::Templates
  describe SourceErb do
    let(:erb_contents) { 'the fake rendered results' }
    subject { SourceErb.new('source-name.erb', 'dest-name.txt', erb_contents, 'fake-job-template-name') }

    describe '#render' do
      let(:context) do
        Bosh::Template::EvaluationContext.new({})
      end
      let(:job_name) { 'fake-job-name' }
      let(:index) { 0 }
      let(:logger) { instance_double('Logger') }

      it 'renders the erb for the given template context' do
        expect(subject.render(context, job_name, index, logger)).to eq('the fake rendered results')
      end

      context 'when an error occurs in erb rendering' do
        let(:erb_contents) { '<% nil.no_method %>' }
        before do
          allow(logger).to receive(:debug)
        end

        let(:original_error) { "undefined method `no_method' for nil:NilClass" }

        let(:expected_message) do
          "Error filling in template `source-name.erb' for `fake-job-name/0' (line 1: #{original_error})"
        end

        it 'logs the error and the new message with the original backtrace' do
          expect(logger).to receive(:debug).with("#<NoMethodError: #{original_error}>")
          expect(logger).to receive(:debug) do |message|
            expect(message).to include(expected_message)
            expect(message).to include("fake-job-template-name/source-name.erb:1:in `get_binding'")
          end

          expect {
            subject.render(context, job_name, index, logger)
          }.to raise_error
        end

        it 'raises a informative error about the template being evaluated' do
          expect {
            subject.render(context, job_name, index, logger)
          }.to raise_error(expected_message)
        end
      end
    end
  end
end
