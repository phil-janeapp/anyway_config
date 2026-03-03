# frozen_string_literal: true

require "spec_helper"

describe Anyway::Loaders::OnePassword do
  include Anyway::Testing::Helpers

  subject { described_class.call(**options) }

  let(:options) { {env_prefix: "MYAPP"} }
  let(:environment_id) { "abc123environment" }
  let(:op_response) do
    [
      {"name" => "MYAPP_HOST", "value" => "prod.example.com"},
      {"name" => "MYAPP_PORT", "value" => "443"},
      {"name" => "OTHER_KEY", "value" => "ignored"}
    ]
  end
  let(:expected_config) { {"host" => "prod.example.com", "port" => "443"} }

  before { allow(described_class).to receive(:environment_id).and_return(environment_id) }

  context "when loading succeeds" do
    before do
      allow(Open3).to receive(:capture3)
        .with("op", "environment", "read", environment_id, "--format", "json")
        .and_return([op_response.to_json, "", instance_double(Process::Status, success?: true)])
    end

    it "returns config filtered by env_prefix" do
      expect(subject).to eq(expected_config)
    end
  end

  context "when environment_id is set via class attribute" do
    before do
      allow(described_class).to receive(:environment_id).and_call_original
      described_class.environment_id = environment_id
      allow(Open3).to receive(:capture3).and_return([op_response.to_json, "", instance_double(Process::Status, success?: true)])
    end

    after { described_class.environment_id = nil }

    it "uses the class-level environment ID" do
      expect(subject).to eq(expected_config)
    end
  end

  context "when OP_ENVIRONMENT_ID is missing" do
    before { allow(described_class).to receive(:environment_id).and_return(nil) }

    it "raises ArgumentError" do
      expect { subject }.to raise_error(ArgumentError, /1Password environment ID is required/)
    end
  end

  context "when op CLI returns an error" do
    before do
      allow(Open3).to receive(:capture3)
        .with("op", "environment", "read", environment_id, "--format", "json")
        .and_return(["", "[ERROR] unauthorized", instance_double(Process::Status, success?: false)])
    end

    it "raises RequestError" do
      expect { subject }.to raise_error(Anyway::Loaders::OnePassword::RequestError, "[ERROR] unauthorized")
    end
  end

  context "when op CLI fails with empty stderr" do
    before do
      allow(Open3).to receive(:capture3)
        .with("op", "environment", "read", environment_id, "--format", "json")
        .and_return(["", "", instance_double(Process::Status, success?: false)])
    end

    it "raises RequestError with an empty message" do
      expect { subject }.to raise_error(Anyway::Loaders::OnePassword::RequestError, "")
    end
  end

  context "when the op binary is not found" do
    before do
      allow(Open3).to receive(:capture3)
        .with("op", "environment", "read", environment_id, "--format", "json")
        .and_raise(Errno::ENOENT, "No such file or directory - op")
    end

    it "raises Errno::ENOENT" do
      expect { subject }.to raise_error(Errno::ENOENT, /op/)
    end
  end

  context "when the op binary is not executable" do
    before do
      allow(Open3).to receive(:capture3)
        .with("op", "environment", "read", environment_id, "--format", "json")
        .and_raise(Errno::EACCES, "Permission denied - op")
    end

    it "raises Errno::EACCES" do
      expect { subject }.to raise_error(Errno::EACCES, /op/)
    end
  end

  context "when op exits successfully but returns malformed JSON" do
    before do
      allow(Open3).to receive(:capture3)
        .with("op", "environment", "read", environment_id, "--format", "json")
        .and_return(["not valid json {{{", "", instance_double(Process::Status, success?: true)])
    end

    it "raises JSON::ParserError" do
      expect { subject }.to raise_error(JSON::ParserError)
    end
  end

  context "when op exits successfully but returns an unexpected JSON type" do
    before do
      allow(Open3).to receive(:capture3)
        .with("op", "environment", "read", environment_id, "--format", "json")
        .and_return(["42", "", instance_double(Process::Status, success?: true)])
    end

    it "returns an empty config" do
      expect(subject).to eq({})
    end
  end

  context "when onepassword_environment_id is passed as a loader option" do
    let(:override_id) { "override-env-id" }
    let(:options) { {env_prefix: "MYAPP", onepassword_environment_id: override_id} }

    before do
      allow(Open3).to receive(:capture3)
        .with("op", "environment", "read", override_id, "--format", "json")
        .and_return([op_response.to_json, "", instance_double(Process::Status, success?: true)])
    end

    it "uses the loader option environment ID over the class default" do
      expect(subject).to eq(expected_config)
    end
  end

  describe ".configured" do
    let(:configured_loader) { described_class.configured(environment_id) }

    before do
      allow(Open3).to receive(:capture3)
        .with("op", "environment", "read", environment_id, "--format", "json")
        .and_return([op_response.to_json, "", instance_double(Process::Status, success?: true)])
    end

    it "returns a callable that uses the given environment ID" do
      expect(configured_loader.call(env_prefix: "MYAPP")).to eq(expected_config)
    end
  end
end
