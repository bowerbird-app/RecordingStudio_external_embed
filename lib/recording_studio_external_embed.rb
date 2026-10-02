# frozen_string_literal: true

require "recording_studio"
require "recording_studio_external_embed/version"
require "recording_studio_external_embed/configuration"
require "recording_studio_external_embed/ingress"
require "recording_studio_external_embed/embed"
require "recording_studio_external_embed/provider"
require "recording_studio_external_embed/oembed"
require "recording_studio_external_embed/youtube"
require "recording_studio_external_embed/helper"
require "recording_studio_external_embed/engine"

module RecordingStudio
  module ExternalEmbed
    class Conflict < StandardError; end
    class DefinitionError < StandardError; end

    CATALOG_KEY = :recording_studio_external_embed_catalog

    class << self
      def resolve(url)
        ingress = Ingress.parse(url)
        return Unresolved.invalid(url) unless ingress

        provider = catalog[ingress.host]
        return Unresolved.unsupported(ingress.original) unless provider

        provider.resolve(ingress)
      end

      def register(provider)
        raise TypeError, "expected a provider" unless provider.is_a?(Provider)
        raise Conflict, "catalog is frozen" if @catalog_frozen

        register_mutex.synchronize { append_provider(provider) }
        provider
      end

      def configure
        yield(configuration) if block_given?
      end

      def configuration
        @configuration ||= Configuration.new
      end

      def with_providers(*extra, replace: false)
        indexed = index_providers(replace ? extra : providers + extra)
        previous = Thread.current[CATALOG_KEY]
        Thread.current[CATALOG_KEY] = indexed
        yield
      ensure
        Thread.current[CATALOG_KEY] = previous if defined?(previous)
      end

      def freeze_catalog!
        @catalog_frozen = true
        @catalog = index_providers(providers)
      end

      private

      def catalog
        Thread.current[CATALOG_KEY] || @catalog ||= index_providers(providers)
      end

      def providers
        @providers ||= [YouTube.build].freeze
      end

      def append_provider(provider)
        current = providers
        return if current.any? { |item| item.equal?(provider) }

        assert_available(current, provider)
        @providers = (current + [provider]).freeze
        @catalog = nil
      end

      def assert_available(current, provider)
        raise Conflict, "provider is already registered" if current.any? { |item| item.key == provider.key }

        overlap = current.flat_map(&:hosts) & provider.hosts
        raise Conflict, "host is already registered" unless overlap.empty?
      end

      def index_providers(list)
        map = {}
        keys = {}
        list.each { |provider| index_provider(map, keys, provider) }
        map.freeze
      end

      def index_provider(map, keys, provider)
        raise Conflict, "provider is already registered" if keys[provider.key]

        keys[provider.key] = true
        provider.hosts.each { |host| index_host(map, host, provider) }
      end

      def index_host(map, host, provider)
        raise Conflict, "host is already registered" if map[host]

        map[host] = provider
      end

      def register_mutex
        @register_mutex ||= Mutex.new
      end
    end

    private_constant :Ingress, :YouTube
  end
end
