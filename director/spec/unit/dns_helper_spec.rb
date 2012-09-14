# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Director::DnsHelper do
  include Bosh::Director::ValidationHelper
  include Bosh::Director::DnsHelper

  describe :canonical do

    it "should be lowercase" do
      canonical("HelloWorld").should == "helloworld"
    end

    it "should convert underscores to hyphens" do
      canonical("hello_world").should == "hello-world"
    end

    it "should strip any non alpha numeric characters" do
      canonical("hello^world").should == "helloworld"
    end

    it "should reject strings that don't start with a letter " +
       "or end with a letter/number" do
      lambda {
        canonical("-helloworld")
      }.should raise_error(
                 BD::DnsInvalidCanonicalName,
                 "Invalid DNS canonical name `-helloworld', " +
                 "must begin with a letter")

      lambda {
        canonical("helloworld-")
      }.should raise_error(
                 BD::DnsInvalidCanonicalName,
                 "Invalid DNS canonical name `helloworld-', " +
                 "can't end with a hyphen")
    end

  end

  describe :dns_servers do
    it "should return nil when there are no DNS servers" do
      dns_servers('network', {}).should be_nil
    end

    it "should return an array of DNS servers" do
      dns_servers('network', {"dns" => %w[1.2.3.4 5.6.7.8]}).should ==
          %w[1.2.3.4 5.6.7.8]
    end

    it "should raise an error if a DNS server isn't specified with as an IP" do
      lambda {
        dns_servers('network', {"dns" => %w[1.2.3.4 foo.bar]})
      }.should raise_error
    end
  end

  describe :delete_dns_records do

    before(:each) do
      @logger = Logger.new("/dev/null")
    end

    BDM = Bosh::Director::Models
    it "should only delete records that match the deployment, job, and index" do
      domain = BDM::Dns::Domain.make

      {
        "0.job-a.network-a.dep.bosh" => "1.1.1.1",
        "1.job-a.network-a.dep.bosh" => "1.1.1.2",
        "0.job-b.network-b.dep.bosh" => "1.1.2.1",
        "0.job-a.network-a.dep-b.bosh" => "1.2.1.1"
      }.each do |key, value|
        BDM::Dns::Record.make(:domain => domain, :name => key,
                              :content => value)
      end

      {
        "1.1.1.1.in-addr.arpa" => "0.job-a.network-a.dep.bosh",
        "2.1.1.1.in-addr.arpa" => "1.job-a.network-a.dep.bosh",
        "1.2.1.1.in-addr.arpa" => "0.job-b.network-b.dep.bosh",
        "1.1.2.1.in-addr.arpa" => "0.job-a.network-a.dep-b.bosh"
      }.each do |key, value|
        BDM::Dns::Record.make(:PTR, :domain => domain, :name => key,
                              :content => value)
      end

      pattern = "0.job-a.%.dep.bosh"
      delete_dns_records(pattern, domain.id)

      expected = Set.new(%w[
        1.job-a.network-a.dep.bosh
        0.job-b.network-b.dep.bosh
        0.job-a.network-a.dep-b.bosh
        2.1.1.1.in-addr.arpa
        1.2.1.1.in-addr.arpa
        1.1.2.1.in-addr.arpa
      ])
      actual = Set.new
      BDM::Dns::Record.each { |record| actual << record.name }
      actual.should == expected
    end

    it "should delete the reverse domain if it is empty" do
      domain = BDM::Dns::Domain.make
      rdomain = BDM::Dns::Domain.make(:name => '1.1.1.in-addr.arpa')
      BDM::Dns::Record.make(:domain => rdomain, :type =>'SOA')
      BDM::Dns::Record.make(:domain => rdomain, :type =>'NS')

      BDM::Dns::Record.make(:domain => domain,
                            :name => "0.job-a.network-a.dep.bosh",
                            :content => "1.1.1.1")
      BDM::Dns::Record.make(:PTR, :domain => rdomain,
                            :name => "1.1.1.1.in-addr.arpa",
                            :content => "0.job-a.network-a.dep.bosh")

      pattern = "0.job-a.%.dep.bosh"
      delete_dns_records(pattern, domain.id)
      BDM::Dns::Record.all.should be_empty
    end
  end
end