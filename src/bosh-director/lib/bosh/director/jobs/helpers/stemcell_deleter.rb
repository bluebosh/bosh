module Bosh::Director::Jobs
  module Helpers
    class StemcellDeleter
      include Bosh::Director::LockHelper
      def initialize(logger)
        @logger = logger
      end

      def delete(stemcell, options = {})
        with_stemcell_lock(stemcell.name, stemcell.version) do
          @logger.info('Checking for any deployments still using the stemcell')
          deployments = stemcell.deployments
          unless deployments.empty?
            names = deployments.map(&:name).join(', ')
            raise Bosh::Director::StemcellInUse,
                  "Stemcell '#{stemcell.name}/#{stemcell.version}' is still in use by: #{names}"
          end

          begin
            cloud_for_stemcell(stemcell).delete_stemcell(stemcell.cid)
          rescue => e
            raise unless options['force']
            @logger.warn(e.backtrace.join("\n"))
            @logger.info("Force deleting is set, ignoring exception: #{e.message}")
          end

          stemcell.destroy
        end
      end

      private

      def cloud_for_stemcell(stemcell)
        cloud = Bosh::Director::CloudFactory.create.get(stemcell.cpi)
        raise "Stemcell has CPI defined (#{stemcell.cpi}) that is not configured anymore." if cloud.nil?
        cloud
      end
    end
  end
end
