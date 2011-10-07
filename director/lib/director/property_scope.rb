module Bosh::Director

  class PropertyScope
    attr_reader :name

    def initialize(name)
      @name = name
    end
  end

  class DeploymentPropertyScope < PropertyScope
    def build
      property = Models::DeploymentProperty.new
      property.deployment = find_deployment
      property
    end

    def find(property_name)
      deployment = find_deployment
      property = Models::DeploymentProperty.find(:deployment_id => deployment.id, :name => property_name)
      property || raise(PropertyNotFound.new(property_name, "deployment", deployment.name))
    end

    def find_all
      Models::DeploymentProperty.filter(:deployment_id => find_deployment.id).all
    end

    def foreign_key
      :deployment_id
    end

    def already_exists(property_name)
      raise PropertyAlreadyExists.new(property_name, "deployment", @name)
    end

    private

    def find_deployment
      deployment = Models::Deployment.find(:name => @name)
      deployment || raise(DeploymentNotFound.new(@name))
    end
  end

  class ReleasePropertyScope < PropertyScope
    def build
      property = Models::ReleaseProperty.new
      property.release = find_release
      property
    end

    def find(property_name)
      release = find_release
      property = Models::ReleaseProperty.find(:release_id => release.id, :name => property_name)
      property || raise(PropertyNotFound.new(property_name, "release", release.name))
    end

    def find_all
      Models::ReleaseProperty.filter(:release_id => find_release.id).all
    end

    def foreign_key
      :release_id
    end

    def already_exists(property_name)
      raise PropertyAlreadyExists.new(property_name, "release", @name)
    end

    private

    def find_release
      release = Models::Release.find(:name => @name)
      release || raise(ReleaseNotFound.new(@name))
    end
  end

end
