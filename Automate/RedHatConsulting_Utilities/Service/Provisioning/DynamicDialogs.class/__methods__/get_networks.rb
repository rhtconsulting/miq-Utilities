# Determine the destination networks for a specific selected destination provider.
#
# @param dialog_templates           String YAML list of selected destination templates including destination provider specified by :provider element
# @param destination_provider_index Int    Index in the destination templates list for the provider this dialog is for
# @param network_purpose            String Network purpose
#
@DEBUG = false

TEMPLATES_DIALOG_OPTION = 'dialog_templates'.freeze

require 'yaml'

def dump_object(object_string, object)
  $evm.log("info", "Listing #{object_string} Attributes:") 
  object.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

def dump_current
  $evm.log("info", "Listing Current Object Attributes:") 
  $evm.current.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

def dump_root
  $evm.log("info", "Listing Root Object Attributes:") 
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

# Log an error and exit.
#
# @param msg Message to error with
def error(msg)
  $evm.log(:error, msg)
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg.to_s
  exit MIQ_STOP
end

# There are many ways to attempt to pass parameters in Automate.
# This function checks all of them in priorty order as well as checking for symbol or string.
#
# Order:
#   1. Inputs
#   2. Current
#   3. Object
#   4. Root
#   5. State
#
# @return Value for the given parameter or nil if none is found
def get_param(param)  
  # check if inputs has been set for given param
  param_value ||= $evm.inputs[param.to_sym]
  param_value ||= $evm.inputs[param.to_s]
  
  # else check if current has been set for given param
  param_value ||= $evm.current[param.to_sym]
  param_value ||= $evm.current[param.to_s]
 
  # else cehck if current has been set for given param
  param_value ||= $evm.object[param.to_sym]
  param_value ||= $evm.object[param.to_s]
  
  # else check if param on root has been set for given param
  param_value ||= $evm.root[param.to_sym]
  param_value ||= $evm.root[param.to_s]
  
  # check if state has been set for given param
  param_value ||= $evm.get_state_var(param.to_sym)
  param_value ||= $evm.get_state_var(param.to_s)

  $evm.log(:info, "{ '#{param}' => '#{param_value}' }") if @DEBUG
  return param_value
end

# Get the network configuration for a given network
#
# @param network_name Name of the network to get the configuraiton for
# @return Hash Configuration information about the given network
#                network_purpose
#                network_address_space
#                network_gateway
#                network_nameservers
#                network_ddi_provider
@network_configurations         = {}
@missing_network_configurations = {}
NETWORK_CONFIGURATION_URI       = 'Infrastructure/Network/Configuration'.freeze
def get_network_configuration(network_name)
  if @network_configurations[network_name].blank? && @missing_network_configurations[network_name].blank?
    begin
      @network_configurations[network_name] = $evm.instantiate("#{NETWORK_CONFIGURATION_URI}/#{network_name}")
    rescue => e
      @missing_network_configurations[network_name] = "WARN: No network configuration exists"
      $evm.log(:warn, "No network configuration for Network <#{network_name}> exists")
    end
  end
  return @network_configurations[network_name]
end

begin
  dump_root()    if @DEBUG
  dump_current() if @DEBUG
  
  # If there isn't a vmdb_object_type yet just exit. The method will be recalled with an vmdb_object_type
  visible_and_required = !$evm.root['vmdb_object_type'].blank?
  $evm.log(:info, "$evm.root['vmdb_object_type'] => #{$evm.root['vmdb_object_type']}") if @DEBUG
  
  # If there are not any selected destination templates then hide dialog element
  destination_templates_yaml = get_param(TEMPLATES_DIALOG_OPTION)
  visible_and_required &= destination_templates_yaml =~ /^---/
  $evm.log(:info, "destination_templates_yaml => #{destination_templates_yaml}") if @DEBUG
  
  # get parameters
  if visible_and_required
    destination_templates      = YAML.load(destination_templates_yaml)
    destination_provider_index = get_param(:destination_provider_index)
    network_purpose            = get_param(:network_purpose)
    
    $evm.log(:info, "destination_templates      => #{destination_templates}")      if @DEBUG
    $evm.log(:info, "destination_provider_index => #{destination_provider_index}") if @DEBUG
    $evm.log(:info, "network_purpose            => #{network_purpose}")            if @DEBUG
    
    # ensure there are more destination templates/providers then this destination network dialog is for
    visible_and_required &= destination_templates.length > destination_provider_index
  end
  
  # determine the destination networks shared by all hosts on the selected destination provider
  all_host_destination_networks = []
  destination_provider_name     = nil
  if visible_and_required
    destination_provider_name = destination_templates[destination_provider_index][:provider]
    destination_provider      = $evm.vmdb(:ems).find_by_name(destination_provider_name)
    
    $evm.log(:info, "destination_provider_name => #{destination_provider_name}") if @DEBUG
    $evm.log(:info, "destination_provider      => #{destination_provider}")      if @DEBUG

    destination_provider.hosts.each do |host|
      # find all the host destination networks
      host_destination_lans = []
      host.lans.each do |lan|
        network_configuraiton = get_network_configuration(lan.name)
        $evm.log(:info, "network_configuraiton['network_purpose'] => #{network_configuraiton.blank? ? nil : network_configuraiton['network_purpose']}") if @DEBUG
        host_destination_lans << lan if !network_configuraiton.blank? && (network_configuraiton['network_purpose'].include?(network_purpose))
      end

      all_host_destination_networks << host_destination_lans.collect { |lan| lan.name }
    end
    $evm.log(:info, "all_host_destination_networks => #{all_host_destination_networks}") if @DEBUG

    # `inject(:&) does an `&` opertion on all elements of the array, thus doing an intersection
    intersection_of_host_destination_lans = all_host_destination_networks.inject(:&)
    $evm.log(:info, "intersection_of_host_destination_lans => #{intersection_of_host_destination_lans}") if @DEBUG
  end
  
  # determine the selecatable networks shared by all hosts that are also have network configuration with a network address space
  selectable_networks = {}
  if visible_and_required
    intersection_of_host_destination_lans.each do |network_name|
      network               = $evm.vmdb(:lan).find_by_name(network_name)
      network_configuration = get_network_configuration(network.name)
      if !network_configuration['network_address_space'].blank?
        selectable_networks[network_name] = "#{network_configuration['network_address_space']} (#{network_name}) (#{destination_provider_name})"
      end
    end
    $evm.log(:info, "selectable_networks => #{selectable_networks}") if @DEBUG
  end
  
  # if should be visible but can't find network configurations, show error
  # else prompt the user what this dialog element is for
  if visible_and_required && selectable_networks.empty?
    selectable_networks[nil] = "ERROR: No Networks on Provider <#{destination_provider_name}> with configuration instances in <#{NETWORK_CONFIGURATION_URI}>."
  elsif visible_and_required && selectable_networks.length > 1
    selectable_networks[nil] = "--- Select <#{destination_provider_name}> Destination Network"
  end
  
  # create dialog element
  dialog_field = $evm.object
  dialog_field['data_type'] = "string"
  dialog_field['visible']   = visible_and_required
  dialog_field['required']  = visible_and_required
  dialog_field['values']    = selectable_networks
  $evm.log(:info, "dialog_field['values'] => #{dialog_field['values']}") if @DEBUG
end
