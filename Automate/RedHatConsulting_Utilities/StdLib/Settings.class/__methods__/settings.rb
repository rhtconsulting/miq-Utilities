#  settings.rb

#  Author: Jeff Warnica <jwarnica@redhat.com> 2018-08-16
#
# Provides a common location for settings for RedHatConsulting_Utilities,
# and some defaults for the children project like rhc-miq-quickstart
#
# Settings are Global, Default, and by RegionID, with regional settings falling through to Default
#-------------------------------------------------------------------------------
#   Copyright 2018 Jeff Warnica <jwarnica@redhat.com>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#-------------------------------------------------------------------------------
module RedHatConsulting_Utilities
  module StdLib
    module Core
      class Settings
        SETTINGS = {
            global: {
                network_lookup_keys: %w(environment), #orderd list of CF tag names to use to lookup vlan names, _ separated
                groups_can_order_for: %w(EvmGroup-super_administrator), #list of groups whos memebers can order services on behalf of others
                vm_auto_start_suppress: true,
            },
            default: {
                # network/vlan/dvs names for the providers
                # these must exist, but can (likely will) change later in the process
                network_vmware: 'VM Network',
                network_redhat: '<Template>',

                retirement: 30.days.to_i,
                retirement_warn: 14.days.to_i
            },
            r901: {
                network_vmware: 'dvs_0810_INF_VMS_PRD_HFLEX',
                network_vmware_test: 'dvs_0820_Self_Prov_Test(10.43.181.x)',
                network_vmware_dev: 'dvs_0821_Self_Prov_Dev(10.43.182.x)',
            },
        }

        ##
        # Gets setting from our configuration hash above
        #
        # == Parameters:
        # region:
        #   A string which is a region number, or the symbol :global
        # key:
        #   The key to fetch from the selected region, or default if the key is not found in the region
        def get_setting(region, key)
          region = ('r' + region.to_s).to_sym unless region == :global
          raise(ArgumentError, "region [#{region}] does not exist in settings hash") unless SETTINGS.key?(region)
          return SETTINGS[region][key] if SETTINGS[region].key?(key)
          raise(ArgumentError, "key [#{key}] does not exist in region [#{region}] or defaults settings hash") unless SETTINGS[:default].key?(key)
          return SETTINGS[:default][key]
        end

      end
    end
  end
end

# settings = RedHatConsulting_Utilities::StdLib::Core::Settings.new()
# puts settings.get_setting(901, :network_rhv)
#
# x = settings.get_setting(901, :foo) rescue "no x"
# puts x
