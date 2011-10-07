module Bosh::Director

  class PropertyManager

    attr_accessor :scope

    def create_property(name, value)
      property = @scope.build
      property.name = name
      property.value = value
      property.save

    rescue Sequel::ValidationFailed => e
      # TODO: this is consistent with UserManager but doesn't quite feel right
      if e.errors[[:name, @scope.foreign_key]].include?(:unique)
        raise @scope.already_exists(name)
      end

      invalid_property(e.errors)
    end

    def update_property(name, value)
      property = get_property(name)
      property.value = value
      property.save

    rescue Sequel::ValidationFailed => e
      invalid_property(e.errors)
    end

    def delete_property(name)
      get_property(name).destroy
    end

    def get_property(name)
      @scope.find(name)
    end

    def get_properties
      @scope.find_all
    end

    private

    def invalid_property(errors)
      raise PropertyInvalid.new(errors.full_messages.sort.join(", "))
    end
  end
end
