require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::DnsBinder do
    subject { described_class.new(deployment) }
    let (:deployment) { instance_double('Bosh::Director::DeploymentPlan::Planner') }

    describe '#bind_deployment' do
      context 'when dns is enabled' do
        before { allow(Config).to receive(:dns_enabled?).and_return(true) }

        before do
          Config.stub(:dns).and_return({ 'address' => '1.2.3.4' })
          Config.stub(:dns_domain_name).and_return('bosh')
        end

        it "should create the domain if it doesn't exist" do
          domain = nil
          deployment.should_receive(:dns_domain=) { |*args| domain = args.first }
          subject.bind_deployment

          Models::Dns::Domain.count.should == 1
          Models::Dns::Domain.first.should == domain
          domain.name.should == 'bosh'
          domain.type.should == 'NATIVE'
        end

        it 'should reuse the domain if it exists' do
          domain = Models::Dns::Domain.make(:name => 'bosh', :type => 'NATIVE')
          deployment.should_receive(:dns_domain=).with(domain)
          subject.bind_deployment

          Models::Dns::Domain.count.should == 1
        end

        it "should create the SOA, NS & A record if they doesn't exist" do
          domain = Models::Dns::Domain.make(:name => 'bosh', :type => 'NATIVE')
          deployment.should_receive(:dns_domain=)
          subject.bind_deployment

          Models::Dns::Record.count.should == 3
          records = Models::Dns::Record
          types = records.map { |r| r.type }
          types.should == %w[SOA NS A]
        end

        it 'should reuse the SOA record if it exists' do
          domain = Models::Dns::Domain.make(:name => 'bosh', :type => 'NATIVE')
          soa = Models::Dns::Record.make(:domain => domain, :name => 'bosh',
            :type => 'SOA')
          ns = Models::Dns::Record.make(:domain => domain, :name => 'bosh',
            :type => 'NS', :content => 'ns.bosh',
            :ttl => 14400) # 4h
          a = Models::Dns::Record.make(:domain => domain, :name => 'ns.bosh',
            :type => 'A', :content => '1.2.3.4',
            :ttl => 14400) # 4h
          deployment.should_receive(:dns_domain=)
          subject.bind_deployment

          soa.refresh
          ns.refresh
          a.refresh

          Models::Dns::Record.count.should == 3
          Models::Dns::Record.all.should == [soa, ns, a]
        end
      end

      context 'when dns is not enabled' do
        before { allow(Config).to receive(:dns_enabled?).and_return(false) }

        it 'does not create any new dns domains' do
          expect {
            subject.bind_deployment
          }.to_not change { Models::Dns::Domain.count }
        end

        it 'does not create any new dns records' do
          expect {
            subject.bind_deployment
          }.to_not change { Models::Dns::Record.count }
        end
      end
    end
  end
end
