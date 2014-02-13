require 'spec_helper'

module VSphereCloud
  describe Resources do
    let(:config) { instance_double('VSphereCloud::Config', client: client, logger: logger) }
    let(:client) { instance_double('VSphereCloud::Client') }
    let(:logger) { instance_double('Logger', info: nil, debug: nil) }

    describe '#datacenters' do

      it "should fetch the datacenters the first time" do
        fake_datacenter = instance_double('VSphereCloud::Resources::Datacenter', name: 'fake-datacenter-name')
        VSphereCloud::Resources::Datacenter.should_receive(:new).with(config).once.and_return(fake_datacenter)

        resources = VSphereCloud::Resources.new(config)

        expect(resources.datacenters).to eq('fake-datacenter-name' => fake_datacenter)
      end

      it "should use cached datacenters" do
        fake_datacenter = instance_double('VSphereCloud::Resources::Datacenter', name: 'fake-datacenter-name')
        VSphereCloud::Resources::Datacenter.should_receive(:new).with(config).once.and_return(fake_datacenter)

        resources = VSphereCloud::Resources.new(config)
        2.times do
          expect(resources.datacenters).to eq('fake-datacenter-name' => fake_datacenter)
        end
      end

      it "should flush stale cached datacenters" do
        fake_datacenter = instance_double('VSphereCloud::Resources::Datacenter', name: 'fake-datacenter-name')
        VSphereCloud::Resources::Datacenter.should_receive(:new).with(config).twice.and_return(fake_datacenter)

        now = Time.now.to_i
        Time.should_receive(:now).and_return(now,
                                             now,
                                             now + Resources::STALE_TIMEOUT + 1,
                                             now + Resources::STALE_TIMEOUT + 1)

        resources = VSphereCloud::Resources.new(config)
        2.times do
          expect(resources.datacenters).to eq('fake-datacenter-name' => fake_datacenter)
        end
      end
    end

    describe :persistent_datastore do
      it "should return the persistent datastore" do
        dc = double(:dc)
        cluster = double(:cluster)
        dc.stub(:clusters).and_return({ "bar" => cluster })
        datastore = double(:datastore)
        cluster.stub(:persistent).with("baz").and_return(datastore)
        resources = VSphereCloud::Resources.new(config)
        resources.stub(:datacenters).and_return({ "foo" => dc })
        resources.persistent_datastore("foo", "bar", "baz").should == datastore
        resources.persistent_datastore("foo", "ba", "baz").should be_nil
      end
    end

    describe :validate_persistent_datastore do
      it "should return true if the provided datastore is still persistent" do
        dc = double(:dc)
        cluster = double(:cluster)
        dc.stub(:clusters).and_return({ "bar" => cluster })
        datastore = double(:datastore)
        cluster.stub(:persistent).with("baz").and_return(datastore)
        resources = VSphereCloud::Resources.new(config)
        resources.stub(:datacenters).and_return({ "foo" => dc })
        resources.validate_persistent_datastore("foo", "baz").should be(true)
      end

      it "should return false if the provided datastore is not persistent" do
        dc = double(:dc)
        cluster = double(:cluster)
        dc.stub(:clusters).and_return({ "bar" => cluster })
        cluster.stub(:persistent).with("baz").and_return(nil)
        resources = VSphereCloud::Resources.new(config)
        resources.stub(:datacenters).and_return({ "foo" => dc })
        resources.validate_persistent_datastore("foo", "baz").should be(false)
      end
    end

    describe :place_persistent_datastore do
      it "should return the datastore when it was placed successfully" do
        dc = double(:dc)
        cluster = double(:cluster)
        dc.stub(:clusters).and_return({ "bar" => cluster })
        datastore = double(:datastore)
        datastore.should_receive(:allocate).with(1024)
        cluster.should_receive(:pick_persistent).with(1024).and_return(datastore)
        resources = VSphereCloud::Resources.new(config)
        resources.stub(:datacenters).and_return({ "foo" => dc })
        resources.place_persistent_datastore("foo", "bar", 1024).
          should == datastore
      end

      it "should return nil when it wasn't placed successfully" do
        dc = double(:dc)
        cluster = double(:cluster)
        dc.stub(:clusters).and_return({ "bar" => cluster })
        cluster.should_receive(:pick_persistent).with(1024).and_return(nil)
        resources = VSphereCloud::Resources.new(config)
        resources.stub(:datacenters).and_return({ "foo" => dc })
        resources.place_persistent_datastore("foo", "bar", 1024).
          should be_nil
      end
    end

    describe '#place' do
      it "should allocate memory and ephemeral disk space" do
        dc = double(:dc)
        cluster = double(:cluster)
        dc.stub(:clusters).and_return({ "bar" => cluster })
        datastore = double(:datastore)
        cluster.stub(:name).and_return("bar")
        cluster.stub(:persistent).with("baz").and_return(datastore)
        resources = VSphereCloud::Resources.new(config)
        resources.stub(:datacenters).and_return({ "foo" => dc })

        scorer = double(:scorer)
        scorer.should_receive(:score).and_return(4)
        VSphereCloud::Resources::Scorer.should_receive(:new).
          with(config, cluster, 512, 1024, []).and_return(scorer)

        cluster.should_receive(:allocate).with(512)
        cluster.should_receive(:pick_ephemeral).with(1024).and_return(datastore)
        datastore.should_receive(:allocate).with(1024)

        resources.place(512, 1024, []).should == [cluster, datastore]
      end

      it "should prioritize persistent locality" do
        dc = double(:dc)
        cluster_a = double(:cluster_a)
        cluster_b = double(:cluster_b)
        dc.stub(:clusters).and_return({ "a" => cluster_a, "b" => cluster_b })

        datastore_a = double(:datastore_a)
        cluster_a.stub(:name).and_return("ds_a")
        cluster_a.stub(:persistent).with("ds_a").and_return(datastore_a)
        cluster_a.stub(:persistent).with("ds_b").and_return(nil)

        datastore_b = double(:datastore_b)
        cluster_b.stub(:name).and_return("ds_b")
        cluster_b.stub(:persistent).with("ds_a").and_return(nil)
        cluster_b.stub(:persistent).with("ds_b").and_return(datastore_b)

        resources = VSphereCloud::Resources.new(config)
        resources.stub(:datacenters).and_return({ "foo" => dc })

        scorer_b = double(:scorer_a)
        scorer_b.should_receive(:score).and_return(4)
        VSphereCloud::Resources::Scorer.should_receive(:new).
          with(config, cluster_b, 512, 1024, [2048]).and_return(scorer_b)

        cluster_b.should_receive(:allocate).with(512)
        cluster_b.should_receive(:pick_ephemeral).with(1024).
          and_return(datastore_b)
        datastore_b.should_receive(:allocate).with(1024)

        resources.place(512, 1024,
                        [{ :size => 2048, :dc_name => "foo", :ds_name => "ds_a" },
                         { :size => 4096, :dc_name => "foo", :ds_name => "ds_b" }]).
          should == [cluster_b, datastore_b]
      end

      it "should ignore locality when there is no space" do
        dc = double(:dc)
        cluster_a = double(:cluster_a)
        cluster_b = double(:cluster_b)
        dc.stub(:clusters).and_return({ "a" => cluster_a, "b" => cluster_b })

        datastore_a = double(:datastore_a)
        cluster_a.stub(:name).and_return("ds_a")
        cluster_a.stub(:persistent).with("ds_a").and_return(datastore_a)
        cluster_a.stub(:persistent).with("ds_b").and_return(nil)

        datastore_b = double(:datastore_b)
        cluster_b.stub(:name).and_return("ds_b")
        cluster_b.stub(:persistent).with("ds_a").and_return(nil)
        cluster_b.stub(:persistent).with("ds_b").and_return(datastore_b)

        resources = VSphereCloud::Resources.new(config)
        resources.stub(:datacenters).and_return({ "foo" => dc })

        scorer_a = double(:scorer_a)
        scorer_a.should_receive(:score).twice.and_return(0)
        VSphereCloud::Resources::Scorer.should_receive(:new).
          with(config, cluster_a, 512, 1024, []).twice.and_return(scorer_a)

        scorer_b = double(:scorer_b)
        scorer_b.should_receive(:score).and_return(4)
        VSphereCloud::Resources::Scorer.should_receive(:new).
          with(config, cluster_b, 512, 1024, [2048]).and_return(scorer_b)

        cluster_b.should_receive(:allocate).with(512)
        cluster_b.should_receive(:pick_ephemeral).with(1024).
          and_return(datastore_b)
        datastore_b.should_receive(:allocate).with(1024)

        resources.place(512, 1024,
                        [{ :size => 2048, :dc_name => "foo", :ds_name => "ds_a" }]).
          should == [cluster_b, datastore_b]
      end

      context 'when clusters have been manually specified' do
        let(:target_cluster) { instance_double('VSphereCloud::Resources::Cluster', name: 'target-cluster') }
        let(:cloud_properties) do
          {
            'ram' => 2048,
            'disk' => 5000,
            'cpu' => 1,
            'datacenters' => [{
                                'name' => 'test-datacenter',
                                'clusters' => [{ 'name' => 'target-cluster' }],
                              }],
          }
        end

        it 'uses the specified cluster for placement' do
          pending

          dc = double(:dc)
          cluster_a = double(:cluster_a)
          cluster_b = double(:cluster_b)
          datastore_a = double(:datastore_a)
          cluster_a.stub(:name).and_return("ds_a")
          cluster_a.stub(:persistent).with("ds_a").and_return(datastore_a)
          cluster_a.stub(:persistent).with("ds_b").and_return(nil)

          datastore_b = double(:datastore_b)
          cluster_b.stub(:name).and_return("ds_b")
          cluster_b.stub(:persistent).with("ds_a").and_return(nil)
          cluster_b.stub(:persistent).with("ds_b").and_return(datastore_b)
          resources = VSphereCloud::Resources.new(config)
          resources.stub(:datacenters).and_return({ "foo" => dc })
          scorer_a = double(:scorer_a)
          scorer_a.should_receive(:score).twice.and_return(0)
          VSphereCloud::Resources::Scorer.should_receive(:new).
            with(config, cluster_a, 512, 1024, []).twice.and_return(scorer_a)

          scorer_b = double(:scorer_b)
          scorer_b.should_receive(:score).and_return(4)
          VSphereCloud::Resources::Scorer.should_receive(:new).
            with(config, cluster_b, 512, 1024, []).and_return(scorer_b)



          allow(dc).to receive(:clusters).and_return({ "a" => cluster_a, "b" => cluster_b, 'target-cluster' => target_cluster })

          allow(target_cluster).to receive(:persistent).with("baz").and_return(datastore_a)

          allow(target_cluster).to receive(:allocate).with(512)
          allow(target_cluster).to receive(:pick_ephemeral).with(1024).and_return(datastore_a)
          allow(target_cluster).to receive(:allocate).with(1024)

          expect(resources.place(512, 1024, [])).to eq([target_cluster, datastore_a])
        end
      end

      context 'when clusters have not been manually specified' do
        subject(:resources) { VSphereCloud::Resources.new(config) }
        let(:cloud_properties) do
          {
            ram: 2048,
            disk: 5000,
            cpu: 1,
          }
        end
        let(:datacenter) { instance_double('VSphereCloud::Resources::Datacenter') }
        before do
          allow(class_double('VSphereCloud::Resources::Datacenter').as_stubbed_const).
            to receive(:new).with(config).and_return(datacenter)
        end
        let(:cluster_a) { instance_double('VSphereCloud::Resources::Cluster', name: 'cluster_a') }
        let(:cluster_b) { instance_double('VSphereCloud::Resources::Cluster', name: 'cluster_b') }

        it 'should allocate memory and ephemeral disk space' do
          allow(datacenter).to receive(:name).and_return('datacenter_name')

          datastore_a = double('VSphereCloud::Resources::Datastore')
          allow(datacenter).to receive(:clusters).and_return({ "bar" => cluster_a })

          allow(config).to receive(:datacenter_name).and_return('fake_data_center')
          allow(cluster_a).to receive(:name).and_return("bar")
          allow(cluster_a).to receive(:persistent).with("baz").and_return(datastore_a)

          scorer = instance_double('VSphereCloud::Resources::Scorer')
          allow(scorer).to receive(:score).and_return(4)
          allow(VSphereCloud::Resources::Scorer).to receive(:new).
                                                      with(config, cluster_a, 512, 1024, []).and_return(scorer)

          allow(cluster_a).to receive(:allocate).with(512)
          allow(cluster_a).to receive(:pick_ephemeral).with(1024).and_return(datastore_a)
          allow(datastore_a).to receive(:allocate).with(1024)

          expect(resources.place(512, 1024, [])).to eq([cluster_a, datastore_a])
        end

        it 'should prioritize persistent locality' do
          allow(datacenter).to receive(:name).and_return('foo')

          datastore_a = instance_double('VSphereCloud::Resources::Datastore')
          datastore_b = instance_double('VSphereCloud::Resources::Datastore')

          allow(datacenter).to receive(:clusters).and_return({ "a" => cluster_a, "b" => cluster_b })

          allow(cluster_a).to receive(:persistent).with('ds_a').and_return(datastore_a)
          allow(cluster_a).to receive(:persistent).with('ds_b').and_return(nil)
          allow(cluster_b).to receive(:persistent).with('ds_a').and_return(nil)
          allow(cluster_b).to receive(:persistent).with('ds_b').and_return(datastore_b)

          scorer_a = instance_double('VSphereCloud::Resources::Scorer')
          allow(scorer_a).to receive(:score).and_return(5)

          allow(VSphereCloud::Resources::Scorer).to receive(:new).
                                                      with(config, cluster_a, 512, 1024, [2048]).and_return(scorer_a)

          scorer_b = instance_double('VSphereCloud::Resources::Scorer')
          expect(scorer_b).to receive(:score).and_return(4)
          allow(VSphereCloud::Resources::Scorer).to receive(:new).
                                                      with(config, cluster_b, 512, 1024, [2048]).and_return(scorer_b)

          allow(cluster_b).to receive(:allocate).with(512)
          allow(cluster_b).to receive(:pick_ephemeral).with(1024).
                                and_return(datastore_b)
          allow(datastore_b).to receive(:allocate).with(1024)

          expect(resources.place(512, 1024,
                                 [{ :size => 2048, :dc_name => "foo", :ds_name => "ds_a" },
                                  { :size => 4096, :dc_name => "foo", :ds_name => "ds_b" },
                                 ])).to eq([cluster_b, datastore_b])
        end

        it 'should ignore locality when there is no space' do
          allow(datacenter).to receive(:name).and_return('foo')
          datacenter.stub(:clusters).and_return({ "a" => cluster_a, "b" => cluster_b })

          scorer_a = instance_double('VSphereCloud::Resources::Scorer')
          allow(scorer_a).to receive(:score).twice.and_return(0)
          allow(VSphereCloud::Resources::Scorer).to receive(:new).
                                                      with(config, cluster_a, 512, 1024, []).twice.and_return(scorer_a)

          datastore_a = instance_double('VSphereCloud::Resources::Datastore')
          allow(cluster_a).to receive(:persistent).with('ds_a').and_return(datastore_a)
          allow(cluster_b).to receive(:persistent).with('ds_a').and_return(nil)


          scorer_b = instance_double('VSphereCloud::Resources::Scorer')
          allow(scorer_b).to receive(:score).and_return(4)
          allow(VSphereCloud::Resources::Scorer).to receive(:new).
                                                      with(config, cluster_b, 512, 1024, [2048]).and_return(scorer_b)

          allow(cluster_b).to receive(:allocate).with(512)


          datastore_b = instance_double('VSphereCloud::Resources::Datastore')
          allow(cluster_b).to receive(:pick_ephemeral).with(1024).
                                and_return(datastore_b)
          allow(datastore_b).to receive(:allocate).with(1024)

          expect(resources.place(512, 1024,
                                 [{ :size => 2048, :dc_name => "foo", :ds_name => "ds_a" }])).
            to eq([cluster_b, datastore_b])
        end
      end
    end
  end
end
