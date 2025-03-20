require 'spec_helper'

module Bosh
  describe Common do

    describe "::symbolize_keys" do
      let(:original) do
        {
          "foo1" => "bar",
          :foo2 => "bar",
          "foo3" => {
            "foo4" => "bar"
          }
        }.freeze
      end

      let(:expected) do
        {
          :foo1 => "bar",
          :foo2 => "bar",
          :foo3 => {
            :foo4 => "bar"
          }
        }.freeze
      end

      it "should not modify the original hash" do
        duplicate = original.dup
        Common.symbolize_keys(original)
        expect(original).to eq(duplicate)
      end

      it "should return a new hash with all keys as symbols" do
        expect(Common.symbolize_keys(original)).to eq(expected)
      end
    end

    describe "::which" do
      let(:path) do
        ENV['PATH'] + ":#{asset_path('')}"
      end

      it "should return the path when it finds the executable" do
        expect(Common.which("foo1", path)).to_not be_nil
      end

      it "should return the path when it finds an executable" do
        expect(Common.which(%w[foo2 foo1], path)).to match(%r{/foo1$})
      end

      it "should return nil when it isn't executable" do
        expect(Common.which("foo2", path)).to be_nil
      end

      it "should return nil when it doesn't find an executable" do
        expect(Common.which("foo1")).to be_nil
      end
    end

    describe "::retryable" do
      it 'should create an instance of Bosh::Common::Retryable' do
        opts = { on: StandardError }
        retryer = double(Common::Retryable)
        block = Proc.new { true }

        expect(Common::Retryable).to receive(:new).with(opts).and_return retryer
        expect(retryer).to receive(:retryer)

        Common.retryable(opts, &block)
      end
    end
  end
end
