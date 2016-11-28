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

    expect(mc[:foo][:bar].changed?).to be(true)
    expect(mc[:foo][:bar].old).to eq(1)
    expect(mc[:foo][:bar].new).to eq(2)

    expect(mc[:foo][:baz].changed?).to be(true)
    expect(mc[:foo][:baz].old).to eq("purr")
    expect(mc[:foo][:baz].new).to eq("meow")

    expect(mc[:foo][:nc].changed?).to be(false)
    expect(mc[:foo][:nc].same?).to be(true)
    expect(mc[:foo][:nc].old).to eq("nc")
    expect(mc[:foo][:nc].new).to eq("nc")

    expect(mc[:foo][:properties][:a].changed?).to be(true)
    expect(mc[:foo][:properties][:b].removed?).to be(true)
    expect(mc[:foo][:properties][:c].mismatch?).to be(true)
    expect(mc[:foo][:properties][:d].added?).to be(true)

    expect(mc[:foo][:arr].changed?).to be(true)
    expect(mc[:arr].same?).to be(true)

    expect(mc[:zb].mismatch?).to be(true)
  end

end
