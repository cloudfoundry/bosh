require 'spec_helper'

module Bosh::Director::ConfigServer
  describe DeepHashReplacement do
    describe "#placeholders_paths" do

      let(:global_props) do
        {'a' => 'test', 'b' => '((bla))'}
      end

      let(:instance_groups_props) do
        {'a' => ['123', 45, '((secret_key))']}
      end

      let(:job_props) do
        {
          'a' => {
            'b' => {
              'c' => '((nuclear_launch_code))'
            }
          }
        }
      end

      let(:env) do
        {
          'a' => 'public',
          'b' => [{'f' => '((my_db_passwd))'}, ['public', '((secret2))']]
        }
      end

      let(:sample_hash) do
        {
          'name' => 'test_manifest',
          'director_uuid' => '((director_uuid_placeholder))',
          'smurf' => '((/my/name/is/smurf/12-3))',
          'gargamel' => '((my/name/is/gar_gamel))',
          'resource_pools' => [
          {
            'name' => 'rp',
            'env' => env
          }
        ],
          'instance_groups' => [
          {
            'name' => 'db',
            'jobs' => [
              {'name' => 'mysql', 'template' => 'template1', 'properties' => job_props},
              {'name' => '((job_name))', 'template' => 'template1'}
            ],
            'properties' => {'a' => ['123', 45, '((secret_key))']}
          }
        ],
          'properties' => global_props
        }
      end

      let(:replacement_list) do
        DeepHashReplacement.new.placeholders_paths(sample_hash)
      end

      it 'creates replacement map for all necessary placeholders' do
        expected_result = [
          {'placeholder'=>'((director_uuid_placeholder))', 'path'=>['director_uuid']},
          {'placeholder'=>'((my_db_passwd))', 'path'=>['resource_pools', 0, 'env', 'b', 0, 'f']},
          {'placeholder'=>'((secret2))', 'path'=>['resource_pools', 0, 'env', 'b', 1, 1]},
          {'placeholder'=>'((nuclear_launch_code))', 'path'=>['instance_groups', 0, 'jobs', 0, 'properties', 'a', 'b', 'c']},
          {'placeholder'=>'((job_name))', 'path'=>['instance_groups', 0, 'jobs', 1, 'name']},
          {'placeholder'=>'((bla))', 'path'=>['properties', 'b']},
          {'placeholder'=>'((secret_key))', 'path'=>['instance_groups', 0, 'properties', 'a', 2]},
          {'placeholder'=>'((/my/name/is/smurf/12-3))', 'path'=>['smurf']},
          {'placeholder'=>'((my/name/is/gar_gamel))', 'path'=>['gargamel']}
        ]

        expect(replacement_list).to match_array(expected_result)
      end

      context 'when key starts with a bang' do
        let(:sample_hash) do
          {
            'smurf' => '((!blue))',
            'gargamel' => {
              'color' => '((!what_is_my_color))'
            }
          }
        end

        it 'handles it correctly and removes ! from key (for spiff)' do
          expected_result = [
            {'placeholder'=>'((!blue))', 'path'=>['smurf']},
            {'placeholder'=>'((!what_is_my_color))', 'path'=>['gargamel', 'color']}
          ]

          expect(replacement_list).to match_array(expected_result)
        end
      end

      context 'when to_be_ignored subtrees exist' do
        let(:consume_spec) do
          {
            'primary_db' => {
              'instances' => [
                {
                  'address' => '((address_placeholder))'
                }
              ],
              'properties'  => {
                'port' => '((manual_link_port))',
                'adapter' => 'mysql2',
                'username' => '((user_name_placeholder))',
                'password' => 'some-password',
                'name' => '((name_placeholder))'
              }
            }
          }
        end

        before do
          sample_hash['instance_groups'][0]['jobs'][0]['consumes'] = consume_spec
        end

        it 'should should not include ignored paths in the result' do
          any_string = String
          index = Integer

          ignored_subtrees = []
          ignored_subtrees << ['instance_groups', index, 'jobs', index, 'consumes', any_string, 'properties']
          ignored_subtrees << ['instance_groups', index, 'jobs', index, 'properties']
          ignored_subtrees << ['instance_groups', index, 'properties']
          ignored_subtrees << ['properties']

          replacements = DeepHashReplacement.new.placeholders_paths(sample_hash, ignored_subtrees)

          expected_replacements = [
            {'placeholder'=>'((my_db_passwd))', 'path'=>['resource_pools', 0, 'env', 'b', 0, 'f']},
            {'placeholder'=>'((secret2))', 'path'=>['resource_pools', 0, 'env', 'b', 1, 1]},
            {'placeholder'=>'((job_name))', 'path'=>['instance_groups', 0, 'jobs', 1, 'name']},
            {'placeholder'=>'((address_placeholder))', 'path'=>['instance_groups', 0, 'jobs', 0, 'consumes', 'primary_db', 'instances', 0, 'address']},
            {'placeholder'=>'((director_uuid_placeholder))', 'path'=>['director_uuid']},
            {'placeholder'=>'((/my/name/is/smurf/12-3))', 'path'=>['smurf']},
            {'placeholder'=>'((my/name/is/gar_gamel))', 'path'=>['gargamel']}
          ]
          expect(replacements).to match_array(expected_replacements)
        end
      end
    end

    describe "#replace_placeholders" do
      let(:values) do
        { "((key))" => "smurf" }
      end

      it 'replaces placeholders in simple unnested objects' do
        obj = {"bla" => "((key))"}
        paths = [
          {
            'placeholder' => '((key))',
            'path' => ['bla']
          }
        ]
        result = DeepHashReplacement.new.replace_placeholders(obj, paths, values)
        expect(result).to eq({"bla" => "smurf"})
      end

      it 'replaces placeholders in nested objects' do
        obj = {
          "bla" => "((key))",
          "a" => {
            "b" => ["bla", "((key))", {"c" => "((key))"}]
          }
        }

        expected = {
          "bla" => "smurf",
          "a" => {
            "b" => ["bla", "smurf", {"c" => "smurf"}]
          }
        }

        paths = [{'placeholder' => '((key))', 'path' => ['bla']},
                 {'placeholder' => '((key))', 'path' => ['a', 'b', 1]},
                 {'placeholder' => '((key))', 'path' => ['a', 'b', 2, "c"]}
        ]

        result = DeepHashReplacement.new.replace_placeholders(obj, paths, values)

        expect(result).to eq(expected)
      end
    end
  end
end
