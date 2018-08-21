#
# Description: Core.class StdLib
#
module RedHatConsulting_Utilities
  module StdLib
    module Core

      def initialize(handle = $evm)
        @handle = handle
        @task = get_stp_task
      end

      def log(level, msg, update_message = false)
        @handle.log(level, "#{msg}")
        @task.message = msg if @task && (update_message || level == 'error')
      end

      def dump_thing(thing)
        thing.attributes.sort.each { |k, v|
          log(:info, "\t Attribute: #{k} = #{v}")
        }
      end

      def dump_root()
        log(:info, "Begin @handle.root.attributes")
        dump_thing(@handle.root)
        log(:info, "End @handle.root.attributes")
        log(:info, "")
      end

      def get_provider(provider_id = nil)
        unless provider_id.nil?
          $evm.root.attributes.detect { |k, v| provider_id = v if k.end_with?('provider_id') } rescue nil
        end
        provider = $evm.vmdb(:ManageIQ_Providers_Amazon_CloudManager).find_by_id(provider_id)
        log(:info, "Found provider: #{provider.name} via provider_id: #{provider.id}") if provider

        # set to true to default to the fist amazon provider
        use_default = true
        unless provider
          # default the provider to first openstack provider
          provider = $evm.vmdb(:ManageIQ_Providers_Amazon_CloudManager).first if use_default
          log(:info, "Found amazon: #{provider.name} via default method") if provider && use_default
        end
        provider ? (return provider) : (return nil)
      end

      def get_stp_task
        task = @handle.root['service_template_provision_task']
        raise 'service_template_provision_task not found' unless task
        task
      end

      def get_request
        miq_request = @handle.vmdb(:miq_request).find_by_id(get_stp_task.miq_request_id)
        raise 'miq_request not found' unless miq_request
        miq_request
      end

      def get_service
        service = get_stp_task.destination
        raise 'service not found' unless service
        service
      end

      # Useful for Ansible Service Provisioning.
      def get_extra_vars
        extra_vars = get_service.job_options[:extra_vars]
        log(:info, "extra_vars: #{extra_vars.inspect}")
        extra_vars
      end

      def set_extra_vars(extra_vars)
        service = get_service

        # Remove any keys with blank values from extra_vars.
        extra_vars.delete_if { |k, v| v == '' }

        # Save updated job_options to service.
        job_options = service.job_options
        job_options[:extra_vars] = extra_vars
        service.job_options = job_options
        log(:info, "extra_vars updated: #{service.job_options[:extra_vars].inspect}")
      end

    end
  end
end
