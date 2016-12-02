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
    expect(tsort_packages("A" => ["B"], "B" => ["C"], "C" => [])).
        to eq(["C", "B", "A"])
  end

  it "whines on missing dependencies" do
    expect {
      tsort_packages("A" => ["B"], "C" => ["D"])
    }.to raise_error Bosh::Cli::MissingDependency,
                         "Package 'A' depends on missing package 'B'"
  end

  it "whines on circular dependencies" do
    expect {
      tsort_packages("foo" => ["bar"], "bar" => ["baz"], "baz" => ["foo"])
    }.to raise_error(Bosh::Cli::CircularDependency,
                         "Cannot resolve dependencies for 'bar': " +
                         "circular dependency with 'foo'")
  end

  it "can resolve nested dependencies" do
    sorted = tsort_packages("A" => ["B", "C"], "B" => ["C", "D"],
                            "C" => ["D"], "D" => [], "E" => [])
    expect(sorted.index("B")).to be <= sorted.index("A")
    expect(sorted.index("C")).to be <= sorted.index("A")
    expect(sorted.index("D")).to be <= sorted.index("B")
    expect(sorted.index("D")).to be <= sorted.index("C")
  end

end
