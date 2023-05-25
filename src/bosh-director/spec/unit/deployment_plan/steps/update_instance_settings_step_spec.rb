require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe UpdateInstanceSettingsStep do
        subject(:step) { UpdateInstanceSettingsStep.new(instance) }

        let(:instance_model) { Models::Instance.make(cloud_properties: '{}') }
        let(:cloud_props) do
          { 'prop1' => 'value1' }
        end
        let(:agent_client) { instance_double(AgentClient, update_settings: nil) }
        let(:instance) { instance_double(Instance, model: instance_model, cloud_properties: cloud_props, update_instance_settings: nil) }
        let(:trusted_certs) { 'fake-cert' }
        let(:old_trusted_certs_sha1) { 'old-fake-cert' }
        let!(:vm) do
          Models::Vm.make(
            instance: instance_model,
            trusted_certs_sha1: old_trusted_certs_sha1,
            active: false,
            cpi: 'vm-cpi',
          )
        end
        let(:report) { Stages::Report.new.tap { |r| r.vm = vm } }

        describe '#perform' do
          before do
            allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
            allow(Config).to receive(:trusted_certs).and_return(trusted_certs)
          end

          it 'should update the instance settings with the proper VM' do
            step.perform(report)
            expect(instance).to have_received(:update_instance_settings).with(vm)
          end

          it 'should update any cloud_properties provided' do
            expect { step.perform(report) }.to change {
              instance_model.cloud_properties
            }.from('{}').to(JSON.dump(cloud_props))
          end
        end
      end
    end
  end
end
