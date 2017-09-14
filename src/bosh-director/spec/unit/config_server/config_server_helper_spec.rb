require 'spec_helper'

module Bosh::Director::ConfigServer
  describe ConfigServerHelper do
    describe '#is_full_variable??' do
      it 'should return true if value is a full variable' do
        placeholders = [
          '((smurf))', '((!smurf))', '(())', '(( ))',
          '((  ))', '(( smurf))', '((/smurf))', '((/smurf))', '((/smurf))',
          '((/))', '((vroom vroo/m))'
        ]

        placeholders.each do |variable|
          expect(ConfigServerHelper.is_full_variable?(variable)).to be_truthy
        end
      end

      it 'should return false if value is not a full variable' do
        not_placeholders = [
          '((smurf', '(!smurf))', 'smurf))', '((smurf', '(( smurf)',
          '(()', '((', '()', '((hello))((bye))',
          "foo//foo\n((blah))", # 151110778
        ]

        not_placeholders.each do |not_variable|
          expect(ConfigServerHelper.is_full_variable?(not_variable)).to be_falsey
        end
      end
    end

    describe '#extract_variables_from_string' do
      it 'handles nil input' do
        expect(ConfigServerHelper.extract_variables_from_string(nil)).to match_array([])
      end

      it 'should return the variables' do
        input = {
          '((smurf))' => ['((smurf))'],
          'smurf ((smurf1)) likes ((smurf2))' => ['((smurf1))', '((smurf2))'],
          '(())' => ['(())'],
          '(( ))' => ['(( ))'],
          '((hello)) ((vroom))((smurf))-happy' => ['((hello))', '((vroom))', '((smurf))'],
          'hello(())' => ['(())'],
          'hello((/test/1/2/3)) hello ((cats))' => ['((/test/1/2/3))', '((cats))'],
          '' => [],
          'illigal char ((&&^&)) and ((##$$%%))' => ['((&&^&))', '((##$$%%))'],
          'cat' => []
        }

        input.each do |k, v|
          expect(ConfigServerHelper.extract_variables_from_string(k)).to match_array(v)
        end
      end
    end

    describe '#extract_variable_name' do
      context 'when name meets specs' do
        it 'should return the value passed in without brackets' do
          names = {
            '((smurf))' => 'smurf',
            '((smurf_))' => 'smurf_',
            '((1smurf))' => '1smurf',
            '((1smurf-))' => '1smurf-',
            '((1sm_urf-))' => '1sm_urf-',
            '((123_-))' => '123_-',
            '((123))' => '123',
            '((_))' => '_',
            '((/smurf))' => '/smurf',
            '((/smurf/gargamel))' => '/smurf/gargamel',
            '((/smurf/gargamel/cat))' => '/smurf/gargamel/cat',
            '((/smurf/gar_gamel))' => '/smurf/gar_gamel'
          }

          names.each do |k, v|
            expect(ConfigServerHelper.extract_variable_name(k)).to eq(v)
          end
        end

        it 'should handle names starting with bang' do
          names = {
            '((!/smurf/gar_gamel))' => '/smurf/gar_gamel',
            '((!smurf))' => 'smurf',
            '((!smurf/cat))' => 'smurf/cat',
          }

          names.each do |k, v|
            expect(ConfigServerHelper.extract_variable_name(k)).to eq(v)
          end
        end
      end

      context 'when name does NOT meet specs' do
        context 'when name has invalid characters' do
          it 'should raise a ConfigServerIncorrectNameSyntax error' do
            invalid_placeholders_names = [
              '(())', '(( ))', '((%))', '((  ))', '((123 345))', '((@bosh))',
              '((hello_)))', '((t*))', '(()))', '((())))', '((smurf cat))',
              "((invalid\ninvalid))", "test\n((invalid))\ntest", # 151110778
            ]

            invalid_placeholders_names.each do |invalid_entity|
              expect {
                ConfigServerHelper.extract_variable_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Variable name '#{invalid_entity.gsub(/(\A\(\(|\)\)\z)/, '')}' must only contain alphanumeric, underscores, dashes, or forward slash characters"
                   )
            end
          end
        end

        context 'when name ends with a forward slash' do
          it 'should raise a ConfigServerIncorrectNameSyntax error' do
            invalid_placeholders_names = [
              '((/))', '((hello/))', '((//))', '((/test/))', '((test//))', '((test///))'
            ]

            invalid_placeholders_names.each do |invalid_entity|
              expect {
                ConfigServerHelper.extract_variable_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Variable name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' must not end with a forward slash"
                   )
            end
          end
        end

        context 'when name has two consecutive forward slashes' do
          it 'should raise a ConfigServerIncorrectNameSyntax error' do
            invalid_placeholders_names = [
              '((//test))', '((test//test))', '((//test//test))'
            ]

            invalid_placeholders_names.each do |invalid_entity|
              expect {
                ConfigServerHelper.extract_variable_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Variable name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' must not contain two consecutive forward slashes"
                   )
            end
          end
        end

        context 'when name has an exclamation mark other than at the start of the name (for spiff)' do
          it 'should raise a ConfigServerIncorrectNameSyntax error' do
            invalid_placeholders_names = [
              '((!!/test))', '((!test/test!))', '((/!/test/!/test))', '((!!/test))', '((!))', '((/!))', '((!_!))'
            ]

            invalid_placeholders_names.each do |invalid_entity|
              expect {
                ConfigServerHelper.extract_variable_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Variable name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' contains invalid character '!'. If it is included for spiff, " +
                       'it should only be at the beginning of the name. Note: it will not be considered a part of the name'
                   )
            end
          end
        end

        context 'when name contains dots' do
          it 'should raise a ConfigServerIncorrectNameSyntax error when name contains dots before the last slash' do
            invalid_placeholders_names = [
              '((/hello.bye/test))', '((smurf/cat.happy/meow.loud))', '((./test))',
              '((././test.test))', '((smurf/cat.happy/cat.sad/meow.loud))'
            ]

            invalid_placeholders_names.each do |invalid_entity|
              expect {
                ConfigServerHelper.extract_variable_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Variable name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' syntax error: Must not contain dots before the last slash"
                   )
            end
          end

          it 'should raise a ConfigServerIncorrectNameSyntax error when a segment starts with a dot' do
            invalid_placeholders_names = [
              '((/.))', '((.))', '((/t/.))', '((/t/..))', '((/t/...))'
            ]

            invalid_placeholders_names.each do |invalid_entity|
              expect {
                ConfigServerHelper.extract_variable_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Variable name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' syntax error: Must not have segment starting with a dot"
                   )
            end
          end

          it 'should raise a ConfigServerIncorrectNameSyntax error when ending with a dot' do
            invalid_placeholders_names = [
              '((/hello/t.))', '((/hello/t..))', '((t.))', '((t..))'
            ]

            invalid_placeholders_names.each do |invalid_entity|
              expect {
                ConfigServerHelper.extract_variable_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Variable name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' syntax error: Must not end name with a dot"
                   )
            end
          end

          it 'should raise a ConfigServerIncorrectNameSyntax error when containing consecutive dots' do
            invalid_placeholders_names = [
              '((smurf/b..h))', '((smurf/b...h))', '((b..h))', '((b...h))'
            ]

            invalid_placeholders_names.each do |invalid_entity|
              expect {
                ConfigServerHelper.extract_variable_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Variable name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' syntax error: Must not contain consecutive dots"
                   )
            end
          end
        end
      end
    end

    describe '#add_prefix_if_not_absolute' do
      context 'when name is absolute' do
        it 'should return name as is' do
          input_name = '/dir/dep/name'
          expected_name = '/dir/dep/name'
          expect(ConfigServerHelper.add_prefix_if_not_absolute(input_name, 'dir2', 'dep2')).to eq(expected_name)
        end
      end

      context 'when name is not absolute' do
        context 'and both director and deployment is specified' do
          it 'should return name with director and deployment prefix' do
            input_name = 'name'
            director = 'dir'
            deployment = 'dep'

            expected_name = '/dir/dep/name'
            expect(ConfigServerHelper.add_prefix_if_not_absolute(input_name, director, deployment)).to eq(expected_name)
          end
        end
      end
    end

    describe '#validate_variable_name' do
      context 'when name does NOT meet specs' do
        context 'when name has invalid characters' do
          it 'should raise a ConfigServerIncorrectNameSyntax error' do
            invalid_variable_names = [
              '', ' ', '%', '  ', '123 345', '@bosh',
              'hello_)', 't*', 'smurf cat', 'smurf.cat',
              "valid\nvalid", # 151110778
            ]

            invalid_variable_names.each do |invalid_entity|
              expect {
                ConfigServerHelper.validate_variable_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Variable name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' must only contain alphanumeric, underscores, dashes, or forward slash characters"
                   )
            end
          end
        end

        context 'when name ends with a forward slash' do
          it 'should raise a ConfigServerIncorrectNameSyntax error' do
            invalid_placeholders_names = [
              '/', 'hello/', '//', '/test/', 'test//', 'test///'
            ]

            invalid_placeholders_names.each do |invalid_entity|
              expect {
                ConfigServerHelper.validate_variable_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Variable name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' must not end with a forward slash"
                   )
            end
          end
        end

        context 'when name has two consecutive forward slashes' do
          it 'should raise a ConfigServerIncorrectNameSyntax error' do
            invalid_placeholders_names = [
              '//test', 'test//test', '//test//test'
            ]

            invalid_placeholders_names.each do |invalid_entity|
              expect {
                ConfigServerHelper.validate_variable_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Variable name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' must not contain two consecutive forward slashes"
                   )
            end
          end
        end
      end
    end

    describe '#validate_absolute_names' do
      context 'when all placeholders are absolute' do
        it 'does NOT raise an error' do
          placeholder_names = ['/test', '/test/test', '/smurf']
          expect{ ConfigServerHelper.validate_absolute_names(placeholder_names) }.to_not raise_error
        end
      end

      context 'when any of the placeholders is NOT absolute' do
        placeholder_names = ['/test', 'test/test', 'smurf']

        it 'raises an error' do
          expect {
            ConfigServerHelper.validate_absolute_names(placeholder_names)
          }.to raise_error(Bosh::Director::ConfigServerIncorrectNameSyntax, "Relative paths are not allowed in this context. The following must be be switched to use absolute paths: 'test/test', 'smurf'")
        end
      end

    end
  end
end
