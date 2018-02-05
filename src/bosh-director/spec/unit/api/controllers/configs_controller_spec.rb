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

          get '/?&latest=true'
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

            get '/?type=my-type&name=my-config&latest=true'
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

          get '/?type=my-type&latest=true'
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
        end

        context 'when no records match the filters' do
          it 'returns empty' do
            get '/?type=my-type&name=notExisting&latest=true'

            expect(last_response.status).to eq(200)

            result = JSON.parse(last_response.body)
            expect(result.class).to be(Array)
            expect(result).to eq([])
          end
        end

        context 'when no type is given' do
          it 'does not filter by type' do
            Models::Config.make(
              content: 'some-other-yaml',
              created_at: Time.now - 2.days,
            )

            newest_config = 'new_config'
            Models::Config.make(
              content: newest_config,
              created_at: Time.now - 1.days,
            )

            get '/?latest=true'

            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
          end
        end

        context 'when no latest param is given' do
          it 'return 400' do
            get '/?type=my-type&name=some-name'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(440_010)
            expect(JSON.parse(last_response.body)['description']).to eq("'latest' is required")
          end
        end

        context 'when latest param is given and has wrong value' do
          it 'return 400' do
            get '/?type=my-type&name=some-name&latest=foo'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(40_005)
            expect(JSON.parse(last_response.body)['description']).to eq("'latest' must be 'true' or 'false'")
          end
        end

        context 'when latest is false' do
          it 'returns the history of all matching configs' do
            config1 = Models::Config.make
            Models::Config.make

            get '/?type=my-type&latest=false'

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
              'teams' => [],
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

        it 'creates a new config' do
          expect do
            post '/', request_body, 'CONTENT_TYPE' => 'application/json'
          end.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

          expect(last_response.status).to eq(201)

          config = Bosh::Director::Models::Config.first
          expect(JSON.parse(last_response.body)).to eq(
            'id' => Bosh::Director::Models::Config.first.id.to_s,
            'type' => 'my-type',
            'name' => 'my-name',
            'content' => 'a: 1',
            'created_at' => config.created_at.to_s,
            'teams' => [],
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

              configs = JSON.parse(get('/?type=my-type&name=my-name&latest=false').body)

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
            expect(JSON.parse(last_response.body)['description']).to eq("Only two request formats are allowed:\n1. #{allowed_format_1}\n2. #{allowed_format_2}")
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
              expect(JSON.parse(last_response.body)['description']).to eq("Only two request formats are allowed:\n1. #{allowed_format_1}\n2. #{allowed_format_2}")

              post(
                '/diff',
                JSON.generate('from' => { 'id' => '1' }, 'to' => { 'id' => 'foo' }),
                'CONTENT_TYPE' => 'application/json',
              )

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(440_010)
              expect(JSON.parse(last_response.body)['description']).to eq("Only two request formats are allowed:\n1. #{allowed_format_1}\n2. #{allowed_format_2}")
            end
          end

          context 'when any of the given `id` values is from type integer' do
            it 'returns 400 with error details' do
              post '/diff', JSON.generate('from' => { 'id' => 1 }, 'to' => { 'id' => '1' }), 'CONTENT_TYPE' => 'application/json'

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(440_010)
              expect(JSON.parse(last_response.body)['description']).to eq("Only two request formats are allowed:\n1. #{allowed_format_1}\n2. #{allowed_format_2}")
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
                expect(last_response.body).to eq('{"diff":[["azs:",null],["- name: az2","removed"],["  properties:","removed"],["    some-key: \"<redacted>\"","removed"]]}')
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
                expect(JSON.parse(last_response.body)['error']).to eq('YAML hash expected')
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
          before do
            @first = Models::Config.create(
              type: 'myType',
              name: 'myName',
              raw_manifest: { 'a' => 5 },
            )
            @second = Models::Config.create(
              type: 'myType',
              name: 'myName',
              raw_manifest: { 'b' => 5 },
            )
          end

          it 'returns the diff' do
            post(
              '/diff',
              JSON.dump(from: { id: @first.id.to_s }, to: { id: @second.id.to_s }),
              'CONTENT_TYPE' => 'application/json',
            )
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('{"diff":[["a: 5","removed"],["",null],["b: 5","added"]]}')
          end

          context 'when config with given "id" does not exist' do
            it 'returns 404 with error details' do
              post(
                '/diff',
                JSON.dump(from: { id: '5' }, to: { id: @second.id.to_s }),
                'CONTENT_TYPE' => 'application/json',
              )

              expect(last_response.status).to eq(404)
              expect(JSON.parse(last_response.body)['code']).to eq(440_012)
              expect(JSON.parse(last_response.body)['description']).to eq("Config with ID '5' not found.")
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

      before do
        Models::Config.make(
          content: 'some-yaml',
          name: 'dev_config',
          created_at: Time.now - 3.days,
          team_id: dev_team.id,
        )

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

        it 'permits read access to the teams config' do
          get '/?type=my-type&latest=false'
          expect(get('/?type=my-type&latest=false').status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body)).to include(include('content' => 'some-yaml'))
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

        it 'stores team_id of the autorized user' do
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

        it 'does not return teams value' do
          get '/?type=my-type&latest=false'
          expect(get('/?type=my-type&latest=false').status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body).first['teams']).to be_nil
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

        it 'does not return teams value' do
          get '/?type=my-type&latest=false'
          expect(get('/?type=my-type&latest=false').status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body).first['teams']).to be_nil
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
          expect(JSON.parse(last_response.body).map { |x| x['teams'] }).to contain_exactly(['dev'], ['other'])
        end
      end

      context 'when user is a reader' do
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

        it 'does not return teams value' do
          get '/?type=my-type&latest=false'
          expect(get('/?type=my-type&latest=false').status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
          expect(JSON.parse(last_response.body).first['teams']).to be_nil
          expect(JSON.parse(last_response.body)[1]['teams']).to be_nil
        end
      end
    end
  end
end
