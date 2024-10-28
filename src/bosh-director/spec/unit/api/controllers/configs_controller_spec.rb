require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/configs_controller'

module Bosh::Director
  describe Api::Controllers::ConfigsController do
    include Rack::Test::Methods

    subject(:app) { Api::Controllers::ConfigsController.new(config) }

    let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }
    let(:identity_provider) { Support::TestIdentityProvider.new(config.get_uuid_provider) }

    let(:config_name) { 'my-name' }
    let(:config_type) { 'some-type' }

    before do
      allow(config).to receive(:identity_provider).and_return(identity_provider)
    end

    describe 'GET', '/' do
      context 'with authenticated admin user' do
        before(:each) do
          authorize('admin', 'admin')
        end

        it 'returns all matching' do
          newest_config = 'new_config'

          FactoryBot.create(:models_config,
                            name: config_name,
                            type: config_type,
                            content: 'some-yaml',
                            created_at: Time.now - 3.days,
          )

          FactoryBot.create(:models_config,
                            name: config_name,
                            type: config_type,
                            content: 'some-other-yaml',
                            created_at: Time.now - 2.days,
          )

          FactoryBot.create(:models_config,
                            type: config_type,
                            content: newest_config,
                            created_at: Time.now - 1.days,
          )

          get '/?&limit=1'
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
          expect(JSON.parse(last_response.body)).to include(include('content' => 'some-other-yaml'))
          expect(JSON.parse(last_response.body)).to include(include('content' => newest_config))
        end

        context 'when name is given' do
          it 'returns the latest config with that name' do
            FactoryBot.create(:models_config,
                              name: config_name,
                              type: config_type,
                              content: 'some-yaml',
                              created_at: Time.now - 3.days,
            )

            FactoryBot.create(:models_config,
                              name: config_name,
                              type: config_type,
                              content: 'some-other-yaml',
                              created_at: Time.now - 2.days,
            )

            newest_config = 'new_config'
            FactoryBot.create(:models_config,
                              name: config_name,
                              type: config_type,
                              content: newest_config,
                              created_at: Time.now - 1.days,
            )

            get "/?type=#{config_type}&name=#{config_name}&limit=1"
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
          end
        end

        it 'returns the latest config' do
          FactoryBot.create(:models_config,
                            name: config_name,
                            type: config_type,
                            content: 'some-yaml',
                            created_at: Time.now - 3.days,
          )

          FactoryBot.create(:models_config,
                            name: config_name,
                            type: config_type,
                            content: 'some-other-yaml',
                            created_at: Time.now - 2.days,
          )

          newest_config = 'new_config'
          FactoryBot.create(:models_config,
                            name: config_name,
                            type: config_type,
                            content: newest_config,
                            created_at: Time.now - 1.days,
          )

          get "/?type=#{config_type}&limit=1"
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
        end

        context 'when no records match the filters' do
          it 'returns empty' do
            get "/?type=#{config_type}&name=notExisting&limit=1"

            expect(last_response.status).to eq(200)

            result = JSON.parse(last_response.body)
            expect(result.class).to be(Array)
            expect(result).to eq([])
          end
        end

        context 'when no type is given' do
          it 'does not filter by type' do
            FactoryBot.create(:models_config, name: config_name, type: config_type,content: 'some-other-yaml')

            newest_config = 'new_config'
            FactoryBot.create(:models_config, name: config_name, type: config_type,content: newest_config)

            get '/?limit=1'

            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
          end
        end

        context 'when no limit param is given' do
          it 'defaults to 1' do
            FactoryBot.create(:models_config, name: config_name, type: config_type)
            FactoryBot.create(:models_config, name: config_name, type: config_type, content: 'newest_config')
            get "/?type=#{config_type}&name=#{config_name}"

            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq('newest_config')
          end

          context 'when latest is set to true' do
            it 'defaults to 1' do
              FactoryBot.create(:models_config, name: config_name, type: config_type)
              FactoryBot.create(:models_config, name: config_name, type: config_type, content: 'newest_config')
              get "/?type=#{config_type}&name=#{config_name}&latest=true"

              expect(last_response.status).to eq(200)
              expect(JSON.parse(last_response.body).count).to eq(1)
              expect(JSON.parse(last_response.body).first['content']).to eq('newest_config')
            end
          end

          context 'when latest is set to false' do
            it 'returns the history of all matching configs' do
              configs = [
                FactoryBot.create(:models_config, type: config_type),
                FactoryBot.create(:models_config, type: config_type),
              ]

              get "/?type=#{config_type}&latest=false"

              expect(last_response.status).to eq(200)

              result = JSON.parse(last_response.body, symbolize_names: true)
              expect(result).to match_array(configs.map(&:to_hash))
            end
          end

          context 'when latest is not set' do
            it 'defaults to 1' do
              FactoryBot.create(:models_config, name: config_name, type: config_type)
              FactoryBot.create(:models_config, name: config_name, type: config_type, content: 'newest_config')
              get "/?type=#{config_type}&name=#{config_name}"

              expect(last_response.status).to eq(200)
              expect(JSON.parse(last_response.body).count).to eq(1)
              expect(JSON.parse(last_response.body).first['content']).to eq('newest_config')
            end
          end

          context 'when latest param is given and has wrong value' do
            it 'return 400' do
              get "/?type=#{config_type}&name=#{config_name}&latest=foo"

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(440_010)
              expect(JSON.parse(last_response.body)['description']).to eq("'latest' must be 'true' or 'false'")
            end
          end
        end

        context 'when latest and limit are given' do
          it 'takes value of limit' do
            FactoryBot.create(:models_config, name: config_name, type: config_type)
            FactoryBot.create(:models_config, name: config_name, type: config_type, content: 'newest_config')
            get "/?type=#{config_type}&name=#{config_name}&latest=false&limit=1"

            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq('newest_config')
          end
        end

        context 'when limit param is given and has wrong value' do
          it 'return 400' do
            get "/?type=#{config_type}&name=#{config_name}&limit=foo"

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440_010)
            expect(JSON.parse(last_response.body)['description']).to eq("'limit' must be a number")
          end

          it 'return 400 for zero' do
            get '/?limit=0'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440_010)
            expect(JSON.parse(last_response.body)['description']).to eq("'limit' must be larger than zero")
          end
        end

        context 'when limit is greater one' do
          let!(:config1) { FactoryBot.create(:models_config, type: config_type, name: 'bob') }
          let!(:config2) { FactoryBot.create(:models_config, type: config_type, name: 'bob') }

          let(:result) { JSON.parse(last_response.body) }

          before do
            get "/?type=#{config_type}&limit=2"
          end

          it 'returns the history of all matching configs' do
            expect(last_response.status).to eq(200)
            expect(result).to eq(
              [
                {
                  'content' => config2.content,
                  'id' => config2.id.to_s,
                  'type' => config2.type,
                  'name' => config2.name,
                  'created_at' => config2.created_at.to_s,
                  'team' => nil,
                  'current' => true,
                },
                {
                  'content' => config1.content,
                  'id' => config1.id.to_s,
                  'type' => config1.type,
                  'name' => config1.name,
                  'created_at' => config1.created_at.to_s,
                  'team' => nil,
                  'current' => false,
                },
              ],
            )
          end
        end
      end
    end

    describe 'POST', '/' do
      let(:config_data) { 'a: 1' }
      let(:request_body) do
        JSON.generate('name' => config_name, 'type' => config_type, 'content' => config_data, 'expected_latest_id' => '0')
      end

      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        it 'creates a new config and returns new config as JSON' do
          expect do
            post '/', request_body, 'CONTENT_TYPE' => 'application/json'
          end.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

          expect(last_response.status).to eq(201)

          config = Bosh::Director::Models::Config.first
          expect(JSON.parse(last_response.body)).to eq(
            'id' => config.id.to_s,
            'type' => config_type,
            'name' => config_name,
            'content' => 'a: 1',
            'created_at' => config.created_at.to_s,
            'team' => nil,
            'current' => true,
          )
        end

        context 'when config exists with different content' do
          it 'creates a new config if expected latest id is not specified' do
            FactoryBot.create(:models_config,
              name: config_name,
              type: config_type,
              content: 'a: 123',
            )
            expect do
              post(
                '/',
                JSON.generate(
                  'name' => config_name,
                  'type' => config_type,
                  'content' => 'b: 12345',
                ),
                'CONTENT_TYPE' => 'application/json',
              )
            end.to change(Models::Config, :count)
            expect(last_response.status).to eq(201)
          end

          it 'does not create a new config if expected latest id is not latest id' do
            config1 = FactoryBot.create(:models_config,
              name: config_name,
              type: config_type,
              content: 'a: 123',
            )
            config2 = FactoryBot.create(:models_config,
              name: config_name,
              type: config_type,
              content: 'a: 456',
            )
            expect do
              post(
                '/',
                JSON.generate(
                  'name' => config_name,
                  'type' => config_type,
                  'content' => 'b: 789',
                  'expected_latest_id' => config1.id,
                ),
                'CONTENT_TYPE' => 'application/json',
              )
            end.to_not change(Models::Config, :count)
            expect(last_response.status).to eq(412)
            expect(JSON.parse(last_response.body)['latest_id']).to eq(config2.id.to_s)
            expect(JSON.parse(last_response.body)['description']).to include(
              "Latest Id: '#{config2.id}' does not match expected latest id",
            )
          end

          it 'does not create a new config if using expected latest id with empty configs' do
            expect do
              post(
                '/',
                JSON.generate(
                  'name' => config_name,
                  'type' => config_type,
                  'content' => 'b: 789',
                  'expected_latest_id' => '123',
                ),
                'CONTENT_TYPE' => 'application/json',
              )
            end.to_not change(Models::Config, :count)
            expect(last_response.status).to eq(412)
            expect(JSON.parse(last_response.body)['latest_id']).to eq('0')
            expect(JSON.parse(last_response.body)['description']).to include(
              "Latest Id: '0' does not match expected latest id",
            )
          end

          it 'creates a new config if expected latest id matches latest id' do
            FactoryBot.create(:models_config,
              name: config_name,
              type: config_type,
              content: 'a: 123',
            )
            config2 = FactoryBot.create(:models_config,
              name: config_name,
              type: config_type,
              content: 'a: 456',
            )
            expect do
              post(
                '/',
                JSON.generate(
                  'name' => config_name,
                  'type' => config_type,
                  'content' => 'b: 12345',
                  'expected_latest_id' => config2.id,
                ),
                'CONTENT_TYPE' => 'application/json',
              )
            end.to change(Models::Config, :count)
            expect(last_response.status).to eq(201)
          end
        end

        it 'ignores config when config already exists' do
          FactoryBot.create(:models_config,
            name: config_name,
            type: config_type,
            content: 'a: 123',
          )

          expect do
            post '/', JSON.generate(
              'name' => config_name,
              'type' => config_type,
              'content' => 'a: 123',
            ), 'CONTENT_TYPE' => 'application/json'
          end.to_not change(Models::Config, :count)

          expect(last_response.status).to eq(201)
        end

        it 'gives a nice error when request body is invalid json' do
          post '/', "}}}i'm not really encoded, hah!", 'CONTENT_TYPE' => 'application/json'

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['code']).to eq(710_001)
          expect(JSON.parse(last_response.body)['description']).to include('Invalid JSON request body: ')
        end

        context 'when type is runtime' do
          let(:request_body) do
            JSON.generate('name' => config_name, 'type' => 'runtime', 'content' => config_data, 'expected_latest_id' => '0')
          end

          context 'when version field is an integer' do
            let(:config_data) do
              config = Bosh::Spec::Deployments.simple_runtime_config
              config['releases'].first['version'] = 2
              YAML.dump(config)
            end

            it 'converts version field to a string' do
              expect do
                post '/', request_body, 'CONTENT_TYPE' => 'application/json'
              end.to change(Models::Config, :count).from(0).to(1)

              expect(last_response.status).to eq(201)
              expect(Models::Config.first.content).to eq(YAML.dump(Bosh::Spec::Deployments.simple_runtime_config))
              expect(JSON.parse(last_response.body)['content']).to eq(YAML.dump(Bosh::Spec::Deployments.simple_runtime_config))
            end
          end

          context 'when releases block does not contain version field' do
            let(:config_data) do
              config = Bosh::Spec::Deployments.simple_runtime_config
              config['releases'].first.delete('version')
              YAML.dump(config)
            end

            it 'saves runtime config without version field' do
              expect do
                post '/', request_body, 'CONTENT_TYPE' => 'application/json'
              end.to change(Models::Config, :count).from(0).to(1)

              expect(last_response.status).to eq(201)
              expect(Models::Config.first.content).to eq(config_data)
              expect(JSON.parse(last_response.body)['content']).to eq(config_data)
            end
          end
        end

        context 'when content is not valid json' do
          it 'creates a new event and gives a nice error' do
            new_config = JSON.generate(
              'type' => 'myType',
              'name' => 'myName',
              'content' => "}}}i'm not really json, hah!",
            )

            post '/', new_config, 'CONTENT_TYPE' => 'application/json'

            event = Bosh::Director::Models::Event.first
            expect(event.object_type).to eq('config/myType')
            expect(event.object_name).to eq('myName')
            expect(event.action).to eq('create')
            expect(event.user).to eq('admin')

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440_011)
            expect(JSON.parse(last_response.body)['description']).to include('Config must be valid YAML: ')
          end
        end

        it 'creates a new event' do
          expect do
            post '/', request_body, 'CONTENT_TYPE' => 'application/json'
          end.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
          event = Bosh::Director::Models::Event.first
          expect(event.object_type).to eq("config/#{config_type}")
          expect(event.object_name).to eq(config_name)
          expect(event.action).to eq('create')
          expect(event.user).to eq('admin')
        end

        context 'when the content is no YAML hash' do
          let(:request_body) { '{"name":"n","type":"t","content":"I am a string","expected_latest_id":"0"}' }

          it 'return 400' do
            post '/', request_body, 'CONTENT_TYPE' => 'application/json'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440_011)
            expect(JSON.parse(last_response.body)['description']).to eq('YAML hash expected')
          end
        end

        context 'when `type` argument is missing' do
          let(:request_body) do
            JSON.generate('name' => config_name, 'content' => '{}', 'expected_latest_id' => '0')
          end

          it 'creates a new event and return 400' do
            post '/', request_body, 'CONTENT_TYPE' => 'application/json'

            event = Bosh::Director::Models::Event.first
            expect(event.object_type).to eq('config/')
            expect(event.object_name).to eq(config_name)
            expect(event.action).to eq('create')
            expect(event.user).to eq('admin')
            expect(event.error).to eq("'type' is required")

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440_010)
            expect(JSON.parse(last_response.body)['description']).to eq("'type' is required")
          end
        end

        context 'when `name` argument is missing' do
          let(:request_body) do
            JSON.generate('type' => config_type, 'content' => '{}', 'expected_latest_id' => '0')
          end

          it 'creates a new event and return 400' do
            post '/', request_body, 'CONTENT_TYPE' => 'application/json'

            event = Bosh::Director::Models::Event.first
            expect(event.object_type).to eq("config/#{config_type}")
            expect(event.object_name).to eq(nil)
            expect(event.action).to eq('create')
            expect(event.user).to eq('admin')

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440_010)
            expect(JSON.parse(last_response.body)['description']).to eq("'name' is required")
          end
        end
      end
    end

    describe 'DELETE', '/' do
      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        context 'when type and name are given' do
          context 'when config exists' do
            before do
              FactoryBot.create(:models_config,
                type: config_type,
                name: config_name,
              )
            end

            it 'deletes the config' do
              expect(delete("/?type=#{config_type}&name=#{config_name}").status).to eq(204)

              configs = JSON.parse(get("/?type=#{config_type}&name=#{config_name}&limit=10").body)

              expect(configs.count).to eq(0)
            end
          end

          context "when there is no config matching given 'type' and 'name'" do
            it 'responds with 404' do
              expect(delete("/?type=#{config_type}&name=#{config_name}").status).to eq(404)
            end
          end
        end

        context "when 'type' parameter is missing" do
          it 'responds with 400' do
            response = delete("/?name=#{config_name}")

            expect(response.status).to eq(400)
            expect(JSON.parse(response.body)['description']).to eq("'type' is required")
          end
        end

        context "when 'name' parameter is missing" do
          it 'responds with 400' do
            response = delete("/?type=#{config_type}")

            expect(response.status).to eq(400)
            expect(JSON.parse(response.body)['description']).to eq("'name' is required")
          end
        end
      end
    end

    describe 'DELETE', '/:id' do
      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        context 'when config exists' do
          let(:config_id) { FactoryBot.create(:models_config).id }

          it 'deletes the config specified by id' do
            expect(delete("/#{config_id}").status).to eq(204)
            expect(Models::Config[config_id].deleted).to eq(true)
          end
        end

        context 'when config does not exists' do
          it 'deletes the config specified by id' do
            expect(delete('/5').status).to eq(404)
          end
        end

        context 'when "id" parameter is not an integer' do
          it 'responds with 400' do
            expect(delete('/bla').status).to eq(404)
          end
        end
      end
    end

    describe 'diff' do
      let(:config_hash_with_one_az) do
        {
          'azs' => [
            {
              'name' => 'az1',
              'properties' => {},
            },
          ],
        }
      end

      let(:config_hash_with_two_azs) do
        {
          'azs' => [
            {
              'name' => 'az1',
              'properties' => {},
            },
            {
              'name' => 'az2',
              'properties' => {
                'some-key' => 'some-value',
              },
            },
          ],
        }
      end

      let(:new_config) do
        JSON.generate(
          'type' => 'myType',
          'name' => 'myName',
          'content' => new_content,
        )
      end

      let(:new_content) { "---\n" }

      context 'authenticated access' do
        before { authorize 'admin', 'admin' }

        context 'when none of the accepted request body formats is used' do
          let(:body) do
            JSON.dump('I am not a valid' => 'request')
          end

          let(:id_format) { JSON.dump('id' => '<id>') }
          let(:content_format) { JSON.dump('content' => '<content>') }
          let(:config_format) { JSON.dump('type' => '<type>', 'name' => '<name>', 'content' => '<content>') }

          let(:diff_err_msg) do
            %(The following request formats are allowed:\n) +
              %(1. {"from":<config>,"to":<config>} where <config> is either #{id_format} or #{content_format}\n) +
              %(2. #{config_format})
          end

          it 'returns 400 with error details' do
            post '/diff', body, 'CONTENT_TYPE' => 'application/json'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440_010)
            expect(JSON.parse(last_response.body)['description']).to eq(diff_err_msg)
          end

          context 'when any of the given `id` values is not a string containing an integer' do
            it 'returns 400 with error details' do
              post(
                '/diff',
                JSON.generate('from' => { 'id' => 'foo' }, 'to' => { 'id' => '1' }),
                'CONTENT_TYPE' => 'application/json',
              )

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(440_010)
              expect(JSON.parse(last_response.body)['description']).to eq(diff_err_msg)

              post(
                '/diff',
                JSON.generate('from' => { 'id' => '1' }, 'to' => { 'id' => 'foo' }),
                'CONTENT_TYPE' => 'application/json',
              )

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(440_010)
              expect(JSON.parse(last_response.body)['description']).to eq(diff_err_msg)
            end
          end

          context 'when any of the given `id` values is from type integer' do
            it 'returns 400 with error details' do
              post '/diff', JSON.generate('from' => { 'id' => 1 }, 'to' => { 'id' => '1' }), 'CONTENT_TYPE' => 'application/json'

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(440_010)
              expect(JSON.parse(last_response.body)['description']).to eq(diff_err_msg)
            end
          end

          context 'when the `content` value is not a string' do
            it' returns 400 with error details' do
              post '/diff', JSON.generate('from' => { 'content' => -1 }, 'to' => { 'id' => '1' }), 'CONTENT_TYPE' => 'application/json'

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(440_010)
              expect(JSON.parse(last_response.body)['description']).to eq(diff_err_msg)
            end
          end
        end

        context 'when diffing yields an error' do
          let(:new_content) { 'a: 1' }
          it 'returns 400 with an empty diff and an error message' do
            allow_any_instance_of(Bosh::Director::Changeset).to receive(:diff).and_raise('Oooooh crap')

            post '/diff', new_config, 'CONTENT_TYPE' => 'application/json'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['diff']).to eq([])
            expect(JSON.parse(last_response.body)['error']).to include('Unable to diff config content')
          end
        end

        context 'when one concrete config is given' do
          context 'when there is a previous config with given name and type' do
            before do
              Models::Config.create(
                type: 'myType',
                name: 'myName',
                raw_manifest: config_hash_with_two_azs,
              )
            end

            context 'when uploading an empty config' do
              let(:new_content) { "---\n" }

              it 'returns the diff' do
                post(
                  '/diff',
                  new_config,
                  'CONTENT_TYPE' => 'application/json',
                )

                expect(JSON.parse(last_response.body)['diff']).to eq([])
                expect(JSON.parse(last_response.body)['error']).to include('YAML hash expected')
              end
            end

            context 'when there is no diff' do
              let(:new_content) { YAML.dump(config_hash_with_two_azs) }

              it 'returns empty diff' do
                post(
                  '/diff',
                  new_config,
                  'CONTENT_TYPE' => 'application/json',
                )
                expect(last_response.body).to match('\{"from":\{"id":"\d+"\}\,"diff":\[\]}')
              end
            end

            context 'when there is a diff' do
              let(:new_content) { YAML.dump(config_hash_with_one_az) }

              it 'returns the diff' do
                post(
                  '/diff',
                  new_config,
                  'CONTENT_TYPE' => 'application/json',
                )
                expect(last_response.status).to eq(200)
                json_response = JSON.parse(last_response.body)
                expect(json_response).to match(
                  'diff' => [
                    ['azs:', nil],
                    ['- name: az2', 'removed'],
                    ['  properties:', 'removed'],
                    ['    some-key: "<redacted>"', 'removed'],
                  ],
                  'from' => { 'id' => anything }
                )
              end
            end

            context 'when invalid content YAML is given' do
              let(:new_content) { "}}}i'm not really encoded, hah!" }
              it 'gives a nice error when request body is not a valid yml' do
                post('/diff', new_config, 'CONTENT_TYPE' => 'application/json')

                expect(last_response.status).to eq(400)
                expect(JSON.parse(last_response.body)['diff']).to eq([])
                expect(JSON.parse(last_response.body)['error']).to include('Config must be valid YAML')
              end
            end

            context 'when the body is not valid YAML' do
              it 'gives a nice error when request body is invalid json' do
                post('/diff', "}}}i'm not really encoded, hah!", 'CONTENT_TYPE' => 'application/json')

                expect(last_response.status).to eq(400)
                expect(JSON.parse(last_response.body)['code']).to eq(710_001)
                expect(JSON.parse(last_response.body)['description']).to include('Invalid JSON request body: ')
              end
            end

            context 'when config content is empty' do
              let(:new_content) { '' }
              it 'gives a nice error ' do
                post '/diff', new_config, 'CONTENT_TYPE' => 'application/json'

                expect(last_response.status).to eq(400)
                expect(JSON.parse(last_response.body)['diff']).to eq([])
                expect(JSON.parse(last_response.body)['error']).to include('YAML hash expected')
              end
            end

            context 'when config content is not a hash' do
              let(:new_content) { 'I am not a hash' }
              it 'errors' do
                post '/diff', new_config, 'CONTENT_TYPE' => 'application/json'

                expect(last_response.status).to eq(400)
                expect(JSON.parse(last_response.body)['error']).to include('YAML hash expected')
              end
            end
          end

          context 'when there is no previous cloud config' do
            let(:new_content) { YAML.dump(config_hash_with_one_az) }
            it 'returns the diff' do
              post(
                '/diff',
                new_config,
                'CONTENT_TYPE' => 'application/json',
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"from":{"id":"0"},"diff":[["azs:","added"],["- name: az1","added"],["  properties: {}","added"]]}')
            end
          end

          context 'when previous config is nil' do
            before do
              @config_id = Models::Config.create(
                type: 'myType',
                name: 'myName',
                raw_manifest: nil,
              ).id
            end
            let(:new_content) { YAML.dump(config_hash_with_one_az) }

            it 'returns the diff' do
              post(
                '/diff',
                new_config,
                'CONTENT_TYPE' => 'application/json',
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq(%({"from":{"id":"#{@config_id}"},"diff":[["azs:","added"],["- name: az1","added"],["  properties: {}","added"]]}))
            end
          end
        end

        context 'when diffing two configs' do
          let(:dev_team) { Models::Team.create(name: 'dev') }
          let(:dev_team_config_manifest) do
            { 'a' => 5 }
          end
          let(:dev_team_config) do
            Models::Config.create(
              type: 'custom',
              name: 'dev-team',
              raw_manifest: dev_team_config_manifest,
              team_id: dev_team.id,
            )
          end

          let(:other_team) { Models::Team.create(name: 'other') }
          let(:other_team_config_manifest) do
            { 'b' => 5 }
          end
          let(:other_team_config) do
            Models::Config.create(
              type: 'custom',
              name: 'other-team',
              raw_manifest: other_team_config_manifest,
              team_id: other_team.id,
            )
          end

          context 'from a given `id` to a given `id`' do
            it 'returns the diff' do
              post(
                '/diff',
                JSON.dump(from: { id: dev_team_config.id.to_s }, to: { id: other_team_config.id.to_s }),
                'CONTENT_TYPE' => 'application/json',
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq(%'{"diff":[["a: 5","removed"],["",null],["b: 5","added"]]}')
            end
          end

          context 'from a given `content` to a given `content`' do
            it 'returns the diff' do
              post(
                '/diff',
                JSON.dump(from: { content: YAML.dump(dev_team_config_manifest) }, to: { content: YAML.dump(other_team_config_manifest) }),
                'CONTENT_TYPE' => 'application/json',
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["a: 5","removed"],["",null],["b: 5","added"]]}')
            end
          end

          context 'from a given `content` to a given `id`' do
            it 'returns the diff' do
              post(
                '/diff',
                JSON.dump(from: { content: YAML.dump(dev_team_config_manifest) }, to: { id: other_team_config.id.to_s }),
                'CONTENT_TYPE' => 'application/json',
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["a: 5","removed"],["",null],["b: 5","added"]]}')
            end
          end

          context 'from a given `id` to a given `content`' do
            it 'returns the diff' do
              post(
                '/diff',
                JSON.dump(from: { id: dev_team_config.id.to_s }, to: { content: YAML.dump(other_team_config_manifest) }),
                'CONTENT_TYPE' => 'application/json',
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq(%'{"diff":[["a: 5","removed"],["",null],["b: 5","added"]]}')
            end

            context 'where the `content` is an empty config' do
              it 'gives a nice error' do
                post(
                  '/diff',
                  JSON.dump(from: { id: dev_team_config.id.to_s }, to: { content: "---\n" }),
                  'CONTENT_TYPE' => 'application/json',
                )

                expect(JSON.parse(last_response.body)['diff']).to eq([])
                expect(JSON.parse(last_response.body)['error']).to include('YAML hash expected')
              end
            end

            context 'where the `content` is invalid YAML' do
              it 'gives a nice error' do
                post(
                  '/diff',
                  JSON.dump(from: { id: dev_team_config.id.to_s }, to: { content: "}I'm not valid yaml" }),
                  'CONTENT_TYPE' => 'application/json',
                )

                expect(last_response.status).to eq(400)
                expect(JSON.parse(last_response.body)['diff']).to eq([])
                expect(JSON.parse(last_response.body)['error']).to include('Config must be valid YAML')
              end
            end
          end

          context "when referencing another team's config" do
            context 'without a team-specific user' do
              before { basic_authorize 'dev-team-member', 'dev-team-member' }

              it 'should return an error when the old config is unauthorized' do
                post(
                  '/diff',
                  JSON.dump(from: { id: other_team_config.id.to_s }, to: { id: dev_team_config.id.to_s }),
                  'CONTENT_TYPE' => 'application/json',
                )
                expect(last_response.status).to eq(401)
                json_response = JSON.parse(last_response.body)
                expect(json_response['code']).to eq(600_000)
                expect(json_response['description'])
                  .to eq('Require one of the scopes: bosh.admin, bosh..admin, bosh.teams.other.admin')
              end

              it 'should return an error when the new config is unauthorized' do
                post(
                  '/diff',
                  JSON.dump(from: { id: dev_team_config.id.to_s }, to: { id: other_team_config.id.to_s }),
                  'CONTENT_TYPE' => 'application/json',
                )
                expect(last_response.status).to eq(401)
                json_response = JSON.parse(last_response.body)
                expect(json_response['code']).to eq(600_000)
                expect(json_response['description'])
                  .to eq('Require one of the scopes: bosh.admin, bosh..admin, bosh.teams.other.admin')
              end

              let(:new_config) do
                JSON.generate(
                  'type' => other_team_config.type,
                  'name' => other_team_config.name,
                  'content' => YAML.dump(other_team_config.raw_manifest),
                )
              end

              it 'should return an error when the config is unauthorized and we post data to diff' do
                post(
                  '/diff',
                  new_config,
                  'CONTENT_TYPE' => 'application/json',
                )

                expect(last_response.status).to eq(401)

                json_response = JSON.parse(last_response.body)
                expect(json_response['code']).to eq(600_000)
                expect(json_response['description'])
                  .to eq('Require one of the scopes: bosh.admin, bosh..admin, bosh.teams.other.admin')
              end
            end
          end

          context 'when config with given "id" does not exist' do
            it 'returns 404 with error details' do
              post(
                '/diff',
                JSON.dump(from: { id: '5' }, to: { id: other_team.id.to_s }),
                'CONTENT_TYPE' => 'application/json',
              )

              expect(last_response.status).to eq(404)
              expect(JSON.parse(last_response.body)['code']).to eq(440_012)
              expect(JSON.parse(last_response.body)['description']).to eq('Config 5 not found')
            end
          end
        end
      end

      context 'accessing with invalid credentials' do
        before { authorize 'invalid-user', 'invalid-password' }

        it 'returns 401' do
          post '/diff', {}.to_json, 'CONTENT_TYPE' => 'application/json'
          expect(last_response.status).to eq(401)
        end
      end
    end

    describe 'authorization' do
      let(:request_body) do
        JSON.generate('type' => config_type, 'content' => '{}')
      end

      let(:dev_team) { Models::Team.create(name: 'dev') }
      let(:other_team) { Models::Team.create(name: 'other') }
      let!(:dev_config) do
        FactoryBot.create(:models_config,
                          type: config_type,
                          content: 'some-yaml',
                          name: 'dev_config',
                          created_at: Time.now - 3.days,
                          team_id: dev_team.id,
        )
      end

      let!(:other_config) do
        FactoryBot.create(:models_config,
                          type: config_type,
                          content: 'some-other-yaml',
                          name: 'other_config',
                          created_at: Time.now - 2.days,
                          team_id: other_team.id,
        )
      end

      context 'without an authenticated user' do
        it 'denies read access' do
          expect(get('/').status).to eq(401)
        end

        it 'denies write access' do
          expect(post('/', request_body, 'CONTENT_TYPE' => 'application/json').status).to eq(401)
        end

        it 'does not permit delete the config' do
          expect(delete("/?type=#{config_type}&name=dev_config").status).to eq(401)
        end
      end

      context 'when user has a team admin membership' do
        before { basic_authorize 'dev-team-member', 'dev-team-member' }

        it 'returns team configs' do
          get "/?type=#{config_type}&latest=false"
          expect(get("/?type=#{config_type}&latest=false").status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body)).to include(include('content' => 'some-yaml'))
          expect(JSON.parse(last_response.body).first['team']).to eq('dev')
        end

        it 'stores team-specific configs' do
          expect do
            post(
              '/',
              JSON.generate('name' => config_name, 'type' => config_type, 'content' => 'a: 123'),
              'CONTENT_TYPE' => 'application/json',
            )
          end.to change { Bosh::Director::Models::Config.filter(team_id: dev_team.id).count }.from(1).to(2)
        end

        it 'deletes the config' do
          expect(delete("/?type=#{config_type}&name=dev_config").status).to eq(204)
          configs = JSON.parse(get("/?type=#{config_type}&name=dev_config&latest=false").body)
          expect(configs.count).to eq(0)
        end

        it "cannot overwrite another team's config" do
          expect(
            post(
              '/',
              JSON.generate('name' => 'other_config', 'type' => config_type, 'content' => 'a: 123'),
              'CONTENT_TYPE' => 'application/json',
            ).status,
          ).to eq(401)
        end

        it "cannot delete another team's config" do
          expect(delete("/?type=#{config_type}&name=other_config").status).to eq(401)
        end

        it "cannot delete another team's config by id" do
          expect(delete("/#{other_config.id}").status).to eq(401)
        end
      end

      context 'when user has a team read membership' do
        before { basic_authorize 'dev-team-read-member', 'dev-team-read-member' }

        it 'permits read access to the teams config' do
          get "/?type=#{config_type}&latest=false"
          expect(get("/?type=#{config_type}&latest=false").status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body)).to include(include('content' => 'some-yaml'))
        end

        it 'denies write access' do
          expect(post('/', request_body, 'CONTENT_TYPE' => 'application/json').status).to eq(401)
        end

        it 'does not permit delete the config' do
          expect(delete("/?type=#{config_type}&name=dev_config").status).to eq(401)
        end

        it 'returns team configs' do
          get "/?type=#{config_type}&latest=false"
          expect(get("/?type=#{config_type}&latest=false").status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body).first['team']).to eq('dev')
        end
      end

      context 'when user is an admin' do
        before { basic_authorize('admin', 'admin') }

        it 'permits read access to all configs' do
          expect(get("/?type=#{config_type}&latest=false").status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
        end

        it 'permits write access' do
          expect do
            post(
              '/',
              JSON.generate('name' => config_name, 'type' => config_type, 'content' => 'a: 123'),
              'CONTENT_TYPE' => 'application/json',
            )
          end.to change(Bosh::Director::Models::Config, :count).from(2).to(3)
        end

        it 'deletes the config' do
          expect(delete("/?type=#{config_type}&name=dev_config").status).to eq(204)
          configs = JSON.parse(get("/?type=#{config_type}&name=dev_config&latest=false").body)
          expect(configs.count).to eq(0)
        end

        it 'returns teams value' do
          get "/?type=#{config_type}&latest=false"
          expect(get("/?type=#{config_type}&latest=false").status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
          expect(JSON.parse(last_response.body).map { |x| x['team'] }).to contain_exactly('dev', 'other')
        end
      end

      context 'when user has read-only access to director' do
        before { basic_authorize('reader', 'reader') }

        it 'permits read access to all configs' do
          expect(get("/?type=#{config_type}&latest=false").status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
        end

        it 'denies write access' do
          expect(post('/', request_body, 'CONTENT_TYPE' => 'application/json').status).to eq(401)
        end

        it 'does not permit delete the config' do
          expect(delete("/?type=#{config_type}&name=dev_config").status).to eq(401)
        end

        it 'returns all configs' do
          get "/?type=#{config_type}&latest=false"
          expect(get("/?type=#{config_type}&latest=false").status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
          expect(JSON.parse(last_response.body).first['team']).to eq('dev')
          expect(JSON.parse(last_response.body)[1]['team']).to eq('other')
        end
      end
    end

    describe 'id' do
      let!(:config_example) { FactoryBot.create(:models_config, id: 123, type: config_type, name: 'default', content: '1') }

      context 'with authenticated admin user' do
        before(:each) do
          authorize('admin', 'admin')
        end

        it 'it returns the specified config' do
          get('/123')

          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)).to eq(
            'id' => '123',
            'type' => config_type,
            'name' => 'default',
            'content' => '1',
            'created_at' => config_example.created_at.to_s,
            'team' => nil,
            'current' => true,
          )
        end

        context 'when no config is found' do
          it 'returns a 404' do
            get('/999')

            expect(last_response.status).to eq(404)
          end
        end

        context 'when `id` is not a valid database primary key type' do
          it 'returns a 404' do
            get('/invalidType!$_0')

            expect(last_response.status).to eq(404)
          end
        end
      end

      context 'without an authenticated user' do
        it 'denies access' do
          response = get('/my-fake-id')
          expect(response.status).to eq(401)
        end
      end

      context 'when user is reader' do
        before { basic_authorize('reader', 'reader') }

        it 'permits access' do
          expect(get('/123').status).to eq(200)
        end
      end
    end
  end
end
