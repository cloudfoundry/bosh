# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::DependencyHelper do

  def sorter
    object = Object.new
    class << object
      include Bosh::Cli::DependencyHelper
    end
    object
  end

  def tsort_packages(*args)
    sorter.tsort_packages(*args)
  end

  def partial_order_sort(*args)
    sorter.partial_order_sort(*args)
  end

  it "resolves sorts simple dependencies" do
    tsort_packages("A" => ["B"], "B" => ["C"], "C" => []).
        should == ["C", "B", "A"]
  end

  it "whines on missing dependencies" do
    lambda {
      tsort_packages("A" => ["B"], "C" => ["D"])
    }.should raise_error Bosh::Cli::MissingDependency,
                         "Package 'A' depends on missing package 'B'"
  end

  it "whines on circular dependencies" do
    lambda {
      tsort_packages("foo" => ["bar"], "bar" => ["baz"], "baz" => ["foo"])
    }.should raise_error(Bosh::Cli::CircularDependency,
                         "Cannot resolve dependencies for 'bar': " +
                         "circular dependency with 'foo'")
  end

  it "can resolve nested dependencies" do
    sorted = tsort_packages("A" => ["B", "C"], "B" => ["C", "D"],
                            "C" => ["D"], "D" => [], "E" => [])
    sorted.index("B").should <= sorted.index("A")
    sorted.index("C").should <= sorted.index("A")
    sorted.index("D").should <= sorted.index("B")
    sorted.index("D").should <= sorted.index("C")
  end

end
