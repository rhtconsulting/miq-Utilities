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
        @handle.log(level, "#{msg}")
        @handle.task.message = msg if @task && (update_message || level == 'error')
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

      ##
      # Builds the RBAC array for further checking
      def get_current_group_rbac_array
        raise 'get_current_group_rbac_array requires @user to be set' if @user.nil
        @rbac_array = []

        unless @user.current_group.filters.blank?
          @user.current_group.filters['managed'].flatten.each do |filter|
            next unless /(?<category>\w*)\/(?<tag>\w*)$/i =~ filter
            @rbac_array << {category => tag}
          end
        end
        log(:info, "@user: #{@user.userid} RBAC filters: #{@rbac_array}") if @debug
        @rbac_array
      end

      ##
      # Checks to see if the current user has access to the requested category/tag
      # Params:
      # :category: string category name
      # :tag: string tag name
      def has_access_to_tag?(category, tag)
        log(:info, "Searching for access to [#{category}]/[#{tag}]") if @debug
        get_current_group_rbac_array if @rbac_array.nil?
        @rbac_array.each do |rbac_hash|
          #each array element only has a single hash cat=>value. So this loops only once.
          rbac_hash.each do |rbac_category, rbac_tags|
            return true if category == rbac_category && tag == rbac_tags
          end
        end
        false
      end

      # using the rbac filters check to ensure that templates, clusters, security_groups, etc... are tagged
      def object_eligible?(obj)
        log(:info, "@user: #{@user.userid} RBAC filters: #{@rbac_array}")
        log(:info, "obj: [#{obj}, obj tags: [#{obj.tags}]")
        @rbac_array.each do |rbac_hash|
          log(:info, "\trh: [#{rbac_hash}]")
          rbac_hash.each do |rbac_category, rbac_tags|
            log(:info, "\t\tc: [#{rbac_category}], t: [#{rbac_tags}]")
            Array.wrap(rbac_tags).each {|rbac_tag_entry| return false unless obj.tagged_with?(rbac_category, rbac_tag_entry)}
          end
          true
        end
      end

    end
  end
end
