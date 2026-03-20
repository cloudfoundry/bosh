module Bosh::Director
  class PermissionAuthorizer
    def initialize(uuid_provider)
      @uuid_provider = uuid_provider
    end

    def granted_or_raise(subject, permission, user_scopes)
      return if is_granted?(subject, permission, user_scopes)

      formatted = list_expected_scope(subject, permission, user_scopes).map do |predicate|
        predicate.length > 1 ? "(#{predicate.join(' AND ')})" : predicate.first
      end

      raise(
        UnauthorizedToAccessDeployment,
        "Require one of the scopes: #{formatted.join(', ')}",
      )
    end

    def is_granted?(subject, permission, user_scopes)
      list_expected_scope(subject, permission, user_scopes).any? do |predicate|
        (predicate - user_scopes).empty?
      end
    end

    def list_expected_scope(subject, permission, user_scopes)
      expected_scope = director_permissions[:admin].dup

      case subject
      when :director
        get_director_scopes(expected_scope, permission, user_scopes)
      when ->(s) { s.instance_of?(Models::Task) }
        expected_scope.concat(subject_teams_scopes(subject, 'admin'))

        case permission
        when :admin
          # already allowed with initial expected_scope
          expected_scope
        when :read
          expected_scope.concat(subject_teams_scopes(subject, 'read'))
          expected_scope.concat(director_permissions[:read])
        else
          raise ArgumentError, "Unexpected permission for task: #{permission}"
        end
      when ->(s) { s.instance_of?(Models::Deployment) }
        expected_scope.concat(subject_teams_scopes(subject, 'admin'))

        case permission
        when :admin
          # already allowed with initial expected_scope
          expected_scope
        when :read, :read_link
          expected_scope.concat(subject_teams_scopes(subject, 'read'))
          expected_scope.concat(director_permissions[:read])
        else
          raise ArgumentError, "Unexpected permission for deployment: #{permission}"
        end
      when ->(s) { s.instance_of?(Models::Config) }
        expected_scope.concat(subject_team_scopes(subject, 'admin'))

        case permission
        when :admin
          # already allowed with initial expected_scope
          expected_scope
        when :read
          expected_scope.concat(subject_team_scopes(subject, 'read'))
          expected_scope.concat(director_permissions[:read])
        else
          raise ArgumentError, "Unexpected permission for config: #{permission}"
        end

      else
        raise ArgumentError, "Unexpected subject: #{subject}"
      end

      expected_scope.uniq
    end

    private

    def get_director_scopes(expected_scope, permission, user_scopes)
      case permission
      when :admin
        # already allowed with initial expected_scope
        expected_scope
      when :create_deployment, :create_link, :delete_link
        expected_scope.concat(bosh_team_admin_scopes(user_scopes))
      when :read_events, :list_configs, :read_link
        expected_scope.concat(director_permissions[:read])
        expected_scope.concat(bosh_team_scopes(user_scopes))
      when :read_releases, :list_deployments, :read_stemcells, :list_tasks
        expected_scope.concat(director_permissions[:read])
        expected_scope.concat(bosh_team_admin_scopes(user_scopes))
      when :update_configs
        expected_scope.concat(bosh_team_admin_scopes(user_scopes))
      when :read, :upload_releases, :upload_stemcells,
           :create_dynamic_disks, :attach_dynamic_disks, :detach_dynamic_disks,
           :list_dynamic_disks, :delete_dynamic_disks, :provide_dynamic_disks
        expected_scope.concat(director_permissions[permission])
      else
        raise ArgumentError, "Unexpected permission for director: #{permission}"
      end
    end

    def bosh_team_admin_scopes(user_scopes)
      user_scopes.select { |scope| scope.match(/\Abosh\.teams\.([^.]*)\.admin\z/) }
                 .map { |scope| [scope] }
    end

    def bosh_team_scopes(user_scopes)
      user_scopes.select { |scope| scope.match(/\Abosh\.teams\.([^.])*\.(admin|read)\z/) }
                 .map { |scope| [scope] }
    end

    def director_permissions
      {
        read: [['bosh.read'], ["bosh.#{@uuid_provider.uuid}.read"]],
        admin: [['bosh.admin'], ["bosh.#{@uuid_provider.uuid}.admin"]],
        upload_stemcells: [['bosh.stemcells.upload']],
        upload_releases: [['bosh.releases.upload']],
        create_dynamic_disks: [['bosh.dynamic-disks.create']],
        delete_dynamic_disks: [['bosh.dynamic-disks.delete']],
        attach_dynamic_disks: [['bosh.dynamic-disks.attach']],
        detach_dynamic_disks: [['bosh.dynamic-disks.detach']],
        provide_dynamic_disks: [['bosh.dynamic-disks.create', 'bosh.dynamic-disks.attach']],
        list_dynamic_disks: [['bosh.dynamic-disks.list']],
      }
    end

    def subject_team_scopes(subject, permission)
      map_teams_scopes(subject.team.nil? ? [] : [subject.team], permission)
    end

    def subject_teams_scopes(subject, permission)
      map_teams_scopes(subject.teams.nil? ? [] : subject.teams, permission)
    end

    def map_teams_scopes(teams, permission)
      teams.map { |team| ["bosh.teams.#{team.name}.#{permission}"] }
    end
  end
end
