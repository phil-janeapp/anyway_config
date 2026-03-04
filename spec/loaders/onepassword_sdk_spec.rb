# frozen_string_literal: true

require "spec_helper"
require "onepassword_sdk"

describe Anyway::Loaders::OnePasswordSDK do
  include Anyway::Testing::Helpers

  subject { described_class.call(**options) }

  let(:options) { {env_prefix: "MYAPP"} }
  let(:environment_id) { "abc123environment" }
  let(:service_account_token) { "ops_test_token" }

  let(:variables) do
    [
      instance_double(OnePasswordSDK::Models::EnvironmentVariable,
        name: "MYAPP_HOST", value: "prod.example.com"),
      instance_double(OnePasswordSDK::Models::EnvironmentVariable,
        name: "MYAPP_PORT", value: "443"),
      instance_double(OnePasswordSDK::Models::EnvironmentVariable,
        name: "OTHER_KEY", value: "ignored")
    ]
  end
  let(:expected_config) { {"host" => "prod.example.com", "port" => "443"} }

  let(:mock_environments) { instance_double(OnePasswordSDK::APIs::EnvironmentsAPI) }
  let(:mock_client) do
    instance_double(OnePasswordSDK::Client, environments: mock_environments, close: nil)
  end

  before do
    allow(described_class).to receive(:environment_id).and_return(environment_id)
    allow(described_class).to receive(:service_account_token).and_return(service_account_token)
    allow_any_instance_of(described_class).to receive(:build_client).and_return(mock_client)
    allow(mock_environments).to receive(:get_variables).with(environment_id).and_return(variables)
  end

  context "when loading succeeds" do
    it "returns config filtered by env_prefix" do
      expect(subject).to eq(expected_config)
    end

    it "closes the client after loading" do
      subject
      expect(mock_client).to have_received(:close)
    end
  end

  context "when environment_id is missing" do
    before { allow(described_class).to receive(:environment_id).and_return(nil) }

    it "raises ArgumentError" do
      expect { subject }.to raise_error(ArgumentError, /environment ID is required/)
    end
  end

  context "when service_account_token is missing" do
    before { allow(described_class).to receive(:service_account_token).and_return(nil) }

    it "raises ArgumentError" do
      expect { subject }.to raise_error(ArgumentError, /service account token is required/)
    end
  end

  context "when the SDK raises an error" do
    before do
      allow(mock_environments).to receive(:get_variables)
        .and_raise(OnePasswordSDK::UnauthorizedError, "invalid token")
    end

    it "propagates the SDK error" do
      expect { subject }.to raise_error(OnePasswordSDK::UnauthorizedError, "invalid token")
    end

    it "still closes the client" do
      expect { subject }.to raise_error(OnePasswordSDK::UnauthorizedError)
      expect(mock_client).to have_received(:close)
    end
  end

  context "when onepassword_environment_id is passed as a loader option" do
    let(:override_id) { "override-env-id" }
    let(:options) { {env_prefix: "MYAPP", onepassword_environment_id: override_id} }

    before do
      allow(mock_environments).to receive(:get_variables).with(override_id).and_return(variables)
    end

    it "uses the loader option environment ID over the class default" do
      expect(subject).to eq(expected_config)
    end
  end

  describe ".configured" do
    let(:configured_loader) { described_class.configured(environment_id) }

    it "returns a callable that uses the given environment ID" do
      expect(configured_loader.call(env_prefix: "MYAPP")).to eq(expected_config)
    end
  end
end
