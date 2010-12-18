require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Director::CycleHelper do

  it "should detect simple cycles" do
    graph = {
      :A => [:B],
      :B => [:A]
    }

    lambda {Bosh::Director::CycleHelper.check_for_cycle([:A, :B, :C]) {|vertex| graph[vertex]}}.should raise_exception
  end

  it "should detect more complicated cycles" do
    graph = {
      :A => [:B],
      :B => [:C],
      :C => [:D],
      :D => [:B]
    }

    lambda {Bosh::Director::CycleHelper.check_for_cycle([:A, :B, :C]) {|vertex| graph[vertex]}}.should raise_exception
  end

  it "should not detect cycles when it's acyclic" do
    graph = {
      :A => [:B, :C],
      :B => [:C]
    }

    Bosh::Director::CycleHelper.check_for_cycle([:A, :B, :C]) {|vertex| graph[vertex]}
  end

  it "should return connected vertices when requested" do
    graph = {
      :A => [:B, :C],
      :B => [:C]
    }

    result = Bosh::Director::CycleHelper.check_for_cycle(
        [:A, :B, :C], :connected_vertices => true) {|vertex| graph[vertex]}
    result.should eql({:connected_vertices=>{:C=>[], :A=>[:C, :B], :B=>[:C]}})
  end

end