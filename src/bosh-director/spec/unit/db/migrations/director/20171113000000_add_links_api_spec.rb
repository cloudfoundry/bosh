require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'During migrations' do
    let(:db) {DBSpecHelper.db}
    let(:migration_file) {'20171113000000_add_links_api.rb'}

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    context 'verify table columns' do
      it 'creates the appropriate tables' do
        DBSpecHelper.migrate(migration_file)
        expect(db.table_exists? :link_providers).to be_truthy
        expect(db.table_exists? :link_provider_intents).to be_truthy
        expect(db.table_exists? :link_consumers).to be_truthy
        expect(db.table_exists? :link_consumer_intents).to be_truthy
        expect(db.table_exists? :links).to be_truthy
        expect(db.table_exists? :instances_links).to be_truthy
      end

      it 'adds the link_serial_id to deployment' do
        db[:deployments] << {name: 'fake-deployment', id: 42}
        DBSpecHelper.migrate(migration_file)

        expect(db[:deployments].first[:links_serial_id]).to eq(0)
      end

      it 'adds the has_stale_errand_links column to deployment and migrates it to TRUE' do
        db[:deployments] << {name: 'fake-deployment', id: 43}
        DBSpecHelper.migrate(migration_file)

        expect(db[:deployments].first[:has_stale_errand_links]).to be_truthy
      end

      it 'adds the has_stale_errand_links column to deployment and defaults to FALSE' do
        DBSpecHelper.migrate(migration_file)
        db[:deployments] << {name: 'fake-deployment', id: 43}

        expect(db[:deployments].first[:has_stale_errand_links]).to be_falsey
      end
    end

    context 'providers migration' do
      context 'when link_spec_json is populated in the deployments table' do
        let(:link_spec_json) do
          {
            'provider_instance_group_1': {
              'provider_job_1': {
                'link_name_1': {
                  'link_type_1': {'my_val': 'hello'}
                },
                'link_name_2': {
                  'link_type_2': {'foo': 'bar'}
                }
              }
            },
            'provider_instance_group_2': {
              'provider_job_1': {
                'link_name_3': {
                  'link_type_1': {'bar': 'baz'}
                },
              },
              'provider_job_2': {
                'link_name_4': {
                  'link_type_2': {'foobar': 'bazbaz'}
                }
              }
            }
          }
        end

        before do
          db[:deployments] << {name: 'fake-deployment', id: 42, link_spec_json: link_spec_json.to_json}
          DBSpecHelper.migrate(migration_file)
        end

        it 'will create correct links providers' do
          expect(db[:link_providers].count).to eq(3)

          expected_links_providers = [
            {instance_group: 'provider_instance_group_1', deployment_id: 42, type: 'job', name: 'provider_job_1', serial_id: 0},
            {instance_group: 'provider_instance_group_2', deployment_id: 42, type: 'job', name: 'provider_job_1', serial_id: 0},
            {instance_group: 'provider_instance_group_2', deployment_id: 42, type: 'job', name: 'provider_job_2', serial_id: 0},
          ]

          db[:link_providers].order(:id).each_with_index do |provider, index|
            output = expected_links_providers[index]
            expect(provider[:name]).to eq(output[:name])
            expect(provider[:deployment_id]).to eq(output[:deployment_id])
            expect(provider[:instance_group]).to eq(output[:instance_group])
            expect(provider[:type]).to eq(output[:type])
            expect(provider[:serial_id]).to eq(output[:serial_id])
          end
        end

        it 'will create correct links providers intents' do
          provider_1_id = db[:link_providers].where(instance_group: 'provider_instance_group_1', deployment_id: 42, type: 'job', name: 'provider_job_1', serial_id: 0).first[:id]
          provider_2_id = db[:link_providers].where(instance_group: 'provider_instance_group_2', deployment_id: 42, type: 'job', name: 'provider_job_1', serial_id: 0).first[:id]
          provider_3_id = db[:link_providers].where(instance_group: 'provider_instance_group_2', deployment_id: 42, type: 'job', name: 'provider_job_2', serial_id: 0).first[:id]

          expected_link_providers_intents = [
            {link_provider_id: provider_1_id, original_name: 'link_name_1', type: 'link_type_1', name: 'link_name_1', content: '{"my_val":"hello"}', serial_id: 0},
            {link_provider_id: provider_1_id, original_name: 'link_name_2', type: 'link_type_2', name: 'link_name_2', content: '{"foo":"bar"}', serial_id: 0},
            {link_provider_id: provider_2_id, original_name: 'link_name_3', type: 'link_type_1', name: 'link_name_3', content: '{"bar":"baz"}', serial_id: 0},
            {link_provider_id: provider_3_id, original_name: 'link_name_4', type: 'link_type_2', name: 'link_name_4', content: '{"foobar":"bazbaz"}', serial_id: 0},
          ]

          expect(db[:link_provider_intents].count).to eq(4)
          db[:link_provider_intents].order(:id).each_with_index do |provider_intent, index|
            output = expected_link_providers_intents[index]
            expect(provider_intent[:link_provider_id]).to eq(output[:link_provider_id])
            expect(provider_intent[:original_name]).to eq(output[:original_name])
            expect(provider_intent[:type]).to eq(output[:type])
            expect(provider_intent[:name]).to eq(output[:name])
            expect(provider_intent[:shared]).to eq(true)
            expect(provider_intent[:consumable]).to eq(true)
            expect(provider_intent[:serial_id]).to eq(output[:serial_id])
          end
        end
      end
    end

    context 'consumer migration' do
      context 'when spec_json is populated with consumed links in the instances table' do
        let(:instance_spec_json) do
          {
            "deployment": "fake-deployment",
            "name": "provider_instance_group_1",
            "job": {
              "name": "provider_instance_group_1",
              "templates": [
                {
                  "name": "http_proxy_with_requires",
                  "version": "760680c4a796a2ffca24026c561c06dd5bdef6b3",
                  "sha1": "fdf0d8acd01055f32fb28caee3b5a2d383848e53",
                  "blobstore_id": "e6a084ab-541c-4f9e-8132-573627bded5a",
                  "logs": []
                }
              ]
            },
            "links": {
              "http_proxy_with_requires": {
                "proxied_http_endpoint": {
                  "instance_group": "provider_deployment_node",
                  "instances": [
                    {
                      "name": "provider_deployment_node",
                      "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                      "index": 0,
                      "bootstrap": true,
                      "az": "z1",
                      "address": "192.168.1.10"
                    }
                  ],
                  "properties": {
                    "listen_port": 15672,
                    "name_space": {
                      "fibonacci": "((fibonacci_placeholder))",
                      "prop_a": "default"
                    }
                  }
                },
                "proxied_http_endpoint2": {
                  "instance_group": "provider_deployment_node",
                  "instances": [
                    {
                      "name": "provider_deployment_node",
                      "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                      "index": 0,
                      "bootstrap": true,
                      "az": "z1",
                      "address": "192.168.1.10"
                    }
                  ],
                  "properties": {
                    "a": 1,
                    "name_space": {
                      "asdf": "((fibonacci_placeholder))",
                      "dbxcv": "default"
                    }
                  }
                }
              }
            }
          }
        end
        let(:expected_owner_object_info) do
          { instance_group_name: 'provider_instance_group_1' }
        end

        before do
          db[:deployments] << {name: 'fake-deployment', id: 42, link_spec_json: "{}"}
          db[:variable_sets] << {id: 1, deployment_id: 42, created_at: Time.now}
          db[:instances] << {
            job: 'provider_instance_group_1',
            id: 22,
            index: 0,
            deployment_id: 42,
            state: "started",
            variable_set_id: 1,
            spec_json: instance_spec_json.to_json
          }
        end

        it 'will create one consumer per consuming job' do
          DBSpecHelper.migrate(migration_file)
          expect(db[:link_consumers].count).to eq(1)

          expect(db[:link_consumers].first[:deployment_id]).to eq(42)
          expect(db[:link_consumers].first[:instance_group]).to eq('provider_instance_group_1')
          expect(db[:link_consumers].first[:name]).to eq('http_proxy_with_requires')
          expect(db[:link_consumers].first[:type]).to eq('job')
          expect(db[:link_consumers].first[:serial_id]).to eq(0)
        end

        it 'will create the correct link_consumers_intents' do
          DBSpecHelper.migrate(migration_file)
          consumer_id = db[:link_consumers].first[:id]

          expected_links_consumers_intents = [
            {:id=>Integer, :link_consumer_id=>consumer_id, :original_name=>'proxied_http_endpoint', :type=>'undefined-migration', :name => 'proxied_http_endpoint', :optional=>false, :blocked=>false, :metadata=> nil, serial_id: 0},
            {:id=>Integer, :link_consumer_id=>consumer_id, :original_name=>'proxied_http_endpoint2', :type=>'undefined-migration', :name => 'proxied_http_endpoint2', :optional=>false, :blocked=>false, :metadata=> nil, serial_id: 0}
          ]

          expect(db[:link_consumer_intents].all).to match_array(expected_links_consumers_intents)
        end

        context 'multiple instances consume same link' do
          before do
            db[:instances] << {
              job: 'provider_instance_group_1',
              id: 23,
              index: 0,
              deployment_id: 42,
              state: "started",
              variable_set_id: 1,
              spec_json: instance_spec_json.to_json
            }
          end

          it 'will not create duplicate consumers' do
            expect(db[:instances].count).to eq(2)
            DBSpecHelper.migrate(migration_file)
            expect(db[:link_consumers].count).to eq(1)

            expect(db[:link_consumers].first[:deployment_id]).to eq(42)
            expect(db[:link_consumers].first[:instance_group]).to eq('provider_instance_group_1')
            expect(db[:link_consumers].first[:name]).to eq('http_proxy_with_requires')
            expect(db[:link_consumers].first[:type]).to eq('job')
            expect(db[:link_consumers].first[:serial_id]).to eq(0)
          end

          it 'will create the correct link_consumers_intents' do
            DBSpecHelper.migrate(migration_file)
            consumer_id = db[:link_consumers].first[:id]

            expected_links_consumers_intents = [
              {:id=>Integer, :link_consumer_id=>consumer_id, :original_name=>'proxied_http_endpoint', :type=>'undefined-migration', :name => 'proxied_http_endpoint', :optional=>false, :blocked=>false, :metadata=>nil, serial_id: 0},
              {:id=>Integer, :link_consumer_id=>consumer_id, :original_name=>'proxied_http_endpoint2', :type=>'undefined-migration', :name => 'proxied_http_endpoint2', :optional=>false, :blocked=>false, :metadata=>nil, serial_id: 0}
            ]

            expect(db[:link_consumer_intents].all).to match_array(expected_links_consumers_intents)
          end
        end
      end
    end

    context 'link migration' do
      context 'when spec_json is populated with consumed links in the instances table' do
        let(:instance_spec_json) do
          {
            "deployment": "fake-deployment",
            "name": "provider_instance_group_1",
            "job": {
              "name": "provider_instance_group_1",
              "templates": [
                {
                  "name": "http_proxy_with_requires",
                  "version": "760680c4a796a2ffca24026c561c06dd5bdef6b3",
                  "sha1": "fdf0d8acd01055f32fb28caee3b5a2d383848e53",
                  "blobstore_id": "e6a084ab-541c-4f9e-8132-573627bded5a",
                  "logs": []
                }
              ]
            },
            "links": {
              "http_proxy_with_requires": {
                "proxied_http_endpoint": {
                  "instance_group": "provider_deployment_node",
                  "instances": [
                    {
                      "name": "provider_deployment_node",
                      "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                      "index": 0,
                      "bootstrap": true,
                      "az": "z1",
                      "address": "192.168.1.10"
                    }
                  ],
                  "properties": {
                    "listen_port": 15672,
                    "name_space": {
                      "fibonacci": "((fibonacci_placeholder))",
                      "prop_a": "default"
                    }
                  }
                },
                "proxied_http_endpoint2": {
                  "instance_group": "provider_deployment_node",
                  "instances": [
                    {
                      "name": "provider_deployment_node",
                      "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                      "index": 0,
                      "bootstrap": true,
                      "az": "z1",
                      "address": "192.168.1.10"
                    }
                  ],
                  "properties": {
                    "a": 1,
                    "name_space": {
                      "asdf": "((fibonacci_placeholder))",
                      "dbxcv": "default"
                    }
                  }
                }
              }
            }
          }
        end

        before do
          db[:deployments] << {name: 'fake-deployment', id: 42, link_spec_json: "{}"}
          db[:variable_sets] << {id: 1, deployment_id: 42, created_at: Time.now}
          db[:instances] << {
            job: 'provider_instance_group_1',
            id: 22,
            index: 0,
            deployment_id: 42,
            state: "started",
            variable_set_id: 1,
            spec_json: instance_spec_json.to_json
          }
        end

        it 'will create one link per consuming instance group/job/link name' do
          before = Time.now
          DBSpecHelper.migrate(migration_file)
          after = Time.now

          link_consumer_intent_1 = db[:link_consumer_intents].where(original_name: 'proxied_http_endpoint').first
          link_consumer_intent_2 = db[:link_consumer_intents].where(original_name: 'proxied_http_endpoint2').first

          expect(db[:links].count).to eq(2)

          link_1_expected_content = {
            "instance_group": "provider_deployment_node",
            "instances": [
              {
                "name": "provider_deployment_node",
                "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                "index": 0,
                "bootstrap": true,
                "az": "z1",
                "address": "192.168.1.10"
              }
            ],
            "properties": {
              "listen_port": 15672,
              "name_space": {
                "fibonacci": "((fibonacci_placeholder))",
                "prop_a": "default"
              }
            }
          }.to_json

          links_1 = db[:links].where(name: 'proxied_http_endpoint').first
          expect(links_1[:link_provider_intent_id]).to be_nil
          expect(links_1[:link_consumer_intent_id]).to eq(link_consumer_intent_1[:id])
          expect(links_1[:link_content]).to eq(link_1_expected_content)
          expect(links_1[:created_at].to_i).to be >= before.to_i
          expect(links_1[:created_at].to_i).to be <= after.to_i

          link_2_expected_content = {
            "instance_group": "provider_deployment_node",
            "instances": [
              {
                "name": "provider_deployment_node",
                "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                "index": 0,
                "bootstrap": true,
                "az": "z1",
                "address": "192.168.1.10"
              }
            ],
            "properties": {
              "a": 1,
              "name_space": {
                "asdf": "((fibonacci_placeholder))",
                "dbxcv": "default"
              }
            }
          }.to_json

          links_2 = db[:links].where(name: 'proxied_http_endpoint2').first
          expect(links_2[:link_provider_intent_id]).to be_nil
          expect(links_2[:link_consumer_intent_id]).to eq(link_consumer_intent_2[:id])
          expect(links_2[:link_content]).to eq(link_2_expected_content)
          expect(links_2[:created_at].to_i).to be >= before.to_i
          expect(links_2[:created_at].to_i).to be <= after.to_i
        end

        it 'will create one instance_link per job per consuming instance' do
          DBSpecHelper.migrate(migration_file)
          expect(db[:instances_links].count).to eq(2)

          dataset = db[:instances_links].all
          expect(dataset[0][:instance_id]).to eq(22)
          expect(dataset[0][:link_id]).to eq(1)
          expect(dataset[0][:serial_id]).to eq(0)

          expect(dataset[1][:instance_id]).to eq(22)
          expect(dataset[1][:link_id]).to eq(2)
          expect(dataset[1][:serial_id]).to eq(0)
        end

        it 'will remove the links key from spec_json' do
          DBSpecHelper.migrate(migration_file)

          db[:instances].all.each do |instance|
            spec_json = instance[:spec_json]
            spec = JSON.load(spec_json)
            expect(spec.has_key?('links')).to be_falsey
          end
        end

        context 'when link_consumer is deleted: #cascade relationship' do
          it 'should delete associated link_consumer_intents and links' do
            DBSpecHelper.migrate(migration_file)

            link_consumer_1 = db[:link_consumers].where(name: 'http_proxy_with_requires').first
            link_consumer_intent_1 = db[:link_consumer_intents].where(original_name: 'proxied_http_endpoint').first
            link_1 = db[:links].where(name: 'proxied_http_endpoint').first

            expect{db[:link_consumers].where(id: link_consumer_1[:id]).delete}.to_not raise_error

            expect(db[:link_consumer_intents].where(id: link_consumer_intent_1[:id]).first).to be_nil
            expect(db[:links].where(link_consumer_intent_id: link_consumer_intent_1[:id]).count).to eq(0)
          end
        end

        context 'when deployment is deleted' do
          before do
            DBSpecHelper.migrate(migration_file)
            db[:instances].delete
          end

          it 'should delete all links, providers, consumers' do
            expect{db[:deployments].where(id: 42).delete}.to_not raise_error
            expect(db[:links].count).to eq(0)
            expect(db[:link_consumers].count).to eq(0)
            expect(db[:link_providers].count).to eq(0)
            expect(db[:link_provider_intents].count).to eq(0)
            expect(db[:link_consumer_intents].count).to eq(0)
            expect(db[:instances_links].count).to eq(0)
          end
        end
      end

      context 'when multiple instances contain the same link key' do
        let(:instance_spec_json) do
          {
            "deployment": "fake-deployment",
            "name": "provider_instance_group_1",
            "job": {
              "name": "provider_instance_group_1",
              "templates": [
                {
                  "name": "http_proxy_with_requires",
                  "version": "760680c4a796a2ffca24026c561c06dd5bdef6b3",
                  "sha1": "fdf0d8acd01055f32fb28caee3b5a2d383848e53",
                  "blobstore_id": "e6a084ab-541c-4f9e-8132-573627bded5a",
                  "logs": []
                }
              ]
            },
            "links": {
              "http_proxy_with_requires": {
                "proxied_http_endpoint": link_content
              }
            }
          }
        end

        let(:link_content) do
          {
            "instance_group": "provider_deployment_node",
            "instances": [
              {
                "name": "provider_deployment_node",
                "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                "index": 0,
                "bootstrap": true,
                "az": "z1",
                "address": "192.168.1.10"
              }
            ],
            "properties": {
              "listen_port": 15672,
              "name_space": {
                "fibonacci": "((fibonacci_placeholder))",
                "prop_a": "default"
              }
            }
          }
        end

        before do
          db[:deployments] << {name: 'fake-deployment', id: 42, link_spec_json: "{}"}
          db[:variable_sets] << {id: 1, deployment_id: 42, created_at: Time.now}
          db[:instances] << {
            job: 'provider_instance_group_1',
            id: 22,
            index: 0,
            deployment_id: 42,
            state: 'started',
            variable_set_id: 1,
            spec_json: instance_spec_json.to_json
          }
        end

        # having 2 links with same contents should be ok as well, test for it
        context 'and contents are the same' do
          before do
            db[:instances] << {
              job: 'provider_instance_group_1',
              id: 23,
              index: 1,
              deployment_id: 42,
              state: 'started',
              variable_set_id: 1,
              spec_json: instance_spec_json.to_json
            }
          end

          it 'should create only one link' do
            before = Time.now
            DBSpecHelper.migrate(migration_file)
            after = Time.now

            link_consumers_1_id = db[:link_consumers].where(name: 'http_proxy_with_requires').first[:id]
            link_consumers_intent_1_id = db[:link_consumer_intents].where(original_name: 'proxied_http_endpoint', link_consumer_id: link_consumers_1_id).first[:id]

            expect(link_consumers_intent_1_id).to_not be_nil
            expect(db[:links].count).to eq(1)

            expect(db[:links].first[:name]).to eq('proxied_http_endpoint')
            expect(db[:links].first[:link_provider_intent_id]).to be_nil
            expect(db[:links].first[:link_consumer_intent_id]).to eq(link_consumers_intent_1_id)
            expect(db[:links].first[:link_content]).to eq(link_content.to_json)
            expect(db[:links].first[:created_at].to_i).to be >= before.to_i
            expect(db[:links].first[:created_at].to_i).to be <= after.to_i
          end

          it 'will create one instance_link per consuming instance' do
            DBSpecHelper.migrate(migration_file)
            expect(db[:instances_links].count).to eq(2)

            dataset = db[:instances_links].all
            expect(dataset[0][:instance_id]).to eq(22)
            expect(dataset[0][:link_id]).to eq(1)
            expect(dataset[0][:serial_id]).to eq(0)

            expect(dataset[1][:instance_id]).to eq(23)
            expect(dataset[1][:link_id]).to eq(1)
            expect(dataset[1][:serial_id]).to eq(0)
          end
        end

        # multiple links attached to the same consumer intent???
        # how we do the equality of the links contents, need to validate it is correct ???
        # the order of the hash contents and keys should be ok

        context 'and contents are different' do
          let(:instance_spec_json2) do
            {
              "deployment": "fake-deployment",
              "name": "provider_instance_group_1",
              "job": {
                "name": "provider_instance_group_1",
                "templates": [
                  {
                    "name": "http_proxy_with_requires",
                    "version": "760680c4a796a2ffca24026c561c06dd5bdef6b3",
                    "sha1": "fdf0d8acd01055f32fb28caee3b5a2d383848e53",
                    "blobstore_id": "e6a084ab-541c-4f9e-8132-573627bded5a",
                    "logs": []
                  }
                ]
              },
              "links": {
                "http_proxy_with_requires": {
                  "proxied_http_endpoint": link_content2
                }
              }
            }
          end

          let(:link_content2) do
            {
              "instance_group": "provider_deployment_node",
              "instances": [
                {
                  "name": "provider_deployment_node",
                  "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                  "index": 0,
                  "bootstrap": true,
                  "az": "z1",
                  "address": "192.168.1.10"
                }
              ],
              "properties": {
                "listen_port": 1111,
                "name_space": {
                  "fibonacci": "1 2 3 5 8 13 21 34 55 89 144",
                  "prop_a": "ALPHABET!"
                }
              }
            }
          end

          before do
            db[:instances] << {
              job: 'provider_instance_group_1',
              id: 23,
              index: 1,
              deployment_id: 42,
              state: "started",
              variable_set_id: 1,
              spec_json: instance_spec_json2.to_json
            }
          end

          it 'should create two distinct link rows' do
            before = Time.now
            DBSpecHelper.migrate(migration_file)
            after = Time.now

            link_consumers_1_id = db[:link_consumers].where(name: 'http_proxy_with_requires').first[:id]
            link_consumers_intent_1_id = db[:link_consumer_intents].where(original_name: 'proxied_http_endpoint', link_consumer_id: link_consumers_1_id).first[:id]
            expect(link_consumers_intent_1_id).to_not be_nil

            links_dataset = db[:links]
            expect(links_dataset.count).to eq(2)

            link_rows = links_dataset.all

            expect(link_rows[0][:name]).to eq('proxied_http_endpoint')
            expect(link_rows[0][:link_provider_intent_id]).to be_nil
            expect(link_rows[0][:link_consumer_intent_id]).to eq(link_consumers_intent_1_id)
            expect(link_rows[0][:link_content]).to eq(link_content.to_json)
            expect(db[:links].first[:created_at].to_i).to be >= before.to_i
            expect(db[:links].first[:created_at].to_i).to be <= after.to_i

            expect(link_rows[1][:name]).to eq('proxied_http_endpoint')
            expect(link_rows[1][:link_provider_intent_id]).to be_nil
            expect(link_rows[1][:link_consumer_intent_id]).to eq(link_consumers_intent_1_id)
            expect(link_rows[1][:link_content]).to eq(link_content2.to_json)
            expect(db[:links].first[:created_at].to_i).to be >= before.to_i
            expect(db[:links].first[:created_at].to_i).to be <= after.to_i
          end

          it 'will create one instance_link per consuming instance' do
            DBSpecHelper.migrate(migration_file)
            expect(db[:instances_links].count).to eq(2)

            dataset = db[:instances_links].all
            expect(dataset[0][:instance_id]).to eq(22)
            expect(dataset[0][:link_id]).to eq(1)
            expect(dataset[0][:serial_id]).to eq(0)

            expect(dataset[1][:instance_id]).to eq(23)
            expect(dataset[1][:link_id]).to eq(2)
            expect(dataset[1][:serial_id]).to eq(0)
          end
        end
      end
    end

    context 'verify all unique constraints' do
      let(:link_spec_json) do
        {
          'provider_instance_group_1': {
            'provider_job_1': {
              'link_name_1': {
                'link_type_1': {'my_val': 'hello'}
              },
              'link_name_2': {
                'link_type_2': {'foo': 'bar'}
              }
            }
          },
          'provider_instance_group_2': {
            'provider_job_1': {
              'link_name_3': {
                'link_type_1': {'bar': 'baz'}
              },
            },
            'provider_job_2': {
              'link_name_4': {
                'link_type_2': {'foobar': 'bazbaz'}
              }
            }
          }
        }
      end
      let(:instance_spec_json) do
        {
          "deployment": "fake-deployment",
          "name": "provider_instance_group_1",
          "job": {
            "name": "provider_instance_group_1",
            "templates": [
              {
                "name": "http_proxy_with_requires",
                "version": "760680c4a796a2ffca24026c561c06dd5bdef6b3",
                "sha1": "fdf0d8acd01055f32fb28caee3b5a2d383848e53",
                "blobstore_id": "e6a084ab-541c-4f9e-8132-573627bded5a",
                "logs": []
              }
            ]
          },
          "links": {
            "http_proxy_with_requires": {
              "proxied_http_endpoint": {
                "instance_group": "provider_deployment_node",
                "instances": [
                  {
                    "name": "provider_deployment_node",
                    "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                    "index": 0,
                    "bootstrap": true,
                    "az": "z1",
                    "address": "192.168.1.10"
                  }
                ],
                "properties": {
                  "listen_port": 15672,
                  "name_space": {
                    "fibonacci": "((fibonacci_placeholder))",
                    "prop_a": "default"
                  }
                }
              },
              "proxied_http_endpoint2": {
                "instance_group": "provider_deployment_node",
                "instances": [
                  {
                    "name": "provider_deployment_node",
                    "id": "19dea4c6-c25f-478c-893e-db29ba7042b5",
                    "index": 0,
                    "bootstrap": true,
                    "az": "z1",
                    "address": "192.168.1.10"
                  }
                ],
                "properties": {
                  "a": 1,
                  "name_space": {
                    "asdf": "((fibonacci_placeholder))",
                    "dbxcv": "default"
                  }
                }
              }
            }
          }
        }
      end
      before do
        db[:deployments] << {name: 'fake-deployment', id: 42, link_spec_json: link_spec_json.to_json}
        db[:variable_sets] << {id: 1, deployment_id: 42, created_at: Time.now}
        db[:instances] << {
          job: 'provider_instance_group_1',
          id: 22,
          index: 0,
          deployment_id: 42,
          state: "started",
          variable_set_id: 1,
          spec_json: instance_spec_json.to_json
        }
        DBSpecHelper.migrate(migration_file)
      end

      context 'link_providers table' do
        context 'when all constraint columns are the same' do
          it 'should raise an error' do
            expect { db[:link_providers] << {instance_group: 'provider_instance_group_1', deployment_id: 42, type: 'job', name: 'provider_job_1'} }
              .to raise_error(/link_providers.deployment_id, link_providers.instance_group, link_providers.name, link_providers.type/)
          end
        end

        context 'when existing record gets updated to violate constraint' do
          it 'should raise an error' do
            expect { db[:link_providers] << {instance_group: 'provider_instance_group_2', deployment_id: 42, type: 'test', name: 'provider_job_1'} }.to_not raise_error
            link_provider = db[:link_providers].where(instance_group: 'provider_instance_group_2', deployment_id: 42, type: 'test', name: 'provider_job_1')
            expect { link_provider.update(type: 'job') }
              .to raise_error(/UNIQUE constraint failed: link_providers.deployment_id, link_providers.instance_group, link_providers.name, link_providers.type/)
          end
        end
      end

      context 'link_consumers table' do
        context 'when all constraint columns are the same' do
          it 'should raise an error' do
            link_consumer = db[:link_consumers].first
            expect { db[:link_consumers] << {deployment_id: link_consumer[:deployment_id], instance_group: link_consumer[:instance_group], name: link_consumer[:name], type: link_consumer[:type]} }
              .to raise_error(/UNIQUE constraint failed: link_consumers.deployment_id, link_consumers.instance_group, link_consumers.name, link_consumers.type/)
          end
        end

        context 'when existing record gets updated to violate constraint' do
          it 'should raise an error' do
            original_link_consumer = db[:link_consumers].first
            expect { db[:link_consumers] << {deployment_id: original_link_consumer[:deployment_id], instance_group: original_link_consumer[:instance_group], name: 'test', type: 'job'} }.to_not raise_error
            new_link_consumer = db[:link_consumers].where(deployment_id: original_link_consumer[:deployment_id], instance_group: original_link_consumer[:instance_group], name: 'test', type: 'job')
            expect { new_link_consumer.update(name: original_link_consumer[:name]) }
              .to raise_error(/UNIQUE constraint failed: link_consumers.deployment_id, link_consumers.instance_group, link_consumers.name, link_consumers.type/)
          end
        end
      end

      context 'link_provider_intents table' do
        context 'when all constraint columns are the same' do
          it 'should raise an error' do
            link_provider_intent = db[:link_provider_intents].first
            expect { db[:link_provider_intents] << {link_provider_id: link_provider_intent[:link_provider_id], original_name: link_provider_intent[:original_name], type: 'job'} }
              .to raise_error(/UNIQUE constraint failed: link_provider_intents.link_provider_id, link_provider_intents.original_name/)
          end
        end

        context 'when existing record gets updated to violate constraint' do
          it 'should raise an error' do
            original_link_provider_intents = db[:link_provider_intents].first
            expect { db[:link_provider_intents] << {link_provider_id: original_link_provider_intents[:link_provider_id], original_name: 'test-original-name', type: 'test'} }.to_not raise_error
            new_link_provider_intents = db[:link_provider_intents].where(link_provider_id: original_link_provider_intents[:link_provider_id], original_name: 'test-original-name', type: 'test')
            expect { new_link_provider_intents.update(original_name: original_link_provider_intents[:name]) }
              .to raise_error(/UNIQUE constraint failed: link_provider_intents.link_provider_id, link_provider_intents.original_name/)
          end
        end
      end

      context 'link_consumer_intents table' do
        context 'when all constraint columns are the same' do
          it 'should raise an error' do
            link_consumer_intent = db[:link_consumer_intents].first
            expect { db[:link_consumer_intents] << {link_consumer_id: link_consumer_intent[:link_consumer_id], original_name: link_consumer_intent[:original_name], type: 'job'} }
              .to raise_error(/UNIQUE constraint failed: link_consumer_intents.link_consumer_id, link_consumer_intents.original_name/)
          end
        end

        context 'when existing record gets updated to violate constraint' do
          it 'should raise an error' do
            original_link_consumer_intents = db[:link_consumer_intents].first
            expect { db[:link_consumer_intents] << {link_consumer_id: original_link_consumer_intents[:link_consumer_id], original_name: 'test-original-name', type: 'job'} }.to_not raise_error
            new_link_consumer_intents = db[:link_consumer_intents].where(link_consumer_id: original_link_consumer_intents[:link_consumer_id], original_name: 'test-original-name', type: 'job')
            expect { new_link_consumer_intents.update(original_name: original_link_consumer_intents[:name]) }
              .to raise_error(/UNIQUE constraint failed: link_consumer_intents.link_consumer_id, link_consumer_intents.original_name/)
          end
        end
      end

      context 'instances_links table' do
        context 'when all constraint columns are the same' do
          it 'should raise an error' do
            instance_link = db[:instances_links].first
            expect { db[:instances_links] << {link_id: instance_link[:link_id], instance_id: instance_link[:instance_id]} }
              .to raise_error(/UNIQUE constraint failed: instances_links.link_id, instances_links.instance_id/)
          end
        end

        context 'when existing record gets updated to violate constraint' do
          it 'should raise an error' do
            existing_link = db[:links].first
            db[:links] << {link_provider_intent_id: existing_link[:link_provider_intent_id], link_consumer_intent_id: existing_link[:link_consumer_intent_id], name: 'test', link_content: 'test'}
            new_link = db[:links].where(name: 'test', link_content: 'test').first

            original_instances_link = db[:instances_links].first
            expect { db[:instances_links] << {link_id: new_link[:id], instance_id: original_instances_link[:instance_id]} }.to_not raise_error
            new_instances_link = db[:instances_links].where(link_id: new_link[:id], instance_id: original_instances_link[:instance_id])
            expect { new_instances_link.update(link_id: original_instances_link[:link_id]) }
              .to raise_error(/UNIQUE constraint failed: instances_links.link_id, instances_links.instance_id/)
          end
        end
      end
    end

    context 'verify unique constraints are named' do
      before do
        db[:deployments] << {name: 'fake-deployment', id: 42}
        DBSpecHelper.migrate(migration_file)
      end

      context 'link_providers table' do
        it 'has named unique constraint' do
          indices = db.indexes(:link_providers)
          expect(indices.has_key?(:link_providers_constraint)).to be_truthy
        end
      end

      context 'link_provider_intents table' do
        it 'has named unique constraint' do
          indices = db.indexes(:link_provider_intents)
          expect(indices.has_key?(:link_provider_intents_constraint)).to be_truthy
        end
      end

      context 'link_consumers table' do
        it 'has named unique constraint' do
          indices = db.indexes(:link_consumers)
          expect(indices.has_key?(:link_consumers_constraint)).to be_truthy
        end
      end

      context 'link_consumer_intents table' do
        it 'has named unique constraint' do
          indices = db.indexes(:link_consumer_intents)
          expect(indices.has_key?(:link_consumer_intents_constraint)).to be_truthy
        end
      end

      context 'instances_links table' do
        it 'has named unique constraint' do
          indices = db.indexes(:instances_links)
          expect(indices.has_key?(:instances_links_constraint)).to be_truthy
        end
      end
    end
  end
end
