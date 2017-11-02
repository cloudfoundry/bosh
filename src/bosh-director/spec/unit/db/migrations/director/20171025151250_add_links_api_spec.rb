require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'During migrations' do
    let(:db) {DBSpecHelper.db}
    let(:migration_file) {'20171025151250_add_links_api.rb'}

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it 'creates the appropriate tables' do
      DBSpecHelper.migrate(migration_file)
      expect(db.table_exists? :link_providers).to be_truthy
      expect(db.table_exists? :link_consumers).to be_truthy
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

        it 'will create a provider for every link' do
          expect(db[:link_providers].count).to eq(4)

          expected_outputs = [
            {instance_group: 'provider_instance_group_1', link_name: 'link_name_1', deployment_id: 42, owner_type: 'job', owner_name: 'provider_job_1', link_def_type: 'link_type_1', content: '{"my_val":"hello"}'},
            {instance_group: 'provider_instance_group_1', link_name: 'link_name_2', deployment_id: 42, owner_type: 'job', owner_name: 'provider_job_1', link_def_type: 'link_type_2', content: '{"foo":"bar"}'},
            {instance_group: 'provider_instance_group_2', link_name: 'link_name_3', deployment_id: 42, owner_type: 'job', owner_name: 'provider_job_1', link_def_type: 'link_type_1', content: '{"bar":"baz"}'},
            {instance_group: 'provider_instance_group_2', link_name: 'link_name_4', deployment_id: 42, owner_type: 'job', owner_name: 'provider_job_2', link_def_type: 'link_type_2', content: '{"foobar":"bazbaz"}'},
          ]

          idx = 0
          db[:link_providers].order(:id).each do |provider|
            output = expected_outputs[idx]
            expect(provider[:name]).to eq(output[:link_name])
            expect(provider[:deployment_id]).to eq(output[:deployment_id])
            expect(provider[:instance_group]).to eq(output[:instance_group])
            expect(provider[:owner_object_type]).to eq(output[:owner_type])
            expect(provider[:owner_object_name]).to eq(output[:owner_name])
            expect(provider[:link_provider_definition_type]).to eq(output[:link_def_type])
            expect(provider[:content]).to eq(output[:content])
            idx += 1
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
        let(:expected_owner_object_info) {{instance_group_name: "provider_instance_group_1"}}

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
          expect(db[:link_consumers].first[:owner_object_name]).to eq('http_proxy_with_requires')
          expect(db[:link_consumers].first[:owner_object_type]).to eq('Job')
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
            expect(db[:link_consumers].first[:owner_object_name]).to eq('http_proxy_with_requires')
            expect(db[:link_consumers].first[:owner_object_type]).to eq('Job')
          end
        end
      end
    end
  end
end
