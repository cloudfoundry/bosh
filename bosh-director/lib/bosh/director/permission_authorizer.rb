module Bosh::Director
  class PermissionAuthorizer
    def initialize
      @director_uuid ||= Bosh::Director::Models::DirectorAttribute.uuid
    end

    def has_admin_scope?(token_scopes)
      !(intersect(permissions[:write], token_scopes).empty?)
    end

    def has_admin_or_director_read_scope?(token_scopes)
      !(intersect(permissions[:read], token_scopes).empty?)
    end

    def has_team_admin_scope?(token_scopes)
      token_scopes.any? do |e|
        /bosh.teams.[^\.]+.admin/ =~ e
      end
    end

    def contains_requested_scope?(valid_scopes, token_scopes)
      return false unless valid_scopes
      !(intersect(valid_scopes, token_scopes).empty?)
    end

    def permissions
      {
        :read  => ['bosh.admin', "bosh.#{@director_uuid}.admin", 'bosh.read', "bosh.#{@director_uuid}.read"],
        :write => ['bosh.admin', "bosh.#{@director_uuid}.admin"]
      }
    end

    def is_authorized?(provided_scopes, token_scopes)
      return true if has_admin_or_director_read_scope?(token_scopes)

      return contains_requested_scope?(provided_scopes, token_scopes)
    end

    def raise_error_if_unauthorized(provided_scopes, deployment_scopes)
      return if has_admin_scope?(provided_scopes)

      if (deployment_scopes & provided_scopes).empty?
        raise Bosh::Director::UnauthorizedToAccessDeployment,
          'You are unauthorized to view this deployment. Please contact the BOSH admin.'
      end
    end

    private

    def intersect(valid_scopes, token_scopes)
      valid_scopes & token_scopes
    end
  end
end
