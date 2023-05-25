# frozen_string_literal: true

require 'rspec'
require 'yaml'
require 'json'
require 'bosh/template/evaluation_context'
require_relative './template_example_group'

describe 'nats.cfg.erb' do
  it_should_behave_like 'a rendered file' do
    let(:file_name) { '../jobs/nats/templates/nats.cfg.erb' }
    let(:properties) do
      {
        'properties' => {
          'nats' => {
            'listen_address' => '1.2.3.4',
            'port' => 4222,
            'enable_metrics_endpoint' => true,
            'ping_interval' => 7,
            'ping_max_outstanding' => 10,
            'auth_timeout' => 10,
            'tls' => {
              'timeout' => 10,
            },
            'max_payload_mb' => '1.5',
          }
        }
      }
    end
    let(:expected_content) do
      <<~HEREDOC
        net: 1.2.3.4
        port: 4222

        http: localhost:8222

        logtime: true

        log_file: /var/vcap/sys/log/nats/nats.log

        authorization {
          DIRECTOR_PERMISSIONS: {
            publish: [
              "agent.*",
              "hm.director.alert"
            ]
            subscribe: ["director.>"]
          }

          AGENT_PERMISSIONS: {
            publish: [
              "hm.agent.heartbeat._CLIENT_ID",
              "hm.agent.alert._CLIENT_ID",
              "hm.agent.shutdown._CLIENT_ID",
              "director.*._CLIENT_ID.*"
            ]
            subscribe: ["agent._CLIENT_ID"]
          }

          HM_PERMISSIONS: {
            publish: []
            subscribe: [
              "hm.agent.heartbeat.*",
              "hm.agent.alert.*",
              "hm.agent.shutdown.*",
              "hm.director.alert"
            ]
          }

          certificate_clients: [
            {client_name: director.bosh-internal, permissions: $DIRECTOR_PERMISSIONS},
            {client_name: agent.bosh-internal, permissions: $AGENT_PERMISSIONS},
            {client_name: hm.bosh-internal, permissions: $HM_PERMISSIONS},
          ]

          timeout: 10
        }

        tls {
          cert_file:  "/var/vcap/jobs/nats/config/nats_server_certificate.pem"
          key_file:   "/var/vcap/jobs/nats/config/nats_server_private_key"
          ca_file:    "/var/vcap/jobs/nats/config/nats_client_ca.pem"
          verify:     true
          timeout:    10
          enable_cert_authorization: true
        }

        ping_interval: 7
        ping_max: 10
        max_payload: 1572864
      HEREDOC
    end
  end
end

describe 'nats_client_ca.pem.erb' do
  it_should_behave_like 'a rendered file' do
    let(:file_name) { '../jobs/nats/templates/nats_client_ca.pem.erb' }
    let(:properties) do
      {
        'properties' => {
          'nats' => {
            'tls' => {
              'ca' => content
            }
          }
        }
      }
    end
  end
end

describe 'nats_server_certificate.pem.erb' do
  it_should_behave_like 'a rendered file' do
    let(:file_name) { '../jobs/nats/templates/nats_server_certificate.pem.erb' }
    let(:properties) do
      {
        'properties' => {
          'nats' => {
            'tls' => {
              'server' => {
                'certificate' => content
              }
            }
          }
        }
      }
    end
  end
end

describe 'nats_server_private_key.erb' do
  it_should_behave_like 'a rendered file' do
    let(:file_name) { '../jobs/nats/templates/nats_server_private_key.erb' }
    let(:properties) do
      {
        'properties' => {
          'nats' => {
            'tls' => {
              'server' => {
                'private_key' => content
              }
            }
          }
        }
      }
    end
  end
end
