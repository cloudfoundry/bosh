require 'spec_helper'

module Bosh::Director::ConfigServer
  describe ConfigServerHelper do
    before do
      @helper = Object.new
      @helper.extend(ConfigServerHelper)
    end

    describe '#is_placeholder?' do
      it 'should return true if value is placeholder' do
        placeholders = [
          '((smurf))', '((((smurf))))', '((!smurf))', '(())', '(( ))',
          '((  ))', '(( smurf))', '((/smurf))', '((/smurf))', '((/smurf))',
          '((/))', '((vroom vroo/m))'
        ]

        placeholders.each do |placeholder|
          expect(@helper.is_placeholder?(placeholder)).to be_truthy
        end
      end

      it 'should return false if value is not a placeholder' do
        not_placeholders = [
          '((smurf', '(!smurf))', 'smurf))', '((smurf', '(( smurf)',
          '(()', '((', '()'
        ]

        not_placeholders.each do |not_placeholder|
          expect(@helper.is_placeholder?(not_placeholder)).to be_falsey
        end
      end
    end

    describe '#extract_placeholder_name' do
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
            expect(@helper.extract_placeholder_name(k)).to eq(v)
          end
        end

        it 'should handle names starting with bang' do
          names = {
            '((!/smurf/gar_gamel))' => '/smurf/gar_gamel',
            '((!smurf))' => 'smurf',
            '((!smurf/cat))' => 'smurf/cat',
          }

          names.each do |k, v|
            expect(@helper.extract_placeholder_name(k)).to eq(v)
          end
        end
      end

      context 'when name does NOT meet specs' do
        context 'when name has invalid characters' do
          it 'should raise a ConfigServerIncorrectNameSyntax error' do
            invalid_placeholders_names = [
              '(())', '(( ))', '((%))', '((  ))', '((123 345))', '((@bosh))',
              '((hello_)))', '((t*))', '(()))', '((())))', '((smurf cat))'
            ]

            invalid_placeholders_names.each do |invalid_entity|
              expect {
                @helper.extract_placeholder_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Placeholder name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' must only contain alphanumeric, underscores, dashes, or forward slash characters"
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
                @helper.extract_placeholder_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Placeholder name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' must not end with a forward slash"
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
                @helper.extract_placeholder_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Placeholder name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' must not contain two consecutive forward slashes"
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
                @helper.extract_placeholder_name(invalid_entity)
              }.to raise_error(
                     Bosh::Director::ConfigServerIncorrectNameSyntax,
                     "Placeholder name '#{invalid_entity.gsub(/(^\(\(|\)\)$)/, '')}' contains invalid character '!'. If it is included for spiff, " +
                       'it should only be at the beginning of the name. Note: it will not be considered a part of the name'
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
          expect(@helper.add_prefix_if_not_absolute(input_name, 'dir2', 'dep2')).to eq(expected_name)
        end
      end

      context 'when name is not absolute' do
        context 'and both director and deployment is specified' do
          it 'should return name with director and deployment prefix' do
            input_name = 'name'
            director = 'dir'
            deployment = 'dep'

            expected_name = '/dir/dep/name'
            expect(@helper.add_prefix_if_not_absolute(input_name, director, deployment)).to eq(expected_name)
          end
        end
      end
    end
  end
end
