# frozen_string_literal: true

require "open3"
require "json"

module Anyway
  module Loaders
    class OnePassword < Base
      class RequestError < StandardError; end

      class << self
        attr_writer :environment_id

        def environment_id
          @environment_id || ENV["OP_ENVIRONMENT_ID"]
        end

        def configured(environment_id)
          ->(**opts) { call(**opts, onepassword_environment_id: environment_id) }
        end
      end

      def call(env_prefix:, onepassword_environment_id: OnePassword.environment_id, **_options)
        env_payload = read_environment(onepassword_environment_id)

        env = ::Anyway::Env.new(type_cast: ::Anyway::NoCast, env_container: env_payload)

        env.fetch_with_trace(env_prefix).then do |(conf, trace)|
          Tracing.current_trace&.merge!(trace)
          conf
        end
      end

      private

      def read_environment(environment_id)
        raise ArgumentError, "1Password environment ID is required to load configuration from 1Password" if environment_id.nil?

        stdout, stderr, status = Open3.capture3("op", "environment", "read", environment_id, "--format", "json")

        raise RequestError, stderr.strip unless status.success?

        parse_response(stdout)
      end

      def parse_response(output)
        parsed = JSON.parse(output)

        # `op environment read --format json` returns an array of {name:, value:} objects.
        # Guard the Hash case for forward-compatibility if 1Password ever changes the shape.
        case parsed
        when Array
          parsed.to_h { |item| [item["name"], item["value"]] }
        when Hash
          parsed
        else
          {}
        end
      end
    end
  end
end
