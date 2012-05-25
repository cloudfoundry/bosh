# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class StemcellManager
      include ApiHelper
      include TaskHelper

      def create_stemcell(user, stemcell)
        random_name = "stemcell-#{UUIDTools::UUID.random_create}"
        stemcell_file = File.join(Dir::tmpdir, random_name)
        write_file(stemcell_file, stemcell)
        task = create_task(user, :update_stemcell, "create stemcell")
        Resque.enqueue(Jobs::UpdateStemcell, task.id, stemcell_file)
        task
      end

      def delete_stemcell(user, stemcell)
        task_name = "delete stemcell: #{stemcell.name}/#{stemcell.version}"
        task = create_task(user, :delete_stemcell, task_name)
        Resque.enqueue(Jobs::DeleteStemcell, task.id, stemcell.name,
                       stemcell.version)
        task
      end
    end
  end
end