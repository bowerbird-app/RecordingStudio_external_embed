# frozen_string_literal: true

module RecordingStudio
  module ExternalEmbed
    class Configuration
      MERGEABLE = %i[open_timeout read_timeout max_bytes].freeze

      attr_accessor :open_timeout, :read_timeout, :max_bytes, :http, :resolver
      attr_reader :hooks

      def initialize
        @open_timeout = 1
        @read_timeout = 2
        @max_bytes = 65_536
        @http = nil
        @resolver = nil
        @hooks = RecordingStudio::Hooks.new
      end

      def merge!(attributes)
        return unless attributes.respond_to?(:each_pair)

        attributes.each_pair do |key, value|
          writer = "#{key}="
          next unless MERGEABLE.include?(key.to_sym) && respond_to?(writer)

          public_send(writer, value)
        end
      end

      def to_h
        {
          open_timeout: open_timeout,
          read_timeout: read_timeout,
          max_bytes: max_bytes
        }
      end
    end
  end
end
