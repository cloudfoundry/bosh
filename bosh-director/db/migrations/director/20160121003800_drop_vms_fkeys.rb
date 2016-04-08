Sequel.migration do
  change do

    # newer versions of sequel support drop_foreign_key but the version breaks tests
    if [:mysql2, :mysql].include?(adapter_scheme)
      run('alter table vms drop FOREIGN KEY vms_ibfk_1')
    elsif [:postgres].include?(adapter_scheme)
      run('alter table vms drop constraint vms_deployment_id_fkey')
    end

  end
end
