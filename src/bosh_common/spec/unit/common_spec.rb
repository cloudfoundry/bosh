require 'spec_helper'

describe Bosh::Common do

  describe "::symbolize_keys" do
    ORIGINAL = {
        "foo1" => "bar",
        :foo2 => "bar",
        "foo3" => {
            "foo4" => "bar"
        }
    }.freeze

    EXPECTED = {
        :foo1 => "bar",
        :foo2 => "bar",
        :foo3 => {
            :foo4 => "bar"
        }
    }.freeze

    it "should not modify the original hash" do
      duplicate = ORIGINAL.dup
      Bosh::Common.symbolize_keys(ORIGINAL)
      expect(ORIGINAL).to eq(duplicate)
    end

    it "should return a new hash with all keys as symbols" do
      expect(Bosh::Common.symbolize_keys(ORIGINAL)).to eq(EXPECTED)
    end
  end

  describe "::which" do
    let(:path) do
      ENV['PATH'] + ":#{File.expand_path('../../assets', __FILE__)}"
    end

    it "should return the path when it finds the executable" do
      expect(Bosh::Common.which("foo1", path)).to_not be_nil
    end

    it "should return the path when it finds an executable" do
      expect(Bosh::Common.which(%w[foo2 foo1], path)).to match(%r{/foo1$})
    end

    it "should return nil when it isn't executable" do
      expect(Bosh::Common.which("foo2", path)).to be_nil
    end

    it "should return nil when it doesn't find an executable" do
      expect(Bosh::Common.which("foo1")).to be_nil
    end
  end

  describe "::retryable" do
    it 'should create an instance of Bosh::Retryable' do
      opts = {on: StandardError}
      retryer = double(Bosh::Retryable)
      block = Proc.new { true }

      expect(Bosh::Retryable).to receive(:new).with(opts).and_return retryer
      expect(retryer).to receive(:retryer)

      Bosh::Common.retryable(opts, &block)
    end
  end

end
