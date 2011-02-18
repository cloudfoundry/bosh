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

  def sort_jobs(*args)
    sorter.sort_jobs(*args)
  end

  it "resolves sorts simple dependencies" do
    tsort_packages("A" => ["B"], "B" => ["C"], "C" => []).should == ["C", "B", "A"]
  end

  it "whines on missing dependencies" do
    lambda {
      tsort_packages("A" => ["B"], "C" => [ "D" ])
    }.should raise_error Bosh::Cli::MissingDependency, "Package 'A' depends on missing package 'B'"
  end

  it "whines on circular dependencies" do
    lambda {
      tsort_packages("foo" => ["bar"], "bar" => ["baz"], "baz" => ["foo"])
    }.should raise_error Bosh::Cli::CircularDependency, "Cannot resolve dependencies for 'baz': circular dependency with 'bar'"
  end

  it "can resolve nested dependencies" do
    sorted = tsort_packages("A" => ["B", "C"], "B" => ["C", "D"], "C" => ["D"], "D" => [], "E" => [])
    sorted.index("B").should <= sorted.index("A")
    sorted.index("C").should <= sorted.index("A")
    sorted.index("D").should <= sorted.index("B")
    sorted.index("D").should <= sorted.index("C")
  end

  it "can sort jobs according to some partial order list" do
    sort_jobs(%w(a b c d e)).should == %w(a b c d e)
    sort_jobs(%w(a b c d e), %w(d b a)).should == %w(d b a c e)
    sort_jobs(%w(a b c d e), %w()).should == %w(a b c d e)
    sort_jobs(%w(a b c d e), %w(e d c b a)).should == %w(e d c b a)
  end

end
