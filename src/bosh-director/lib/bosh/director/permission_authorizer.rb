module Bosh::Director
  class PermissionAuthorizer
    def initialize(uuid_provider)
      @uuid_provider = uuid_provider
    end

    def granted_or_raise(subject, permission, user_scopes)
      if !is_granted?(subject, permission, user_scopes)
        raise UnauthorizedToAccessDeployment, "Require one of the scopes: #{list_expected_scope(subject, permission, user_scopes).join(', ')}"
      end
    end

    def is_granted?(subject, permission, user_scopes)
      !intersect(user_scopes, list_expected_scope(subject, permission, user_scopes)).empty?
    end

    def list_expected_scope(subject, permission, user_scopes)
      expected_scope = director_permissions[:admin]

      case subject
        when :director
          get_director_scopes(expected_scope, permission, user_scopes)
        when lambda { |s| s.instance_of?(Models::Task) }
          expected_scope << subject_team_scopes(subject, 'admin')

          case permission
            when :admin
              # already allowed with initial expected_scope
            when :read
              expected_scope << subject_team_scopes(subject, 'read')
              expected_scope << director_permissions[:read]
            else
              raise ArgumentError, "Unexpected permission for task: #{permission}"
          end
        when lambda { |s| s.instance_of?(Models::Deployment) }
          expected_scope << subject_team_scopes(subject, 'admin')

          case permission
            when :admin
              # already allowed with initial expected_scope
            when :read
              expected_scope << subject_team_scopes(subject, 'read')
              expected_scope << director_permissions[:read]
            else
              raise ArgumentError, "Unexpected permission for deployment: #{permission}"
          end
        else
          raise ArgumentError, "Unexpected subject: #{subject}"
      end

      expected_scope.flatten.uniq
    end

    private

    def get_director_scopes(expected_scope, permission, user_scopes)
      case permission
        when :admin
          # already allowed with initial expected_scope
        when :create_deployment
          expected_scope << add_bosh_admin_scopes(user_scopes)
        when :read_events
          expected_scope << director_permissions[:read]
          expected_scope << add_bosh_team_scopes(user_scopes)
        when :read_releases, :list_deployments, :read_stemcells, :list_tasks
          expected_scope << director_permissions[:read]
          expected_scope << add_bosh_admin_scopes(user_scopes)
        when :read, :upload_releases, :upload_stemcells
          expected_scope << director_permissions[permission]
        else
          raise ArgumentError, "Unexpected permission for director: #{permission}"
      end
    end

    def add_bosh_admin_scopes(user_scopes)
      user_scopes.select do |scope|
        scope.match(/\Abosh\.teams\.([^.]*)\.admin\z/)
      end
    end

    def add_bosh_team_scopes(user_scopes)
      user_scopes.select do |scope|
        scope.match(/\Abosh\.teams\.([^.])*\.(admin|read)\z/)
      end
    end

    def director_permissions
      {
        read: ['bosh.read', "bosh.#{@uuid_provider.uuid}.read"],
        admin: ['bosh.admin', "bosh.#{@uuid_provider.uuid}.admin"],
        upload_stemcells: ['bosh.stemcells.upload'],
        upload_releases: ['bosh.releases.upload'],
      }
    end

    def subject_team_scopes(subject, permission)
      teams = subject.teams.nil? ? [] : subject.teams
      teams.map { |team| "bosh.teams.#{team.name}.#{permission}" }
    end

    def intersect(valid_scopes, token_scopes)
      valid_scopes & token_scopes
    end
  end
end
