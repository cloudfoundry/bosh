# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::HashChangeset do

  def changeset(m1, m2)
    cs = Bosh::Cli::HashChangeset.new
    cs.add_hash(m1, :old)
    cs.add_hash(m2, :new)
    cs
  end

  it "contains changeset for two hashes" do
    m1 = {
      :foo => {
        :bar => 1,
        :baz => "purr",
        :nc => "nc",
        :properties => {
          :a => "1",
          :b => "2",
          :c => "3"
        },
        :arr => %w(a b c)
      },
      :arr => [1, 2, 3],
      :zb => { :a => 2, :b => 3}
    }

    m2 = {
      :foo => {
        :bar => 2,
        :baz => "meow",
        :nc => "nc",
        :properties => {
          :a => "2",
          :d => "7",
          :c => 3
        },
        :arr => %w(a b c d e)
      },
      :arr => [1, 2, 3],
      :zb => "test"
    }

    mc = changeset(m1, m2)

    mc[:foo][:bar].changed?.should be(true)
    mc[:foo][:bar].old.should == 1
    mc[:foo][:bar].new.should == 2

    mc[:foo][:baz].changed?.should be(true)
    mc[:foo][:baz].old.should == "purr"
    mc[:foo][:baz].new.should == "meow"

    mc[:foo][:nc].changed?.should be(false)
    mc[:foo][:nc].same?.should be(true)
    mc[:foo][:nc].old.should == "nc"
    mc[:foo][:nc].new.should == "nc"

    mc[:foo][:properties][:a].changed?.should be(true)
    mc[:foo][:properties][:b].removed?.should be(true)
    mc[:foo][:properties][:c].mismatch?.should be(true)
    mc[:foo][:properties][:d].added?.should be(true)

    mc[:foo][:arr].changed?.should be(true)
    mc[:arr].same?.should be(true)

    mc[:zb].mismatch?.should be(true)
  end

end
