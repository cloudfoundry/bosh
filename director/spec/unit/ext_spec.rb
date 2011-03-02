require File.dirname(__FILE__) + '/../spec_helper'

describe "Monkey Patches" do

  describe :to_openstruct do

    it "should convert a complex object to an openstruct" do
      hash = {
        :foo => [{:list => "test"}],
        :test => "bad",
        :nested => {:hash => 3}
      }
      result = hash.to_openstruct

      ostruct = OpenStruct.new("foo" => [OpenStruct.new("list" => "test")],
                               "test" => "bad",
                               "nested" => OpenStruct.new("hash" => 3))
      result.should == ostruct
    end

  end

  describe :recursive_merge! do

    it "should recursively merge hashes" do
      a = {:foo => {:bar => 5, :foz => 17}}
      b = {:test => "value", :foo => {:baz => 1, :bar => "hi"}}

      a.recursive_merge!(b).should == {:test=>"value", :foo=>{:bar=>"hi", :foz=>17, :baz=>1}}
    end

    it "should always use the new value type, even if it's not a hash" do
      a = {:foo => {:bar => 1}}
      b = {:foo => "value"}

      a.recursive_merge!(b).should == {:foo=>"value"}
    end

  end

end