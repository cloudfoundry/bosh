require 'spec_helper'

module Bosh::Director::ConfigServer
  describe DeepHashReplacement do
    let(:subject) { DeepHashReplacement.new }

    describe '#variables_paths' do
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
          'instance_groups' => [
          {
            'name' => 'db',
            'jobs' => [
              {'name' => 'mysql', 'template' => 'template1', 'properties' => job_props},
              {'name' => '((job_name))', 'template' => 'template1'}
            ],
            'properties' => {
              'a' => ['123', 45, '((secret_key))'],
              'b' => 'vroom.((my_domain)).com',
              'c' => 'vroom.((my_domain)).com:((port))',
              'd' => [0, 1, 2, '((my_index)) vroom ((/smurf/hello))']
            }
          }
        ],
          'properties' => global_props
        }
      end

      it 'creates replacement map for all necessary variables' do
        expected_result = [
          {'variables'=>['((director_uuid_placeholder))'], 'path'=>['director_uuid'],'is_key'=> false},
          {'variables'=>['((/my/name/is/smurf/12-3))'], 'path'=>['smurf'], 'is_key'=>false},
          {'variables'=>['((my/name/is/gar_gamel))'], 'path'=>['gargamel'], 'is_key'=>false},
          {'variables'=>['((nuclear_launch_code))'], 'path'=>['instance_groups', 0, 'jobs', 0, 'properties', 'a', 'b', 'c'], 'is_key'=>false},
          {'variables'=>['((job_name))'], 'path'=>['instance_groups', 0, 'jobs', 1, 'name'], 'is_key'=>false},
          {'variables'=>['((secret_key))'], 'path'=>['instance_groups', 0, 'properties', 'a', 2], 'is_key'=>false},
          {'variables'=>['((my_domain))'], 'path'=>['instance_groups', 0, 'properties', 'b'], 'is_key'=>false},
          {'variables'=>['((my_domain))', '((port))'], 'path'=>['instance_groups', 0, 'properties', 'c'], 'is_key'=>false},
          {'variables'=>['((my_index))', '((/smurf/hello))'], 'path'=>['instance_groups', 0, 'properties', 'd', 3], 'is_key'=>false},
          {'variables'=>['((bla))'], 'path'=>['properties', 'b'], 'is_key'=>false}
        ]

        replacement_list = subject.variables_path(sample_hash)
        expect(replacement_list).to eq(expected_result)
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
            {'variables'=>['((!blue))'], 'path'=>['smurf'], 'is_key'=>false},
            {'variables'=>['((!what_is_my_color))'], 'path'=>['gargamel', 'color'], 'is_key'=>false}
          ]

          replacement_list = subject.variables_path(sample_hash)
          expect(replacement_list).to eq(expected_result)
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

          expected_replacements = [
            {'variables'=>['((director_uuid_placeholder))'], 'path'=>['director_uuid'], 'is_key' =>false},
            {'variables'=>['((/my/name/is/smurf/12-3))'], 'path'=>['smurf'], 'is_key' =>false},
            {'variables'=>['((my/name/is/gar_gamel))'], 'path'=>['gargamel'], 'is_key' =>false},
            {'variables'=>['((job_name))'], 'path'=>['instance_groups', 0, 'jobs', 1, 'name'], 'is_key' =>false},
            {'variables'=>['((address_placeholder))'], 'path'=>['instance_groups', 0, 'jobs', 0, 'consumes', 'primary_db', 'instances', 0, 'address'], 'is_key' =>false}
          ]

          replacement_list = subject.variables_path(sample_hash, ignored_subtrees)
          expect(replacement_list).to match_array(expected_replacements)
        end
      end

      context 'when the key is a variable' do
        let(:sample_hash) do
          {
            '((my_key))' => {
              '((my_other_key))' => '((what_is_my_color))',
            },
          }
        end

        it 'handles it correctly and removes ! from key (for spiff)' do
          expected_result = [
            { 'variables' => ['((what_is_my_color))'], 'path' => ['((my_key))', '((my_other_key))'], 'is_key' => false },
            { 'variables' => ['((my_other_key))'], 'path' => ['((my_key))'], 'is_key' => true },
            { 'variables' => ['((my_key))'], 'path' => [], 'is_key' => true },
          ]

          replacement_list = subject.variables_path(sample_hash)
          expect(replacement_list).to eq(expected_result)
        end
      end
    end

    describe '#replace_variables' do
      let(:values) do
        {
          '((key_0))' => 'smurf_0',
          '((key_1))' => 'smurf_1',
          '((key_2))' => 'smurf_2',
          '((key_3))' => 'smurf_3',
          '((key_4))' => { 'name' => 'papa-smurf' },
          '((key_5))' => 504,
          '((key_6))' => nil,
          '((key_7))' => '((key_8))',
          '((key_8))' => '((key_7))',
          '((deep_key))' => 'mama-smurf',
          '((deeper_key))' => 'auntie-smurf',
          '((deepest_key))' => 'grandma-smurf',
        }
      end

      it 'replaces variables in simple unnested objects' do
        obj = {
          'bla' => '((key_1))',
          'test' => '((key_4))',
        }

        paths = [
          { 'variables' => ['((key_1))'], 'path' => ['bla'] },
          { 'variables' => ['((key_4))'], 'path' => ['test'] },
        ]

        result = subject.replace_variables(obj, paths, values)
        expect(result) .to eq('bla' => 'smurf_1', 'test' => { 'name' => 'papa-smurf' })
      end

      it 'replaces variables in nested objects' do
        obj = {
          'bla' => '((key_1))',
          'a' => {
            'b' => ['bla', '((key_1))', '((key_2))', {'c' => '((key_3))'}]
          },
          'deep' => {
            'deeper' => {
              'deepest' => {
                'hello' => 'smile',
                'state' => '((key_4))',
                'number' => '((key_5))',
              }
            }
          }
        }

        expected = {
          'bla' => 'smurf_1',
          'a' => {
            'b' => ['bla', 'smurf_1', 'smurf_2', {'c' => 'smurf_3'}]
          },
          'deep' => {
            'deeper' => {
              'deepest' => {
                'hello' => 'smile',
                'state' => {
                  'name' => 'papa-smurf'
                },
                'number' => 504,
              }
            }
          }
        }

        paths = [
          {'variables' => ['((key_1))'], 'path' => ['bla']},
          {'variables' => ['((key_1))'], 'path' => ['a', 'b', 1]},
          {'variables' => ['((key_2))'], 'path' => ['a', 'b', 2]},
          {'variables' => ['((key_3))'], 'path' => ['a', 'b', 3, 'c']},
          {'variables' => ['((key_4))'], 'path' => ['deep', 'deeper', 'deepest', 'state']},
          {'variables' => ['((key_5))'], 'path' => ['deep', 'deeper', 'deepest', 'number']}
        ]

        result = DeepHashReplacement.new.replace_variables(obj, paths, values)

        expect(result).to eq(expected)
      end

      context 'when having mid-string interpolation' do
        it 'supports multiple variables in one value' do
          obj = {
            'bla' => 'delimiter1-((key_1))-delimiter2-((key_2))-delimiter3',
            'combinations' => '((key_1)) age is ((key_5))',
            'a' => {
              'b' => [
                'bla',
                'delimiter1-((key_3))-delimiter2-((key_2))-delimiter3',
                'delimiter1-((key_2))-delimiter2-((key_2))',
                {
                  'c' => 'delimiter1-((key_3))-delimiter2-((key_1))-delimiter3-((key_2))'
                }
              ]
            }
          }

          expected = {
            'bla' => 'delimiter1-smurf_1-delimiter2-smurf_2-delimiter3',
            'combinations' => 'smurf_1 age is 504',
            'a' => {
              'b' => [
                'bla',
                'delimiter1-smurf_3-delimiter2-smurf_2-delimiter3',
                'delimiter1-smurf_2-delimiter2-smurf_2',
                {
                  'c' => 'delimiter1-smurf_3-delimiter2-smurf_1-delimiter3-smurf_2'
                }
              ]
            }
          }

          paths = [
            {'variables' => ['((key_1))', '((key_2))'], 'path' => ['bla']},
            {'variables' => ['((key_1))', '((key_5))'], 'path' => ['combinations']},
            {'variables' => ['((key_2))', '((key_3))'], 'path' => ['a', 'b', 1]},
            {'variables' => ['((key_2))'], 'path' => ['a', 'b', 2]},
            {'variables' => ['((key_1))', '((key_2))', '((key_3))'], 'path' => ['a', 'b', 3, 'c']},
          ]

          result = DeepHashReplacement.new.replace_variables(obj, paths, values)
          expect(result).to eq(expected)
        end

        it 'replaces the variables only once' do
          input = {
            'smurf' => '((key_7)) meow ((key_8))'
          }

          expected_output = {
            'smurf' => '((key_8)) meow ((key_7))'
          }

          paths = [
            {'variables' => ['((key_7))', '((key_8))'], 'path' => ['smurf']},
          ]

          result = DeepHashReplacement.new.replace_variables(input, paths, values)
          expect(result).to eq(expected_output)
        end

        context 'when value returned by config server is not an integer or a string' do
          it 'throws an error' do
            obj = {
              'name' => '((key_1))',
              'url' => 'http://((key_4))',
              'link' => 'visit us at http://((key_6))'
            }

            paths = [
              {
                'variables' => ['((key_1))'],
                'path' => ['name']
              },
              {
                'variables' => ['((key_4))'],
                'path' => ['url']
              },
              {
                'variables' => ['((key_6))'],
                'path' => ['link']
              }
            ]

            expected_error_msg = <<-EXPECTED.strip
- Failed to substitute variable: Can not replace '((key_4))' in 'http://((key_4))'. The value should be a String or an Integer.
- Failed to substitute variable: Can not replace '((key_6))' in 'visit us at http://((key_6))'. The value should be a String or an Integer.
            EXPECTED

            expect {
              DeepHashReplacement.new.replace_variables(obj, paths, values)
            }.to raise_error { |e|
              expect(e.is_a?(Bosh::Director::ConfigServerIncorrectVariablePlacement)).to be_truthy
              expect(e.message).to eq(expected_error_msg)
            }
          end
        end
      end

      context 'when the key is a variable' do
        it 'replaces the key variables' do
          obj = {
            '((key_0))' => '((key_1))',
            '((deep_key))' => {
              '((deeper_key))' => {
                '((deepest_key))' => {
                  'hello' => 'smile',
                  'state' => '((key_4))',
                  'number' => '((key_5))',
                },
              },
            },
          }


          expected = {
            'smurf_0' => 'smurf_1',
            'mama-smurf' => {
              'auntie-smurf' => {
                'grandma-smurf' => {
                  'hello' => 'smile',
                  'state' => { 'name' => 'papa-smurf' },
                  'number' => 504,
                },
              },
            },
          }


          paths = subject.variables_path(obj)
          result = subject.replace_variables(obj, paths, values)

          expect(result).to eq(expected)
        end
      end
    end
  end
end
