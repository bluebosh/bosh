module Bosh::Director
  module DeploymentPlan
    module Stages
      class DownloadPackagesStage
        def initialize(base_job, deployment_plan)
          @base_job = base_job
          @logger = base_job.logger
          @deployment_plan = deployment_plan
          @event_log = Config.event_log
        end

        def perform
          create_swap_delete_instance_plans = @deployment_plan.instance_plans_with_create_swap_delete_and_needs_duplicate_vm
          instance_plans_missing_vms = @deployment_plan.instance_plans_with_missing_vms
          instance_plans_needing_packages = create_swap_delete_instance_plans + instance_plans_missing_vms

          total = instance_plans_needing_packages.length
          event_log_stage = Config.event_log.begin_stage('Downloading packages', total)

          ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
            instance_plans_needing_packages.each do |plan|
              instance_string = plan.instance.model.to_s

              pool.process do
                with_thread_name("download_package_for_instance(#{instance_string}/#{total})") do

                  event_log_stage.advance_and_track(instance_string) do
                    @logger.info("Downloading packages for instance #{instance_string}.")
                    Steps::PrepareInstanceStep.new(plan, use_active_vm: false).perform(Report.new)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
