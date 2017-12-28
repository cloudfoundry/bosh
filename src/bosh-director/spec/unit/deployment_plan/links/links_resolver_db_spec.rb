require 'spec_helper'

describe 'links_resolver' do
  let(:deployment_name) {'fake-deployment'}
  let(:release_name) {'fake-release'}
  let(:deployment_model) {Bosh::Director::Models::Deployment.make(name: deployment_name)}

  let(:instance_group) do
    instance_group = instance_double(Bosh::Director::DeploymentPlan::InstanceGroup, {
      name: 'ig_1',
      deployment_name: deployment_name,
      link_paths: []
    })
    allow(instance_group).to receive_message_chain(:persistent_disk_collection, :non_managed_disks).and_return([])
    allow(instance_group).to receive(:jobs).and_return(jobs)
    allow(instance_group).to receive(:link_path).and_return(link_path)
    instance_group
  end

  let(:provider_job) do
    job = instance_double(Bosh::Director::DeploymentPlan::Job, name: 'job_1')
    allow(job).to receive(:provided_links).and_return(provided_links)
    job
  end

  let(:jobs) do
    [provider_job]
  end

  let(:provided_links) do
    [
      Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'p1')
    ]
  end

  let(:consumer_job) do
    job = instance_double(Bosh::Director::DeploymentPlan::Job, name: 'job_1')
    allow(job).to receive(:model_consumed_links).and_return(consumed_links)
    allow(job).to receive(:consumes_link_info).and_return(consumed_link_info)
    job
  end

  let(:consumed_link_info) do
    {}
  end

  let(:consumed_links) do
    [
      Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'c1')
    ]
  end

  let(:links_resolver) do
    Bosh::Director::DeploymentPlan::LinksResolver.new(deployment_plan, logger)
  end

  let(:deployment_plan) do
    deployment_plan = instance_double(Bosh::Director::DeploymentPlan::Planner, name: deployment_name, model: deployment_model)
    allow(deployment_plan).to receive(:add_link_provider)
    allow(deployment_plan).to receive(:add_link_consumer)
    deployment_plan
  end

  let(:link_spec) do
    {
      'deployment_name' => deployment_name,
      'domain' => 'bosh',
      'default_network' => 'net_a',
      'networks' => ['net_a', 'net_b'],
      'instance_group' => instance_group.name,
      'instances' => [],
    }
  end

  let(:link_path) do
    instance_double(Bosh::Director::DeploymentPlan::LinkPath,
                    deployment: deployment_name,
                    instance_group: 'ig_1',
                    owner: 'job_1',
                    name: 'original_provider_name',
                    manual_spec: nil)
  end

  before do
    allow(Bosh::Director::DeploymentPlan::Link).to receive_message_chain(:new, :spec).and_return(link_spec)
  end

  context 'when an instance group is updated' do
    context 'and the provided link name specified in the release did not change' do
      it 'should update the previous provider' do
        providers = Bosh::Director::Models::Links::LinkProvider

        links_resolver.add_providers(instance_group)

        expect(providers.count).to eq(1)
        original_provider_id = providers.first.id

        links_resolver.add_providers(instance_group)

        expect(providers.count).to eq(1)
        updated_provider_id = providers.first.id

        expect(updated_provider_id).to eq(original_provider_id)
      end
    end
  end

  context 'when a job provides two different names but is aliased to the same name' do
    let(:provided_links) do
      [
        Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'p1'),
        Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'p2'),
      ]
    end

    it 'should create two provider intents in the database' do
      links_resolver.add_providers(instance_group)

      expect(Bosh::Director::Models::Links::LinkProviderIntent.count).to eq(2)
    end
  end

  describe '#add_providers' do
    let(:jobs) do
      [provider_job]
    end

    let(:link_path) do
      instance_double(Bosh::Director::DeploymentPlan::LinkPath,
                      deployment: deployment_name,
                      instance_group: 'ig_1',
                      owner: 'job_1',
                      name: 'original_provider_name',
                      manual_spec: nil)
    end

    let(:links_manager) do
      Bosh::Director::Links::LinksManager.new
    end

    before do
      allow(Bosh::Director::Links::LinksManager).to receive(:new).and_return(links_manager)
      allow(instance_group).to receive(:link_path).and_return(link_path)
      allow(instance_group).to receive(:add_resolved_link)

      consumer = Bosh::Director::Models::Links::LinkConsumer.create(
        deployment: deployment_model,
        instance_group: 'ig_1',
        name: 'job_1',
        type: 'job'
      )

      Bosh::Director::Models::Links::LinkConsumerIntent.create(
        link_consumer: consumer,
        original_name: 'p1',
        type: 'pt1',
        optional: false,
        blocked: false
      )
    end

    context 'when there are jobs that provide links' do
      it 'should add a provider' do
        old_count = Bosh::Director::Models::Links::LinkProvider.count
        links_resolver.add_providers(instance_group)
        new_count = Bosh::Director::Models::Links::LinkProvider.count

        expect(old_count).to eq(0)
        expect(new_count).to eq(1)
        provider = Bosh::Director::Models::Links::LinkProvider.first
        expect(provider.instance_group).to eq('ig_1')
        expect(provider.name).to eq('job_1')
        expect(provider.type).to eq('job')
      end

      it 'should add a provider intent' do
        old_count = Bosh::Director::Models::Links::LinkProviderIntent.count
        links_resolver.add_providers(instance_group)
        new_count = Bosh::Director::Models::Links::LinkProviderIntent.count

        expect(old_count).to eq(0)
        expect(new_count).to eq(1)
        provider_intent = Bosh::Director::Models::Links::LinkProviderIntent.first
        provider = Bosh::Director::Models::Links::LinkProvider.first
        expect(provider_intent.link_provider).to eq(provider)
        expect(provider_intent.original_name).to eq('p1')
        expect(provider_intent.type).to eq('pt1')
      end

      context 'when provider is updated' do
        before do
          links_resolver.add_providers(instance_group)
          provider = Bosh::Director::Models::Links::LinkProvider.first
          expect(provider.instance_group).to eq('ig_1')
          expect(provider.name).to eq('job_1')
          expect(provider.type).to eq('job')

          provider_intent = Bosh::Director::Models::Links::LinkProviderIntent.first
          expect(provider_intent.link_provider).to eq(provider)
          expect(provider_intent.name).to eq('foo')
          expect(provider_intent.original_name).to eq('p1')
          expect(provider_intent.type).to eq('pt1')
        end

        it 'should only update and not create a new provider' do
          allow(provider_job).to receive(:provided_links).and_return(
            [ Bosh::Director::DeploymentPlan::TemplateLink.new('bar', 'pt1', false, false, 'p1') ]
          )
          old_count = Bosh::Director::Models::Links::LinkProvider.count
          old_link_provider = Bosh::Director::Models::Links::LinkProvider.first
          old_provider_id = old_link_provider[:id]

          links_resolver.add_providers(instance_group)
          new_count = Bosh::Director::Models::Links::LinkProvider.count

          expect(old_count).to eq(1)
          expect(new_count).to eq(1)
          provider = Bosh::Director::Models::Links::LinkProvider.first
          expect(provider.instance_group).to eq('ig_1')
          expect(provider.name).to eq('job_1')
          expect(provider.type).to eq('job')
          expect(provider[:id]).to eq(old_provider_id)
        end

        it 'should only update and not create a new provider intent' do
          allow(provider_job).to receive(:provided_links).and_return(
            [ Bosh::Director::DeploymentPlan::TemplateLink.new('bar', 'pt1', false, false, 'p1') ]
          )
          old_count = Bosh::Director::Models::Links::LinkProviderIntent.count
          provider_intent = Bosh::Director::Models::Links::LinkProviderIntent.first
          provider = Bosh::Director::Models::Links::LinkProvider.first
          expect(provider_intent.link_provider).to eq(provider)
          expect(provider_intent.name).to eq('foo')
          expect(provider_intent.original_name).to eq('p1')
          expect(provider_intent.type).to eq('pt1')

          provided_links = [ Bosh::Director::DeploymentPlan::TemplateLink.new('bar', 'pt1', false, false, 'p1') ]
          links_resolver.add_providers(instance_group)

          new_count = Bosh::Director::Models::Links::LinkProviderIntent.count

          expect(old_count).to eq(1)
          expect(new_count).to eq(1)

          provider_intent = Bosh::Director::Models::Links::LinkProviderIntent.first
          provider = Bosh::Director::Models::Links::LinkProvider.first
          expect(provider_intent.link_provider).to eq(provider)
          expect(provider_intent.name).to eq('bar')
          expect(provider_intent.original_name).to eq('p1')
          expect(provider_intent.type).to eq('pt1')

        end
      end
    end

    context 'when there are unmanaged persistent disks' do
      let(:provided_links) {[]}

      def new_persistent_disk(name)
        disk_type = Bosh::Director::DeploymentPlan::DiskType.new('disk_type_name', 1000, {})
        Bosh::Director::DeploymentPlan::PersistentDiskCollection::NewPersistentDisk.new(name, disk_type)
      end

      before do
        allow(instance_group).to receive_message_chain(:persistent_disk_collection, :non_managed_disks).and_return(
          [new_persistent_disk('disk_1'), new_persistent_disk('disk_2')]
        )
      end

      context 'when there are no jobs' do
        let(:jobs) {[]}

        it 'should add a provider' do
          links_resolver.add_providers(instance_group)

          provider = Bosh::Director::Models::Links::LinkProvider.find(
            deployment_id: 1,
            instance_group: instance_group.name,
            name: instance_group.name,
            type: 'instance_group'
          )

          expect(provider).to_not be_nil
        end

        it 'should add a provider intent per disk' do
          links_resolver.add_providers(instance_group)

          actual_intents = Bosh::Director::Models::Links::LinkProviderIntent.all.map do |intent|
            {name: intent[:original_name], content: JSON.parse(intent[:content])}
          end

          expected_intents = [
            {name: 'disk_1', content: {'deployment_name' => "fake-deployment", 'properties' => {'name' => "disk_1"}, 'networks' => [], 'instances' => []}},
            {name: 'disk_2', content: {'deployment_name' => "fake-deployment", 'properties' => {'name' => "disk_2"}, 'networks' => [], 'instances' => []}}
          ]

          expect(actual_intents).to match_array(expected_intents)
        end

      end
    end

    context 'when there are jobs providing links and unmanaged disks' do
      def new_persistent_disk(name)
        disk_type = Bosh::Director::DeploymentPlan::DiskType.new('disk_type_name', 1000, {})
        Bosh::Director::DeploymentPlan::PersistentDiskCollection::NewPersistentDisk.new(name, disk_type)
      end

      before do
        allow(instance_group).to receive_message_chain(:persistent_disk_collection, :non_managed_disks).and_return(
          [new_persistent_disk('disk_1'), new_persistent_disk('disk_2')]
        )
      end

      context 'when the names are the same' do
        let(:provided_links) do
          [
            Bosh::Director::DeploymentPlan::TemplateLink.new('disk1', 'disk', false, false, 'disk1'),
            Bosh::Director::DeploymentPlan::TemplateLink.new('disk2', 'disk', false, false, 'disk2'),
          ]
        end

        it 'should create providers' do
          links_resolver.add_providers(instance_group)
          expect(Bosh::Director::Models::Links::LinkProvider.count).to eq(2)

          disk_provider = Bosh::Director::Models::Links::LinkProvider.find(
            deployment_id: 1,
            instance_group: instance_group.name,
            name: instance_group.name,
            type: 'instance_group'
          )

          expect(disk_provider).to_not be_nil

          link_provider = Bosh::Director::Models::Links::LinkProvider.find(
            deployment_id: 1,
            instance_group: instance_group.name,
            name: provider_job.name,
            type: 'job'
          )

          expect(link_provider).to_not be_nil
        end

        it 'should create the appropriate intents for each provider' do
          links_resolver.add_providers(instance_group)

          actual_intents = Bosh::Director::Models::Links::LinkProviderIntent.all.map do |intent|
            {original_name: intent[:original_name], name: intent[:name], link_provider_id: intent.link_provider_id, content: JSON.parse(intent[:content])}
          end

          expected_intents = [
            {original_name: 'disk1', name: 'disk1', link_provider_id: 1, content: {"deployment_name" => "fake-deployment", "domain" => "bosh", "default_network" => "net_a", "networks" => ["net_a", "net_b"], "instance_group" => "ig_1", "instances" => []}},
            {original_name: 'disk2', name: 'disk2', link_provider_id: 1, content: {"deployment_name" => "fake-deployment", "domain" => "bosh", "default_network" => "net_a", "networks" => ["net_a", "net_b"], "instance_group" => "ig_1", "instances" => []}},
            {original_name: 'disk_1', name: 'disk_1', link_provider_id: 2, content: {'deployment_name' => "fake-deployment", 'properties' => {'name' => "disk_1"}, 'networks' => [], 'instances' => []}},
            {original_name: 'disk_2', name: 'disk_2', link_provider_id: 2, content: {'deployment_name' => "fake-deployment", 'properties' => {'name' => "disk_2"}, 'networks' => [], 'instances' => []}}
          ]

          expect(actual_intents).to match_array(expected_intents)
        end
      end

      context 'when the names are different' do
        let(:provided_links) do
          [
            Bosh::Director::DeploymentPlan::TemplateLink.new('foo', 'pt1', false, false, 'p1'),
          ]
        end
        it 'should create providers' do
          links_resolver.add_providers(instance_group)
          expect(Bosh::Director::Models::Links::LinkProvider.count).to eq(2)

          disk_provider = Bosh::Director::Models::Links::LinkProvider.find(
            deployment_id: 1,
            instance_group: instance_group.name,
            name: instance_group.name,
            type: 'instance_group'
          )

          expect(disk_provider).to_not be_nil

          link_provider = Bosh::Director::Models::Links::LinkProvider.find(
            deployment_id: 1,
            instance_group: instance_group.name,
            name: provider_job.name,
            type: 'job'
          )

          expect(link_provider).to_not be_nil
        end

        it 'should create the appropriate intents for each provider' do
          links_resolver.add_providers(instance_group)

          actual_intents = Bosh::Director::Models::Links::LinkProviderIntent.all.map do |intent|
            {original_name: intent[:original_name], name: intent[:name], link_provider_id: intent.link_provider_id, content: JSON.parse(intent[:content])}
          end

          expected_intents = [
            {original_name: 'p1', name: 'foo', link_provider_id: 1, content: {"deployment_name" => "fake-deployment", "domain" => "bosh", "default_network" => "net_a", "networks" => ["net_a", "net_b"], "instance_group" => "ig_1", "instances" => []}},
            {original_name: 'disk_1', name: 'disk_1', link_provider_id: 2, content: {'deployment_name' => "fake-deployment", 'properties' => {'name' => "disk_1"}, 'networks' => [], 'instances' => []}},
            {original_name: 'disk_2', name: 'disk_2', link_provider_id: 2, content: {'deployment_name' => "fake-deployment", 'properties' => {'name' => "disk_2"}, 'networks' => [], 'instances' => []}}
          ]

          expect(actual_intents).to match_array(expected_intents)
        end
      end
    end
  end

  describe '#resolve' do
    context 'when job consumes link from the same deployment' do
      let(:jobs) do
        [consumer_job]
      end

      let(:link_path) do
        instance_double(Bosh::Director::DeploymentPlan::LinkPath,
                        deployment: deployment_name,
                        instance_group: 'ig_1',
                        owner: 'job_1',
                        name: 'original_provider_name',
                        manual_spec: nil)
      end

      let(:links_manager) do
        Bosh::Director::Links::LinksManager.new
      end

      before do
        allow(deployment_plan).to receive(:use_dns_addresses?).and_return(true)
        allow(Bosh::Director::Links::LinksManager).to receive(:new).and_return(links_manager)
        allow(instance_group).to receive(:link_path).and_return(link_path)
        allow(instance_group).to receive(:add_resolved_link)

        provider = Bosh::Director::Models::Links::LinkProvider.create(
          deployment: deployment_model,
          instance_group: 'ig_1',
          name: 'job_1',
          type: 'job'
        )

        Bosh::Director::Models::Links::LinkProviderIntent.create(
          link_provider: provider,
          original_name: 'original_provider_name',
          type: 'pt1',
          name: 'foo',
          shared: true,
          consumable: true,
          content: {
            'instances' =>
              [
                {
                  'address' => 'net-2-addr',
                  'addresses' => {
                    'net-1' => 'net-1-addr',
                    'net-2' => 'net-2-addr',
                    'net-3' => 'net-3-addr',
                  }
                }
              ]
          }.to_json
        )
      end

      it 'calls find or creates a new consumer' do
        expect(links_manager).to receive(:find_or_create_consumer).once.and_call_original
        expect(links_manager).to receive(:find_or_create_consumer_intent).once.and_call_original
        links_resolver.resolve(instance_group)
      end

      it 'adds consumer to deployment_plan' do
        expect(deployment_plan).to receive(:add_link_consumer)
        links_resolver.resolve(instance_group)
      end

      it 'adds consumer intent with alias to database' do
        links_resolver.resolve(instance_group)
        link_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.first
        expect(link_consumer_intent[:original_name]).to eq('c1')
        expect(link_consumer_intent[:name]).to eq('foo')
      end

      it 'adds link to links table' do
        links_resolver.resolve(instance_group)
        expected_content = {
          'instances' => [
            {
              'address' => 'net-2-addr'
            }
          ]
        }
        expect(Bosh::Director::Models::Links::Link.count).to eq(1)
        link = Bosh::Director::Models::Links::Link.first
        expect(link.name).to eq('c1')
        expect(link.link_provider_intent_id).to eq(1)
        expect(link.link_consumer_intent_id).to eq(1)
        expect(JSON.parse(link.link_content)).to match(expected_content)
        expect(link.created_at).to_not be_nil
      end

      context 'when link alias changes' do
        let(:consumed_links) do
          [
            Bosh::Director::DeploymentPlan::TemplateLink.new('bar', 'pt1', false, false, 'p1')
          ]
        end

        let(:jobs) do
          [consumer_job]
        end

        before do
          provider = Bosh::Director::Models::Links::LinkProvider.create(
            deployment: deployment_model,
            instance_group: 'ig_1',
            name: 'job_1',
            type: 'job'
          )

          consumer = Bosh::Director::Models::Links::LinkConsumer.create(
            deployment: deployment_model,
            instance_group: 'ig_1',
            name: 'job_1',
            type: 'job'
          )

          @link_provider_intent = Bosh::Director::Models::Links::LinkProviderIntent.create(
            link_provider_id: provider[:id],
            original_name: 'original_provider_name',
            type: 'pt1',
            name: 'foo',
            shared: true,
            consumable: true,
            content: {
              'instances' =>
                [
                  {
                    'address' => 'net-2-addr',
                    'addresses' => {
                      'net-1' => 'net-1-addr',
                      'net-2' => 'net-2-addr',
                      'net-3' => 'net-3-addr',
                    }
                  }
                ]
            }.to_json
          )

          @link_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.create(
            link_consumer_id: consumer[:id],
            original_name: 'original_provider_name',
            type: 'pt1',
            optional: false,
            blocked: false
          )

          @created_link = Bosh::Director::Models::Links::Link.create(
            link_provider_intent: @link_provider_intent,
            link_consumer_intent: @link_consumer_intent,
            name: 'p1',
            link_content: 'link_content',
            created_at: Time.now
          )
        end

        it 'the link uses the same consumer' do
          old_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(id: @created_link[:link_consumer_intent_id])
          old_consumer = old_consumer_intent.link_consumer
          links_resolver.resolve(instance_group)
          updated_link = links_manager.find_link(
            name: 'p1',
            provider_intent: @link_provider_intent,
            consumer_intent: @link_consumer_intent
          )
          expect(updated_link).to_not be_nil
          expect(updated_link[:link_consumer_intent_id]).to eq(old_consumer_intent[:id])

          new_consumer_intent = Bosh::Director::Models::Links::LinkConsumerIntent.find(id: updated_link[:link_consumer_intent_id])
          expect(new_consumer_intent.link_consumer[:id]).to eq(old_consumer[:id])
        end

        # Feature to be implemented in story #151894692
        xcontext 'if the the alias is nil' do
          let (:links) {{'backup_db' => {"from" => 'db'}}}

          let(:template_consumes_links) {[{'name' => 'backup_db', 'type' => 'db'}]}
          let(:template_provides_links) do
            [
              {name: "db", type: "db", properties: ['mysql']},
              {name: "unconsumable", type: "key", properties: ["oranges", "pineapples"]}
            ]
          end

          let(:manifest_job_provides) do
            {'db' => {'as' => 'db'}, 'unconsumable' => nil}
          end

          it 'is not consumable' do
            links_resolver.resolve(instance_group)
            expect(deployment_plan.link_providers.size).to eq(2)
            expect(deployment_plan.link_providers[0].consumable).to be_truthy
            expect(deployment_plan.link_providers[1].consumable).to be_falsey
          end
        end
      end
    end

    context 'when job consumes link from another deployment' do
        context 'and the provider is using old content format' do
          let(:jobs) do
            [consumer_job]
          end

          before do
            allow(instance_group).to receive(:add_resolved_link)
            provider = Bosh::Director::Models::Links::LinkProvider.create(
              deployment: deployment_model,
              instance_group: 'ig_1',
              name: 'job_1',
              type: 'job'
            )

            Bosh::Director::Models::Links::LinkProviderIntent.create(
              link_provider: provider,
              original_name: 'original_provider_name',
              type: 'pt1',
              name: 'foo',
              shared: true,
              consumable: true,
              content: {
                'instances' =>
                  [
                    {
                      'address' => 'net-2-addr',
                      'addresses' => {
                        'net-1' => 'net-1-addr',
                        'net-2' => 'net-2-addr',
                        'net-3' => 'net-3-addr',
                      }
                    }
                  ]
              }.to_json
            )
          end

          context 'when global_use_dns_entry is TRUE' do
            before do
              allow(deployment_plan).to receive(:use_dns_addresses?).and_return(true)
            end

            context 'when link_use_ip_address is nil' do
              it 'returns whatever is in the spec.address' do
                links_resolver.resolve(instance_group)

                link = Bosh::Director::Models::Links::Link.first
                expect(link[:id]).to eq(1)
                expect(link[:link_provider_intent_id]).to eq(1)
                expect(link[:link_consumer_intent_id]).to eq(1)
                expect(link[:name]).to eq("c1")
                expect(link[:link_content]).to eq({'instances' => [{'address' => 'net-2-addr'}]}.to_json)
                expect(link[:created_at]).to be_a(Time)
              end
            end

            context 'when link_use_ip_address is TRUE' do
              let(:consumed_link_info) do
                {'ip_addresses' => true}
              end

              it 'raises an error' do
                expect {links_resolver.resolve(instance_group)}.to raise_error 'Unable to retrieve default network from provider. Please redeploy provider deployment'
              end
            end

            context 'when link_use_ip_address is FALSE' do
              let(:consumed_link_info) do
                {'ip_addresses' => false}
              end


              it 'raises an error' do
                expect {links_resolver.resolve(instance_group)}.to raise_error 'Unable to retrieve default network from provider. Please redeploy provider deployment'
              end
            end
          end

          context 'when global_use_dns_entry is FALSE' do
            before do
              allow(deployment_plan).to receive(:use_dns_addresses?).and_return(false)
            end

            context 'when link_use_ip_address is nil' do

              it 'returns whatever is in the spec.address' do
                links_resolver.resolve(instance_group)

                link = Bosh::Director::Models::Links::Link.first
                expect(link[:id]).to eq(1)
                expect(link[:link_provider_intent_id]).to eq(1)
                expect(link[:link_consumer_intent_id]).to eq(1)
                expect(link[:name]).to eq("c1")
                expect(link[:link_content]).to eq({'instances' => [{'address' => 'net-2-addr'}]}.to_json)
                expect(link[:created_at]).to be_a(Time)
              end
            end

            context 'when link_use_ip_address is TRUE' do
              let(:consumed_link_info) do
                {'ip_addresses' => true}
              end

              it 'raises an error' do
                expect {links_resolver.resolve(instance_group)}.to raise_error 'Unable to retrieve default network from provider. Please redeploy provider deployment'
              end
            end

            context 'when link_use_ip_address is FALSE' do
              let(:consumed_link_info) do
                {'ip_addresses' => false}
              end

              it 'raises an error' do
                expect {links_resolver.resolve(instance_group)}.to raise_error 'Unable to retrieve default network from provider. Please redeploy provider deployment'
              end
            end
          end

          context 'when preferred network is specified' do
            let(:consumed_link_info) do
              {'network' => 'net-3'}
            end

            before do
              allow(deployment_plan).to receive(:use_dns_addresses?).and_return(true)
            end

            it 'picks the address from the preferred network' do
              links_resolver.resolve(instance_group)

              link = Bosh::Director::Models::Links::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_intent_id]).to eq(1)
              expect(link[:link_consumer_intent_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(link[:link_content]).to eq({'instances' => [{'address' => 'net-3-addr'}]}.to_json)
              expect(link[:created_at]).to be_a(Time)
            end

            context 'with a bad network name' do
              let(:consumed_link_info) do
                {'network' => 'whatever-net'}
              end

              it 'raises an error' do
                expect {links_resolver.resolve(instance_group)}.to raise_error "Provider link does not have network: 'whatever-net'"
              end
            end
          end
        end

      context 'and the provider is using new content format' do
        let(:jobs) do
          [consumer_job]
        end

        let(:addresses) do
          {
            'net-1' => 'net-1-addr',
            'net-2' => 'net-2-addr',
            'net-3' => 'net-3-addr',
          }
        end

        let(:dns_addresses) do
          {
            'net-1' => 'dns-net-1-addr',
            'net-2' => 'dns-net-2-addr',
            'net-3' => 'dns-net-3-addr',
          }
        end

        before do
          allow(instance_group).to receive(:add_resolved_link)

          provider = Bosh::Director::Models::Links::LinkProvider.create(
            deployment: deployment_model,
            instance_group: 'ig_1',
            name: 'job_1',
            type: 'Job',
            )

          Bosh::Director::Models::Links::LinkProviderIntent.create(
            link_provider: provider,
            original_name: 'original_provider_name',
            type: 'pt1',
            name: 'foo',
            shared: true,
            consumable: true,
            content: {
              'default_network' => 'net-2',
              'instances' => [
                {
                  'name' => 'name-1',
                  'id' => 'id-1',
                  'address' => 'net-2-addr',
                  'addresses' => addresses,
                  'dns_addresses' => dns_addresses
                }
              ]}.to_json
          )
        end

        context 'when global_use_dns_entry is TRUE' do
          before do
            allow(deployment_plan).to receive(:use_dns_addresses?).and_return(true)
          end

          context 'when link_use_ip_address is nil' do
            it 'returns whatever is in the dns_addresses for default network' do
              links_resolver.resolve(instance_group)
              expected_link_content = {
                'default_network' => 'net-2',
                'instances' => [
                  {
                    'name' => 'name-1',
                    'id' => 'id-1',
                    'address' => 'dns-net-2-addr'
                  }
                ]
              }

              link = Bosh::Director::Models::Links::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_intent_id]).to eq(1)
              expect(link[:link_consumer_intent_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(JSON.parse(link[:link_content])).to match(expected_link_content)
              expect(link[:created_at]).to be_a(Time)
            end

            context 'when address returned is an IP' do
              let(:logger) {double(:logger).as_null_object}
              let(:event_log) {double(:event_logger)}
              let(:addresses) do
                {
                  'net-1' => '1.1.1.1',
                  'net-2' => '2.2.2.2',
                  'net-3' => '3.3.3.3',
                }
              end
              let(:dns_addresses) do
                {
                  'net-1' => '1.1.1.1',
                  'net-2' => '2.2.2.2',
                  'net-3' => '3.3.3.3',
                }
              end

              before do
                allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
              end

              it 'logs warning' do
                log_message = 'DNS address not available for the link provider instance: name-1/id-1'
                expect(logger).to receive(:warn).with(log_message)
                expect(event_log).to receive(:warn).with(log_message)

                links_resolver.resolve(instance_group)
              end
            end
          end

          context 'when link_use_ip_address is TRUE' do
            let(:consumed_link_info) do
              {'ip_addresses' => true}
            end

            it 'returns whatever is in the addresses' do
              links_resolver.resolve(instance_group)

              expected_link_content = {
                'default_network' => 'net-2',
                'instances' => [
                  {
                    'name' => 'name-1',
                    'id' => 'id-1',
                    'address' => 'net-2-addr'
                  }
                ]
              }

              link = Bosh::Director::Models::Links::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_intent_id]).to eq(1)
              expect(link[:link_consumer_intent_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(JSON.parse(link[:link_content])).to match(expected_link_content)
              expect(link[:created_at]).to be_a(Time)
            end

            context 'when address returned is NOT an IP' do
              let(:logger) {double(:logger).as_null_object}
              let(:event_log) {double(:event_logger)}

              before do
                allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
              end

              it 'logs warning' do
                log_message = 'IP address not available for the link provider instance: name-1/id-1'
                expect(logger).to receive(:warn).with(log_message)
                expect(event_log).to receive(:warn).with(log_message)

                links_resolver.resolve(instance_group)
              end
            end
          end

          context 'when link_use_ip_address is FALSE' do
            let(:consumed_link_info) do
              {'ip_addresses' => false}
            end

            it 'returns whatever is in the dns_addresses' do
              links_resolver.resolve(instance_group)

              expected_link_content = {
                'default_network' => 'net-2',
                'instances' => [
                  {
                    'name' => 'name-1',
                    'id' => 'id-1',
                    'address' => 'dns-net-2-addr'
                  }
                ]
              }

              link = Bosh::Director::Models::Links::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_intent_id]).to eq(1)
              expect(link[:link_consumer_intent_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(JSON.parse(link[:link_content])).to match(expected_link_content)
              expect(link[:created_at]).to be_a(Time)
            end
          end
        end

        context 'when global_use_dns_entry is FALSE' do
          before do
            allow(deployment_plan).to receive(:use_dns_addresses?).and_return(false)
          end

          context 'when link_use_ip_address is nil' do
            it 'returns whatever is in the addresses for default network' do
              links_resolver.resolve(instance_group)
              expected_link_content = {
                'default_network' => 'net-2',
                'instances' => [
                  {
                    'name' => 'name-1',
                    'id' => 'id-1',
                    'address' => 'net-2-addr'
                  }
                ]
              }

              link = Bosh::Director::Models::Links::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_intent_id]).to eq(1)
              expect(link[:link_consumer_intent_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(JSON.parse(link[:link_content])).to match(expected_link_content)
              expect(link[:created_at]).to be_a(Time)
            end
          end

          context 'when link_use_ip_address is TRUE' do
            let(:consumed_link_info) do
              {'ip_addresses' => true}
            end

            it 'returns whatever is in the addresses' do
              links_resolver.resolve(instance_group)
              expected_link_content = {
                'default_network' => 'net-2',
                'instances' => [
                  {
                    'name' => 'name-1',
                    'id' => 'id-1',
                    'address' => 'net-2-addr'
                  }
                ]
              }

              link = Bosh::Director::Models::Links::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_intent_id]).to eq(1)
              expect(link[:link_consumer_intent_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(JSON.parse(link[:link_content])).to match(expected_link_content)
              expect(link[:created_at]).to be_a(Time)
            end
          end

          context 'when link_use_ip_address is FALSE' do
            let(:consumed_link_info) do
              {'ip_addresses' => false}
            end

            it 'returns whatever is in the dns_addresses' do
              links_resolver.resolve(instance_group)
              expected_link_content = {
                'default_network' => 'net-2',
                'instances' => [
                  {
                    'name' => 'name-1',
                    'id' => 'id-1',
                    'address' => 'dns-net-2-addr'
                  }
                ]
              }

              link = Bosh::Director::Models::Links::Link.first
              expect(link[:id]).to eq(1)
              expect(link[:link_provider_intent_id]).to eq(1)
              expect(link[:link_consumer_intent_id]).to eq(1)
              expect(link[:name]).to eq("c1")
              expect(JSON.parse(link[:link_content])).to match(expected_link_content)
              expect(link[:created_at]).to be_a(Time)
            end
          end
        end

        context 'when preferred network is specified' do
          before do
            allow(deployment_plan).to receive(:use_dns_addresses?).and_return(true)
          end

          let(:consumed_link_info) do
            {'network' => 'net-3'}
          end

          it 'picks the address from the preferred network' do
            links_resolver.resolve(instance_group)
            expected_link_content = {
              'default_network' => 'net-3',
              'instances' => [
                {
                  'name' => 'name-1',
                  'id' => 'id-1',
                  'address' => 'dns-net-3-addr'
                }
              ]
            }

            link = Bosh::Director::Models::Links::Link.first
            expect(link[:id]).to eq(1)
            expect(link[:link_provider_intent_id]).to eq(1)
            expect(link[:link_consumer_intent_id]).to eq(1)
            expect(link[:name]).to eq("c1")
            expect(JSON.parse(link[:link_content])).to match(expected_link_content)
            expect(link[:created_at]).to be_a(Time)
          end

          context 'with a bad network name' do
            let(:consumed_link_info) do
              {'network' => 'whatever-net'}
            end

            it 'raises an error' do
              expect {links_resolver.resolve(instance_group)}.to raise_error "Provider link does not have network: 'whatever-net'"
            end
          end
        end
      end
    end
  end
end