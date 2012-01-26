# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

require "common/thread_pool"

describe Bosh::ThreadPool do

  before(:all) do
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
  end

  it "should respect max threads" do
    max = 0
    current = 0
    lock = Mutex.new

    Bosh::ThreadPool.new(:max_threads => 2, :logger => @logger).wrap do |pool|
      4.times do
        pool.process do
          lock.synchronize do
            current += 1
            max = current if current > max
          end
          sleep(0.050)
          lock.synchronize do
            max = current if current > max
            current -= 1
          end
        end
      end
    end
    max.should be <= 2
  end

  it "should raise exceptions" do
    lambda {
      Bosh::ThreadPool.new(:max_threads => 2, :logger => @logger).wrap do |pool|
        5.times do |index|
          pool.process do
            sleep(0.050)
            raise "bad" if index == 4
          end
        end
      end
    }.should raise_exception("bad")
  end

  it "should stop processing new work when there was an exception" do
    max = 0
    lock = Mutex.new

    lambda {
      Bosh::ThreadPool.new(:max_threads => 1, :logger => @logger).wrap do |pool|
        10.times do |index|
          pool.process do
            lock.synchronize { max = index if index > max }
            sleep(0.050)
            raise "bad" if index == 4
          end
        end
      end
    }.should raise_exception("bad")

    max.should be == 4
  end

end
