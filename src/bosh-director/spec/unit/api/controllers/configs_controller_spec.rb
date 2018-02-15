require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/configs_controller'

module Bosh::Director
  describe Api::Controllers::ConfigsController do
    include Rack::Test::Methods

    subject(:app) { Api::Controllers::ConfigsController.new(config) }
    let(:config) do
      config = Config.load_hash(SpecHelper.spec_get_director_config)
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end

    describe 'GET', '/' do
      context 'with authenticated admin user' do
        before(:each) do
          authorize('admin', 'admin')
        end

        it 'returns all matching' do
          newest_config = 'new_config'

          Models::Config.make(
            content: 'some-yaml',
            created_at: Time.now - 3.days,
          )

          Models::Config.make(
            content: 'some-other-yaml',
            created_at: Time.now - 2.days,
          )

          Models::Config.make(
            name: 'my-config',
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
            Models::Config.make(
              content: 'some-yaml',
              created_at: Time.now - 3.days,
            )

            Models::Config.make(
              content: 'some-other-yaml',
              created_at: Time.now - 2.days,
            )

            newest_config = 'new_config'
            Models::Config.make(
              name: 'my-config',
              content: newest_config,
              created_at: Time.now - 1.days,
            )

            get '/?type=my-type&name=my-config&limit=1'
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
          end
        end

        it 'returns the latest config' do
          Models::Config.make(
            content: 'some-yaml',
            created_at: Time.now - 3.days,
          )

          Models::Config.make(
            content: 'some-other-yaml',
            created_at: Time.now - 2.days,
          )

          newest_config = 'new_config'
          Models::Config.make(
            content: newest_config,
            created_at: Time.now - 1.days,
          )

          get '/?type=my-type&limit=1'
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
        end

        context 'when no records match the filters' do
          it 'returns empty' do
            get '/?type=my-type&name=notExisting&limit=1'

            expect(last_response.status).to eq(200)

            result = JSON.parse(last_response.body)
            expect(result.class).to be(Array)
            expect(result).to eq([])
          end
        end

        context 'when no type is given' do
          it 'does not filter by type' do
            Models::Config.make(content: 'some-other-yaml')

            newest_config = 'new_config'
            Models::Config.make(content: newest_config)

            get '/?limit=1'

            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
          end
        end

        context 'when no limit param is given' do
          it 'defaults to 1' do
            Models::Config.make
            Models::Config.make(content: 'newest_config')
            get '/?type=my-type&name=some-name'

            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq('newest_config')
          end
        end

        context 'when limit param is given and has wrong value' do
          it 'return 400' do
            get '/?type=my-type&name=some-name&limit=foo'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440010)
            expect(JSON.parse(last_response.body)['description']).to eq("'limit' must be a number")
          end

          it 'return 400 for zero' do
            get '/?limit=0'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440010)
            expect(JSON.parse(last_response.body)['description']).to eq("'limit' must be larger than zero")
          end
        end

        context 'when limit is greater one' do
          it 'returns the history of all matching configs' do
            config1 = Models::Config.make
            Models::Config.make

            get '/?type=my-type&limit=2'

            expect(last_response.status).to eq(200)

            result = JSON.parse(last_response.body)
            expect(result.class).to be(Array)
            expect(result.size).to eq(2)
            expect(result).to include(
              'content' => config1.content,
              'id' => config1.id.to_s,
              'type' => config1.type,
              'name' => config1.name,
              'created_at' => config1.created_at.to_s,
              'team' => nil,
            )
          end
        end
      end
    end

    describe 'POST', '/' do
      let(:config_data) { 'a: 1' }
      let(:request_body) do
        JSON.generate('name' => 'my-name', 'type' => 'my-type', 'content' => config_data)
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
            'type' => 'my-type',
            'name' => 'my-name',
            'content' => 'a: 1',
            'created_at' => config.created_at.to_s,
            'team' => nil,
          )
        end

        it 'creates a new config when one exists with different content' do
          Models::Config.make(
            name: 'my-name',
            type: 'my-type',
            content: 'a: 123',
          )

          expect do
            post(
              '/',
              JSON.generate(
                'name' => 'my-name',
                'type' => 'my-type',
                'content' => 'b: 12345',
              ),
              'CONTENT_TYPE' => 'application/json',
            )
          end.to change(Models::Config, :count)

          expect(last_response.status).to eq(201)
        end

        it 'ignores config when config already exists' do
          Models::Config.make(
            name: 'my-name',
            type: 'my-type',
            content: 'a: 123',
          )

          expect do
            post '/', JSON.generate(
              'name' => 'my-name',
              'type' => 'my-type',
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
          expect(event.object_type).to eq('config/my-type')
          expect(event.object_name).to eq('my-name')
          expect(event.action).to eq('create')
          expect(event.user).to eq('admin')
        end

        context 'when the content is no YAML hash' do
          let(:request_body) { '{"name":"n","type":"t","content":"I am a string"}' }

          it 'return 400' do
            post '/', request_body, 'CONTENT_TYPE' => 'application/json'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440_011)
            expect(JSON.parse(last_response.body)['description']).to eq('YAML hash expected')
          end
        end

        context 'when `type` argument is missing' do
          let(:request_body) do
            JSON.generate('name' => 'my-name', 'content' => '{}')
          end

          it 'creates a new event and return 400' do
            post '/', request_body, 'CONTENT_TYPE' => 'application/json'

            event = Bosh::Director::Models::Event.first
            expect(event.object_type).to eq('config/')
            expect(event.object_name).to eq('my-name')
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
            JSON.generate('type' => 'my-type', 'content' => '{}')
          end

          it 'creates a new event and return 400' do
            post '/', request_body, 'CONTENT_TYPE' => 'application/json'

            event = Bosh::Director::Models::Event.first
            expect(event.object_type).to eq('config/my-type')
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
              Models::Config.make(
                type: 'my-type',
                name: 'my-name',
              )
            end

            it 'deletes the config' do
              expect(delete('/?type=my-type&name=my-name').status).to eq(204)

              configs = JSON.parse(get('/?type=my-type&name=my-name&limit=10').body)

              expect(configs.count).to eq(0)
            end
          end

          context "when there is no config matching given 'type' and 'name'" do
            it 'responds with 404' do
              expect(delete('/?type=my-type&name=my-name').status).to eq(404)
            end
          end
        end

        context "when 'type' parameter is missing" do
          it 'responds with 400' do
            response = delete('/?name=my-name')

            expect(response.status).to eq(400)
            expect(JSON.parse(response.body)['description']).to eq("'type' is required")
          end
        end

        context "when 'name' parameter is missing" do
          it 'responds with 400' do
            response = delete('/?type=my-type')

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
          let(:config_id) { Models::Config.make.id }

          it 'deletes the config specified by id' do
            expect(delete("/#{config_id}").status).to eq(204)
            expect(Models::Config[config_id].deleted).to eq(true)
          end
        end

        context 'when config does not exists' do
          it 'deletes the config specified by id' do
            expect(delete("/5").status).to eq(404)
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

          let(:allowed_format_1) do
            JSON.dump(
              'from' => { 'id' => '<id>' },
              'to' => { 'id' => '<id>' },
            )
          end

          let(:allowed_format_2) do
            JSON.dump(
              'type' => '<type>',
              'name' => '<name>',
              'content' => '<content>',
            )
          end

          it 'returns 400 with error details' do
            post '/diff', body, 'CONTENT_TYPE' => 'application/json'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440_010)
            expect(JSON.parse(last_response.body)['description'])
              .to eq("Only two request formats are allowed:\n1. #{allowed_format_1}\n2. #{allowed_format_2}")
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
              expect(JSON.parse(last_response.body)['description'])
                .to eq("Only two request formats are allowed:\n1. #{allowed_format_1}\n2. #{allowed_format_2}")

              post(
                '/diff',
                JSON.generate('from' => { 'id' => '1' }, 'to' => { 'id' => 'foo' }),
                'CONTENT_TYPE' => 'application/json',
              )

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(440_010)
              expect(JSON.parse(last_response.body)['description'])
                .to eq("Only two request formats are allowed:\n1. #{allowed_format_1}\n2. #{allowed_format_2}")
            end
          end

          context 'when any of the given `id` values is from type integer' do
            it 'returns 400 with error details' do
              post '/diff', JSON.generate('from' => { 'id' => 1 }, 'to' => { 'id' => '1' }), 'CONTENT_TYPE' => 'application/json'

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(440_010)
              expect(JSON.parse(last_response.body)['description'])
                .to eq("Only two request formats are allowed:\n1. #{allowed_format_1}\n2. #{allowed_format_2}")
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
                expect(last_response.body).to eq('{"diff":[]}')
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
                expect(json_response).to eq(
                  'diff' => [
                    ['azs:', nil],
                    ['- name: az2', 'removed'],
                    ['  properties:', 'removed'],
                    ['    some-key: "<redacted>"', 'removed'],
                  ],
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
              expect(last_response.body).to eq('{"diff":[["azs:","added"],["- name: az1","added"],["  properties: {}","added"]]}')
            end
          end

          context 'when previous config is nil' do
            before do
              Models::Config.create(
                type: 'myType',
                name: 'myName',
                raw_manifest: nil,
              )
            end
            let(:new_content) { YAML.dump(config_hash_with_one_az) }

            it 'returns the diff' do
              post(
                '/diff',
                new_config,
                'CONTENT_TYPE' => 'application/json',
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["azs:","added"],["- name: az1","added"],["  properties: {}","added"]]}')
            end
          end
        end

        context 'when diffing two versions by id' do
          let(:dev_team) { Models::Team.create(name: 'dev') }
          let(:dev_team_config) do
            Models::Config.create(
              type: 'custom',
              name: 'dev-team',
              raw_manifest: { 'a' => 5 },
              team_id: dev_team.id,
            )
          end

          let(:other_team) { Models::Team.create(name: 'other') }
          let(:other_team_config) do
            Models::Config.create(
              type: 'custom',
              name: 'other-team',
              raw_manifest: { 'b' => 5 },
              team_id: other_team.id,
            )
          end

          it 'returns the diff' do
            post(
              '/diff',
              JSON.dump(from: { id: dev_team_config.id.to_s }, to: { id: other_team_config.id.to_s }),
              'CONTENT_TYPE' => 'application/json',
            )
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('{"diff":[["a: 5","removed"],["",null],["b: 5","added"]]}')
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
        JSON.generate('type' => 'my-type', 'content' => '{}')
      end

      let(:dev_team) { Models::Team.create(name: 'dev') }
      let(:other_team) { Models::Team.create(name: 'other') }
      let!(:dev_config) do
        Models::Config.make(
          content: 'some-yaml',
          name: 'dev_config',
          created_at: Time.now - 3.days,
          team_id: dev_team.id,
        )
      end

      let!(:other_config) do
        Models::Config.make(
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
          expect(delete('/?type=my-type&name=dev_config').status).to eq(401)
        end
      end

      context 'when user has a team admin membership' do
        before { basic_authorize 'dev-team-member', 'dev-team-member' }

        it 'returns team configs' do
          get '/?type=my-type&latest=false'
          expect(get('/?type=my-type&latest=false').status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body)).to include(include('content' => 'some-yaml'))
          expect(JSON.parse(last_response.body).first['team']).to eq('dev')
        end

        it 'stores team-specific configs' do
          expect do
            post(
              '/',
              JSON.generate('name' => 'my-name', 'type' => 'my-type', 'content' => 'a: 123'),
              'CONTENT_TYPE' => 'application/json',
            )
          end.to change(Bosh::Director::Models::Config, :count).from(2).to(3)
          expect(Bosh::Director::Models::Config.all[2][:team_id]).to eq(dev_team.id)
        end

        it 'deletes the config' do
          expect(delete('/?type=my-type&name=dev_config').status).to eq(204)
          configs = JSON.parse(get('/?type=my-type&name=dev_config&latest=false').body)
          expect(configs.count).to eq(0)
        end

        it "cannot overwrite another team's config" do
          expect(
            post(
              '/',
              JSON.generate('name' => 'other_config', 'type' => 'my-type', 'content' => 'a: 123'),
              'CONTENT_TYPE' => 'application/json',
            ).status,
          ).to eq(401)
        end

        it "cannot delete another team's config" do
          expect(delete('/?type=my-type&name=other_config').status).to eq(401)
        end

        it "cannot delete another team's config by id" do
          expect(delete("/#{other_config.id}").status).to eq(401)
        end
      end

      context 'when user has a team read membership' do
        before { basic_authorize 'dev-team-read-member', 'dev-team-read-member' }

        it 'permits read access to the teams config' do
          get '/?type=my-type&latest=false'
          expect(get('/?type=my-type&latest=false').status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body)).to include(include('content' => 'some-yaml'))
        end

        it 'denies write access' do
          expect(post('/', request_body, 'CONTENT_TYPE' => 'application/json').status).to eq(401)
        end

        it 'does not permit delete the config' do
          expect(delete('/?type=my-type&name=dev_config').status).to eq(401)
        end

        it 'returns team configs' do
          get '/?type=my-type&latest=false'
          expect(get('/?type=my-type&latest=false').status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body).first['team']).to eq('dev')
        end
      end

      context 'when user is an admin' do
        before { basic_authorize('admin', 'admin') }

        it 'permits read access to all configs' do
          expect(get('/?type=my-type&latest=false').status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
        end

        it 'permits write access' do
          expect do
            post(
              '/',
              JSON.generate('name' => 'my-name', 'type' => 'my-type', 'content' => 'a: 123'),
              'CONTENT_TYPE' => 'application/json',
            )
          end.to change(Bosh::Director::Models::Config, :count).from(2).to(3)
        end

        it 'deletes the config' do
          expect(delete('/?type=my-type&name=dev_config').status).to eq(204)
          configs = JSON.parse(get('/?type=my-type&name=dev_config&latest=false').body)
          expect(configs.count).to eq(0)
        end

        it 'returns teams value' do
          get '/?type=my-type&latest=false'
          expect(get('/?type=my-type&latest=false').status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
          expect(JSON.parse(last_response.body).map { |x| x['team'] }).to contain_exactly('dev', 'other')
        end
      end

      context 'when user has read-only access to director' do
        before { basic_authorize('reader', 'reader') }

        it 'permits read access to all configs' do
          expect(get('/?type=my-type&latest=false').status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
        end

        it 'denies write access' do
          expect(post('/', request_body, 'CONTENT_TYPE' => 'application/json').status).to eq(401)
        end

        it 'does not permit delete the config' do
          expect(delete('/?type=my-type&name=dev_config').status).to eq(401)
        end

        it 'returns all configs' do
          get '/?type=my-type&latest=false'
          expect(get('/?type=my-type&latest=false').status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
          expect(JSON.parse(last_response.body).first['team']).to eq('dev')
          expect(JSON.parse(last_response.body)[1]['team']).to eq('other')
        end
      end
    end

    describe 'id' do
      let!(:config_example) { Bosh::Director::Models::Config.make(id: 123, type: 'my-type', name: 'default', content: '1') }

      context 'with authenticated admin user' do
        before(:each) do
          authorize('admin', 'admin')
        end

        it 'it returns the specified config' do
          get('/123')

          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)).to eq('id' => '123', 'type' => 'my-type', 'name' => 'default', 'content' => '1', 'created_at' => config_example.created_at.to_s, 'team' => nil)
        end

        context 'when no config is found' do
          it 'returns a 404' do
            get('/999')

            expect(last_response.status).to eq(404)
          end
        end

        context 'when `id` is not a string containing an integer' do
          it 'returns a 404' do
            get('/invalid-id')

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
