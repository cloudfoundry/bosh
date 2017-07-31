require 'spec_helper'
require 'bosh/director/core/templates/source_erb'
require 'logger'

module Bosh::Director::Core::Templates
  describe SourceErb do
    let(:erb_contents) { '<%= "erb code to render" %>' } # not contents that HAVE been rendered -- contents that WILL be rendered
    subject { SourceErb.new('source-filename.erb', 'dest-filename.txt', erb_contents, 'fake-job-name') }

    describe '#render' do
      let(:context) do
        Bosh::Template::EvaluationContext.new({}, nil)
      end
      let(:logger) { instance_double('Logger') }

      it 'renders the erb for the given template context' do
        expect(subject.render(context, logger)).to eq('erb code to render')
      end

      context 'when an error occurs in erb rendering' do
        let(:erb_contents) { '<% nil.no_method %>' }
        before do
          allow(logger).to receive(:debug)
        end

        let(:original_error) { "undefined method `no_method' for nil:NilClass" }

        let(:expected_message) do
          "Error filling in template 'source-filename.erb' (line 1: #{original_error})"
        end

        it 'logs the error and the new message with the original backtrace' do
          expect(logger).to receive(:debug).with("#<NoMethodError: #{original_error}>")
          expect(logger).to receive(:debug) do |message|
            expect(message).to include(expected_message)
            expect(message).to include("fake-job-name/source-filename.erb:1:in 'get_binding'")
          end

          expect {
            subject.render(context, logger)
          }.to raise_error
        end

        it 'raises a informative error about the template being evaluated' do
          expect {
            subject.render(context, logger)
          }.to raise_error(expected_message)
        end
      end

      context 'when no space trimming is used' do
        let(:erb_contents) do
          <<-EOF
first line
<% a= 1 %>
second line
          EOF
        end
        let(:logger) { instance_double('Logger') }

        it 'contains an empty newline in the rendered result' do
          expect(subject.render(context, logger)).to eq("first line\n\nsecond line\n")
        end
      end

      context 'when space trimming is used' do
        let(:erb_contents) do
          <<-EOF
first line
<% a= 1 -%>
second line
          EOF
        end
        let(:logger) { instance_double('Logger') }

        it 'does not contain an empty newline in the rendered result' do
          expect(subject.render(context, logger)).to eq("first line\nsecond line\n")
        end
      end
    end
  end
end
