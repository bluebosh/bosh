require 'securerandom'

module Bosh::Director::Models
  class Instance < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment
    one_to_many :persistent_disks
    one_to_many :rendered_templates_archives
    one_to_many :ip_addresses
    one_to_many :vms
    many_to_many :templates
    many_to_one :variable_set, class: 'Bosh::Director::Models::VariableSet'
    many_to_many :links, :class => 'Bosh::Director::Models::Links::Link', :join_table => :instances_links

    def validate
      validates_presence [:deployment_id, :job, :index, :state]
      validates_unique [:deployment_id, :job, :index]
      validates_unique [:vms].sort.first
      validates_integer :index
      validates_includes %w(started stopped detached), :state
    end

    def managed_persistent_disk
      PersistentDisk.first(active: true, name: '', instance: self)
    end

    def active_persistent_disks
      disk_collection = Bosh::Director::DeploymentPlan::PersistentDiskCollection.new(Bosh::Director::Config.logger)
      self.persistent_disks.select { |disk| disk.active }.each do |disk|
        disk_collection.add_by_model(disk)
      end
      disk_collection
    end

    def active_persistent_disk_cids
      active_persistent_disks.collection.map(&:model).map(&:disk_cid).compact
    end

    # @todo[multi-disks] drop this method+calls since it's assuming a single persistent disk
    def managed_persistent_disk_cid
      disk = managed_persistent_disk
      return disk.disk_cid if disk
      nil
    end

    def latest_rendered_templates_archive
      rendered_templates_archives_dataset.order(:created_at).last
    end

    def stale_rendered_templates_archives
      stale_archives = rendered_templates_archives_dataset
      latest = latest_rendered_templates_archive
      latest ? stale_archives.exclude(id: latest.id) : stale_archives
    end

    def cloud_properties_hash
      if cloud_properties.nil?
        return {} if spec.nil? || spec['vm_type'].nil?
        spec['vm_type']['cloud_properties'] || {}
      else
        JSON.parse(cloud_properties)
      end
    end

    def cloud_properties_hash=(hash)
      self.cloud_properties = JSON.dump(hash)
    end

    def orphanable?
      return false if spec.nil? || spec['update'].nil?

      return false if ip_addresses.any? { |ip| ip.type == 'static' }

      strategy = spec['update']['vm_strategy']
      strategy == Bosh::Director::DeploymentPlan::UpdateConfig::VM_STRATEGY_CREATE_SWAP_DELETE
    end

    def dns_record_names
      return nil if dns_records.nil?

      JSON.parse(dns_records)
    end

    def dns_record_names=(list)
      self.dns_records = JSON.dump(list)
    end

    def name
      "#{self.job}/#{self.uuid}"
    end

    def to_s
      "#{self.job}/#{self.uuid} (#{self.index})"
    end

    def spec
      return nil if spec_json.nil?

      begin
        result = JSON.parse(spec_json)
      rescue JSON::ParserError
        return 'error'
      end

      result
    end

    def spec=(spec)
      if spec.nil?
        self.spec_json = nil
      else
        self.spec_json = JSON.generate(spec)
      end
    end

    def spec_p(property_path)
      current_prop = spec
      property_path.split('.').each do |prop|
        return nil if current_prop.nil? || !current_prop.is_a?(Hash)

        current_prop = current_prop[prop]
      end
      current_prop
    end

    def vm_env
      return {} if spec.nil?
      spec['env'] || {}
    end

    def active_vm
      Vm.first(instance_id: id, active: true)
    end

    def active_vm=(new_active_vm)
      old_active_vm = active_vm
      Bosh::Director::Config.db.transaction do
        old_active_vm&.update(active: false)
        new_active_vm&.update(active: true)
      end
    end

    def cpi
      active_vm&.cpi
    end

    def agent_id
      instance_active_vm = active_vm
      instance_active_vm.nil? ? nil : instance_active_vm.agent_id
    end

    def vm_cid
      instance_active_vm = active_vm
      instance_active_vm.nil? ? nil : instance_active_vm.cid
    end

    def vm_created_at
      instance_active_vm = active_vm
      instance_active_vm.nil? || instance_active_vm.created_at.nil? ? nil : instance_active_vm.created_at.utc.iso8601
    end

    def lifecycle
      spec_hash = spec
      spec_hash ? spec_hash['lifecycle'] : nil
    end

    def expects_vm?
      lifecycle == 'service' && ['started', 'stopped'].include?(self.state)
    end

    def has_important_vm?
      active_vm != nil && state != 'stopped' && !ignore
    end

    def most_recent_inactive_vm
      inactive_vms = self.vms.select{ |vm| vm.active == false }
      inactive_vms.sort!{ |a,b| b.id <=> a.id }

      inactive_vms.first
    end

    def trusted_certs_sha1
      instance_active_vm = active_vm
      instance_active_vm.nil? ? ::Digest::SHA1.hexdigest('') : instance_active_vm.trusted_certs_sha1
    end

    def blobstore_config_sha1
      active_vm&.blobstore_config_sha1
    end

    def nats_config_sha1
      active_vm&.nats_config_sha1
    end

    def stopped?
      state == 'stopped'
    end

    def detached?
      state == 'detached'
    end

    private

    def object_or_nil(value)
      if value == 'null' || value.nil?
        nil
      else
        JSON.parse(value)
      end
    end

    def json_encode(value)
      value.nil? ? 'null' : JSON.generate(value)
    end
  end

  Instance.plugin :association_dependencies
  Instance.add_association_dependencies :ip_addresses => :destroy
  Instance.add_association_dependencies :templates => :nullify
end
