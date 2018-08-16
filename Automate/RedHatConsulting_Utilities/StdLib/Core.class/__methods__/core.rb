#
# Description: Core.class StdLib
#
module RedHatConsulting_Utilities
  module StdLib
    module Core

      def initialize(handle = $evm)
        @handle = handle
      end

      def log(level, msg, update_message = false)
        @handle.log(level, msg.to_s)

        # quick return if we aren't updating GUI messages
        return if update_message || level == 'error'

        task = nil

        task = @task unless @task.nil?
        task = @handle.task if task.nil? && !@handle.task.nil?
        if task.nil?
          @handle.log(:debug, 'Unable to find task. Ignoring message update')
        else
          task.message = msg
        end
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

      def error(msg)
        @handle.log(:error, msg)
        @handle.root['ae_result'] = 'error'
        @handle.root['ae_reason'] = msg.to_s
        exit MIQ_STOP
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


      def set_complex_state_var(name, value)
        @handle.set_state_var(name.to_sym, JSON.generate(value))
      end

      def get_complex_state_var(name)
        JSON.parse(@handle.get_state_var(name.to_sym))
      end


    end
  end
end
