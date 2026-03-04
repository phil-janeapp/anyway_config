# frozen_string_literal: true

require "onepassword_sdk"

module Anyway
  module Loaders
    class OnePasswordSDK < Base
      class << self
        attr_writer :environment_id

        def environment_id
          @environment_id || ENV["OP_ENVIRONMENT_ID"]
        end

        attr_writer :service_account_token

        def service_account_token
          @service_account_token || ENV["OP_SERVICE_ACCOUNT_TOKEN"]
        end

        def configured(environment_id)
          ->(**opts) { call(**opts, onepassword_environment_id: environment_id) }
        end
      end

      def call(env_prefix:, onepassword_environment_id: OnePasswordSDK.environment_id, **_options)
        env_payload = fetch_variables(onepassword_environment_id)

        env = ::Anyway::Env.new(type_cast: ::Anyway::NoCast, env_container: env_payload)

        env.fetch_with_trace(env_prefix).then do |(conf, trace)|
          Tracing.current_trace&.merge!(trace)
          conf
        end
      end

      private

      def fetch_variables(environment_id)
        raise ArgumentError, "1Password environment ID is required" if environment_id.nil?
        raise ArgumentError, "1Password service account token is required" if OnePasswordSDK.service_account_token.nil?

        client = build_client
        variables = client.environments.get_variables(environment_id)
        variables.each_with_object({}) { |v, h| h[v.name] = v.value }
      ensure
        client&.close
      end

      def build_client
        ::OnePasswordSDK::Client.new(
          service_account_token: OnePasswordSDK.service_account_token
        )
      end
    end
  end
end
