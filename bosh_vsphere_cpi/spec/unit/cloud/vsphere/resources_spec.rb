require 'spec_helper'

module VSphereCloud
  describe Resources do
    subject(:resources) { VSphereCloud::Resources.new(datacenter, config) }
    let(:config) { instance_double('VSphereCloud::Config', client: client, logger: logger) }
    let(:client) { instance_double('VSphereCloud::Client') }
    let(:datacenter) { instance_double('VSphereCloud::Resources::Datacenter') }
    let(:logger) { instance_double('Logger', info: nil, debug: nil) }

    let(:cluster) { double(:cluster) }
    before { allow(datacenter).to receive(:clusters).and_return({ "bar" => cluster }) }

    describe :pick_persistent_datastore_in_cluster do
      it "should return the datastore when it was placed successfully" do
        datastore = double(:datastore)
        expect(datastore).to receive(:allocate).with(1024)
        expect(cluster).to receive(:pick_persistent).with(1024).and_return(datastore)
        expect(resources.pick_persistent_datastore_in_cluster("bar", 1024)).
          to eq(datastore)
      end

      it "should return nil when it wasn't placed successfully" do
        expect(cluster).to receive(:pick_persistent).with(1024).and_return(nil)
        expect(resources.pick_persistent_datastore_in_cluster("bar", 1024)).
          to be_nil
      end
    end

    describe '#place' do
      it "should allocate memory and ephemeral disk space" do
        datastore = double(:datastore)
        allow(cluster).to receive(:name).and_return("bar")
        allow(cluster).to receive(:persistent).with("baz").and_return(datastore)

        scorer = double(:scorer)
        expect(scorer).to receive(:score).and_return(4)
        expect(VSphereCloud::Resources::Scorer).to receive(:new).
          with(config, cluster, 512, 1024, []).and_return(scorer)

        expect(cluster).to receive(:allocate).with(512)
        expect(cluster).to receive(:pick_ephemeral).with(1024).and_return(datastore)
        expect(datastore).to receive(:allocate).with(1024)

        expect(resources.place(512, 1024, [])).to eq([cluster, datastore])
      end

      it "should prioritize persistent locality" do
        cluster_a = double(:cluster_a)
        cluster_b = double(:cluster_b)
        allow(datacenter).to receive(:clusters).and_return({ "a" => cluster_a, "b" => cluster_b })

        datastore_a = double(:datastore_a)
        allow(cluster_a).to receive(:name).and_return("ds_a")
        allow(cluster_a).to receive(:persistent).with("ds_a").and_return(datastore_a)
        allow(cluster_a).to receive(:persistent).with("ds_b").and_return(nil)

        datastore_b = double(:datastore_b)
        allow(cluster_b).to receive(:name).and_return("ds_b")
        allow(cluster_b).to receive(:persistent).with("ds_a").and_return(nil)
        allow(cluster_b).to receive(:persistent).with("ds_b").and_return(datastore_b)

        scorer_b = double(:scorer_a)
        expect(scorer_b).to receive(:score).and_return(4)
        expect(VSphereCloud::Resources::Scorer).to receive(:new).
          with(config, cluster_b, 512, 1024, [2048]).and_return(scorer_b)

        expect(cluster_b).to receive(:allocate).with(512)
        expect(cluster_b).to receive(:pick_ephemeral).with(1024).
          and_return(datastore_b)
        expect(datastore_b).to receive(:allocate).with(1024)

        expect(resources.place(512, 1024,
                        [{ :size => 2048, :dc_name => "foo", :ds_name => "ds_a" },
                         { :size => 4096, :dc_name => "foo", :ds_name => "ds_b" }])).
          to eq([cluster_b, datastore_b])
      end

      it "should ignore locality when there is no space" do
        cluster_a = double(:cluster_a)
        cluster_b = double(:cluster_b)
        allow(datacenter).to receive(:clusters).and_return({ "a" => cluster_a, "b" => cluster_b })

        datastore_a = double(:datastore_a)
        allow(cluster_a).to receive(:name).and_return("ds_a")
        allow(cluster_a).to receive(:persistent).with("ds_a").and_return(datastore_a)
        allow(cluster_a).to receive(:persistent).with("ds_b").and_return(nil)

        datastore_b = double(:datastore_b)
        allow(cluster_b).to receive(:name).and_return("ds_b")
        allow(cluster_b).to receive(:persistent).with("ds_a").and_return(nil)
        allow(cluster_b).to receive(:persistent).with("ds_b").and_return(datastore_b)

        scorer_a = double(:scorer_a)
        expect(scorer_a).to receive(:score).twice.and_return(0)
        expect(VSphereCloud::Resources::Scorer).to receive(:new).
          with(config, cluster_a, 512, 1024, []).twice.and_return(scorer_a)

        scorer_b = double(:scorer_b)
        expect(scorer_b).to receive(:score).and_return(4)
        expect(VSphereCloud::Resources::Scorer).to receive(:new).
          with(config, cluster_b, 512, 1024, [2048]).and_return(scorer_b)

        expect(cluster_b).to receive(:allocate).with(512)
        expect(cluster_b).to receive(:pick_ephemeral).with(1024).
          and_return(datastore_b)
        expect(datastore_b).to receive(:allocate).with(1024)

        expect(resources.place(512, 1024,
                        [{ :size => 2048, :dc_name => "foo", :ds_name => "ds_a" }])).
          to eq([cluster_b, datastore_b])
      end

      context 'when clusters have not been manually specified' do
        let(:cloud_properties) do
          {
            ram: 2048,
            disk: 5000,
            cpu: 1,
          }
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
          allow(datacenter).to receive(:clusters).and_return({ "a" => cluster_a, "b" => cluster_b })

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
