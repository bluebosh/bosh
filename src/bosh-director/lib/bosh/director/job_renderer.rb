require 'bosh/director/core/templates/job_template_loader'
require 'bosh/director/core/templates/job_instance_renderer'
require 'bosh/director/core/templates/template_blob_cache'

module Bosh::Director
  class JobRenderer
    def self.render_job_instances_with_cache(logger, instance_plans, cache, dns_encoder, link_provider_intents)
      job_template_loader = Core::Templates::JobTemplateLoader.new(
        logger,
        cache,
        link_provider_intents,
        dns_encoder,
      )

      instance_plans.each do |instance_plan|
        render_job_instance(instance_plan, job_template_loader, logger)
      end
    end

    def self.render_job_instance(instance_plan, loader, logger)
      instance = instance_plan.instance

      if instance_plan.templates.empty?
        logger.debug("Skipping rendering templates for '#{instance}', no templates")
        return
      end

      logger.debug("Rendering templates for instance #{instance}")

      instance_renderer = Core::Templates::JobInstanceRenderer.new(instance_plan.templates, loader)
      rendered_job_instance = instance_renderer.render(get_templates_spec(instance_plan))

      instance_plan.rendered_templates = rendered_job_instance

      instance.configuration_hash = rendered_job_instance.configuration_hash
      instance.template_hashes    = rendered_job_instance.template_hashes
    end

    def self.get_templates_spec(instance_plan)
      instance_plan.spec.as_template_spec
    rescue StandardError => e
      header = "- Unable to render jobs for instance group '#{instance_plan.instance.instance_group_name}'. Errors are:"
      message = FormatterHelper.new.prepend_header_and_indent_body(
        header,
        e.message.strip,
        indent_by: 2,
      )
      raise message
    end
  end
end
