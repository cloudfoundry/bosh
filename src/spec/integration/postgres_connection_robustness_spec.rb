require 'spec_helper'

describe 'recovering from postgres connection failures', type: :integration, db: :postgresql do
  with_reset_sandbox_before_each

  it 'can start a task after the postgres connections are cut and reconnected' do

    target_and_login

    current_sandbox.database_proxy.stop
    current_sandbox.database_proxy.start

    upload_stemcell

  end

  it 'can start a task before and after the postgres connections are cut and reconnected' do

    target_and_login

    upload_stemcell

    current_sandbox.database_proxy.stop
    current_sandbox.database_proxy.start

    delete_stemcell

  end

end
