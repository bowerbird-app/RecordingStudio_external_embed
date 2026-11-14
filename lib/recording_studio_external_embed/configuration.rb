# frozen_string_literal: true

require "active_support/core_ext/numeric/time"

module RecordingStudio
  module ExternalEmbed
    class Configuration
      MERGEABLE = %i[open_timeout read_timeout max_bytes cache_ttl].freeze

      attr_accessor :open_timeout, :read_timeout, :max_bytes, :http, :resolver, :cache, :cache_ttl
      attr_reader :hooks, :layout

      def initialize
        @open_timeout = 1
        @read_timeout = 2
        @max_bytes = 65_536
        @http = nil
        @resolver = nil
        @cache = nil
        @cache_ttl = 12.hours
        # nil falls through to RecordingStudio.configuration.layout, then the core default.
        @layout = nil
        @hooks = RecordingStudio::Hooks.new
      end

      def layout=(value)
        @layout = RecordingStudio::Layout.accept(value)
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
          max_bytes: max_bytes,
          cache_ttl: cache_ttl
        }
      end
    end
  end
end
