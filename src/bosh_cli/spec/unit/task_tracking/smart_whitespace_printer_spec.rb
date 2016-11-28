require 'spec_helper'

describe Bosh::Cli::TaskTracking::SmartWhitespacePrinter do
  subject { described_class.new }

  describe '#print' do
    context 'when nothing was printed before' do
      [:line_around, :line_before, :before, :none].each do |separator|
        context "when printing with #{separator}" do
          it 'does not add space' do
            subject.print(separator, 'str1')
            expect(subject.output).to eq('str1')
          end
        end
      end
    end

    context 'when :line_around was used last time' do
      before { subject.print(:line_around, 'str1') }

      [:line_around, :line_before, :before, :none].each do |separator|
        context "when printing with #{separator}" do
          it 'adds a single blank line between two strings' do
            subject.print(separator, 'str2')
            expect(subject.output).to eq("str1\n\nstr2")
          end
        end
      end
    end

    context 'when :line_before was used last time' do
      before { subject.print(:line_before, 'str1') }

      context 'when printing with :line_around' do
        it 'adds a single blank line between two strings' do
          subject.print(:line_around, 'str2')
          expect(subject.output).to eq("str1\n\nstr2")
        end
      end

      context 'when printing with :line_before' do
        it 'adds a single blank line between two strings' do
          subject.print(:line_before, 'str2')
          expect(subject.output).to eq("str1\n\nstr2")
        end
      end

      context 'when printing with :before' do
        it 'puts next line right after another (w/o blank line)' do
          subject.print(:before, 'str2')
          expect(subject.output).to eq("str1\nstr2")
        end
      end

      context 'when printing with :none' do
        it 'prints immediately after first string w/o any breaks' do
          subject.print(:none, 'str2')
          expect(subject.output).to eq("str1str2")
        end
      end
    end

    context 'when :before was used last time' do
      before { subject.print(:before, 'str1') }

      context 'when printing with :line_around' do
        it 'adds a single blank line between two strings' do
          subject.print(:line_around, 'str2')
          expect(subject.output).to eq("str1\n\nstr2")
        end
      end

      context 'when printing with :line_before' do
        it 'adds a single blank line between two strings' do
          subject.print(:line_before, 'str2')
          expect(subject.output).to eq("str1\n\nstr2")
        end
      end

      context 'when printing with :before' do
        it 'puts next line right after another (w/o blank line)' do
          subject.print(:before, 'str2')
          expect(subject.output).to eq("str1\nstr2")
        end
      end

      context 'when printing with :none' do
        it 'prints immediately after first string w/o any breaks' do
          subject.print(:none, 'str2')
          expect(subject.output).to eq("str1str2")
        end
      end
    end

    context 'when :none was used last time' do
      before { subject.print(:none, 'str1') }

      context 'when printing with :line_around' do
        it 'adds a single blank line between two strings' do
          subject.print(:line_around, 'str2')
          expect(subject.output).to eq("str1\n\nstr2")
        end
      end

      context 'when printing with :line_before' do
        it 'adds a single blank line between two strings' do
          subject.print(:line_before, 'str2')
          expect(subject.output).to eq("str1\n\nstr2")
        end
      end

      context 'when printing with :before' do
        it 'keeps two lines one after another' do
          subject.print(:before, 'str2')
          expect(subject.output).to eq("str1\nstr2")
        end
      end

      context 'when printing with :none' do
        it 'prints immediately after first string w/o any breaks' do
          subject.print(:none, 'str2')
          expect(subject.output).to eq("str1str2")
        end
      end
    end

    context 'when unknown value is used' do
      it 'raises an error stating that value is not one of the separator' do
        expect {
          subject.print(:unknown, 'str2')
        }.to raise_error(ArgumentError, "Unknown separator :unknown")
      end
    end
  end

  describe '#finish' do
    context 'when nothing was printed before' do
      it 'does not add space' do
        subject.finish
        expect(subject.output).to eq('')
      end
    end

    [:line_around, :line_before, :before, :none].each do |separator|
      context "when #{separator} was used last time" do
        before { subject.print(separator, 'str1') }

        it 'adds a single line break to end the line' do
          subject.finish
          expect(subject.output).to eq("str1\n")
        end
      end
    end
  end
end
