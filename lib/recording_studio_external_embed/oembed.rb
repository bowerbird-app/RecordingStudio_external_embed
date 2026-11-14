# frozen_string_literal: true

require "ipaddr"
require "openssl"
require "json"
require "net/http"
require "resolv"
require "uri"

module RecordingStudio
  module ExternalEmbed
    module Oembed
      class Presentation
        attr_reader :title, :author_name, :author_url, :thumbnail_url, :width, :height, :metadata_status

        def self.none
          for_status(:none)
        end

        def self.for_status(metadata_status)
          new(metadata_status: metadata_status)
        end

        def initialize(**attrs)
          @title = attrs[:title]
          @author_name = attrs[:author_name]
          @author_url = attrs[:author_url]
          @thumbnail_url = attrs[:thumbnail_url]
          @width = attrs[:width]
          @height = attrs[:height]
          @metadata_status = attrs[:metadata_status]
          raise ArgumentError, "metadata status is invalid" unless known_status?

          freeze
        end

        def data?
          title || author_name || author_url || thumbnail_url || width || height
        end

        def cacheable?
          metadata_status == :fetched
        end

        private

        def known_status?
          Embed::METADATA_STATUSES.include?(metadata_status)
        end
      end

      class Endpoint
        attr_reader :endpoint, :thumbnail_hosts

        def self.build(endpoint:, thumbnail_hosts:)
          parsed_endpoint(endpoint)
          hosts = Array(thumbnail_hosts).map { |name| name.to_s.downcase }
          raise DefinitionError, "thumbnail host is invalid" unless hosts.all? { |name| public_name?(name) }

          new(endpoint, hosts.freeze)
        end

        def self.parsed_endpoint(endpoint)
          uri = URI.parse(endpoint.to_s)
          return uri if public_endpoint?(uri)

          raise DefinitionError, "oEmbed endpoint must be a public https origin"
        rescue URI::InvalidURIError
          raise DefinitionError, "oEmbed endpoint must be a public https origin"
        end

        def self.public_endpoint?(uri)
          return false unless uri.is_a?(URI::HTTPS)
          return false if uri.userinfo
          return false unless public_name?(uri.host.to_s.downcase)

          uri.port.nil? || uri.port == 443
        end

        def self.public_name?(host)
          return false unless host.match?(/\A[a-z0-9.-]+\z/)
          return false if host.include?("..") || host.start_with?(".") || host.end_with?(".")

          !ip_literal?(host)
        end

        def self.ip_literal?(host)
          IPAddr.new(host)
          true
        rescue IPAddr::InvalidAddressError
          false
        end

        private_class_method :new, :parsed_endpoint, :public_endpoint?, :public_name?, :ip_literal?

        def initialize(endpoint, thumbnail_hosts)
          @endpoint = endpoint
          @thumbnail_hosts = thumbnail_hosts
          freeze
        end
      end

      class AddressGuard
        UNSAFE_RANGES = ["0.0.0.0", "::", "100.64.0.0/10", "224.0.0.0/4", "240.0.0.0/4", "ff00::/8"].freeze

        def self.safe_address(addresses)
          list = Array(addresses).map(&:to_s)
          return nil if list.empty? || list.any? { |address| unsafe?(address) }

          list.first
        end

        def self.unsafe?(address)
          ip = coerced_ip(address)
          return true unless ip
          return true if ip.loopback? || ip.private? || ip.link_local?

          unsafe_range?(ip)
        end

        def self.coerced_ip(address)
          ip = IPAddr.new(address)
          return ip.native if ip.respond_to?(:ipv4_mapped?) && ip.ipv4_mapped?

          ip
        rescue IPAddr::Error
          nil
        end

        def self.unsafe_range?(ip)
          UNSAFE_RANGES.any? { |range| IPAddr.new(range).include?(ip) }
        end

        private_class_method :unsafe?, :coerced_ip, :unsafe_range?
      end

      class Gateway
        def self.lookup(endpoint, canonical_url, provider:)
          new(endpoint, canonical_url, provider).lookup
        end

        def initialize(endpoint, canonical_url, provider)
          @endpoint = endpoint
          @canonical_url = canonical_url
          @provider = provider
        end

        def lookup
          cached = ResponseCache.read(@provider, @canonical_url)
          return cached if cached

          presentation = retrieve
          ResponseCache.write(@provider, @canonical_url, presentation) if presentation.cacheable?
          presentation
        rescue JSON::ParserError
          Presentation.for_status(:failed)
        rescue IOError, SystemCallError, Timeout::Error, SocketError, Resolv::ResolvError,
               OpenSSL::SSL::SSLError, Net::ProtocolError
          Presentation.for_status(:transient_failure)
        end

        private

        def retrieve
          uri = request_uri
          return Presentation.for_status(:failed) unless uri

          refusal = pin(uri)
          return refusal if refusal

          status, body = fetch(uri)
          classify(status, body)
        end

        def pin(uri)
          addresses = Array(resolve(uri.host)).map(&:to_s)
          return Presentation.for_status(:transient_failure) if addresses.empty?

          @address = AddressGuard.safe_address(addresses)
          return if @address

          Presentation.for_status(:failed)
        end

        def classify(status, body)
          code = status.to_i
          return Presentation.for_status(:transient_failure) if code == 429 || (500..599).cover?(code)
          return Presentation.for_status(:failed) unless code == 200 && body

          Metadata.read(body, thumbnail_hosts: @endpoint.thumbnail_hosts)
        end

        def request_uri
          uri = URI.parse(@endpoint.endpoint)
          params = URI.decode_www_form(uri.query.to_s)
          params << ["url", @canonical_url]
          params << %w[format json]
          uri.query = URI.encode_www_form(params)
          return nil unless uri.is_a?(URI::HTTPS) && uri.host == URI.parse(@endpoint.endpoint).host

          uri
        rescue URI::InvalidURIError
          nil
        end

        def resolve(host)
          resolver = RecordingStudio::ExternalEmbed.configuration.resolver
          return resolver.call(host) if resolver

          Resolv.getaddresses(host)
        end

        def fetch(uri)
          client = RecordingStudio::ExternalEmbed.configuration.http
          return client.call(uri) if client

          response = pinned_http(uri).start { |http| http.request(Net::HTTP::Get.new(uri)) }
          limited_body(response)
        end

        def pinned_http(uri)
          settings = RecordingStudio::ExternalEmbed.configuration
          http = Net::HTTP.new(uri.host, uri.port)
          http.ipaddr = @address
          http.use_ssl = true
          http.open_timeout = settings.open_timeout
          http.read_timeout = settings.read_timeout
          http.max_retries = 0
          http
        end

        def limited_body(response)
          body = response.body.to_s
          limit = RecordingStudio::ExternalEmbed.configuration.max_bytes
          return [response.code.to_i, nil] if body.bytesize > limit

          [response.code.to_i, body]
        end
      end

      class Metadata
        def self.read(body, thumbnail_hosts:)
          new(body, thumbnail_hosts).read
        end

        def initialize(body, thumbnail_hosts)
          @body = body
          @thumbnail_hosts = thumbnail_hosts
        end

        def read
          data = parsed_hash
          return Presentation.for_status(:failed) unless data

          data.delete("html")
          present(data)
        end

        private

        def present(data)
          presentation = Presentation.new(**attributes(data), metadata_status: :fetched)
          presentation.data? ? presentation : Presentation.none
        end

        def attributes(data)
          {
            title: clean_text(data["title"]),
            author_name: clean_text(data["author_name"]),
            author_url: https_url(data["author_url"]),
            thumbnail_url: https_url(data["thumbnail_url"], hosts: @thumbnail_hosts),
            width: counted(data["width"]),
            height: counted(data["height"])
          }
        end

        def counted(value)
          value if value.is_a?(Integer) && value.positive?
        end

        def parsed_hash
          return nil if @body.to_s.bytesize > RecordingStudio::ExternalEmbed.configuration.max_bytes

          data = JSON.parse(@body.to_s)
          data if data.is_a?(Hash)
        rescue JSON::ParserError
          nil
        end

        def clean_text(value)
          return nil unless value.is_a?(String)

          text = value.gsub(/[[:cntrl:]<>]/, "").strip
          return nil if text.empty?

          text.length > 300 ? text[0, 300] : text
        end

        def https_url(value, hosts: nil)
          uri = URI.parse(value.to_s)
          return nil unless uri.is_a?(URI::HTTPS) && uri.host && uri.userinfo.nil?
          return nil if hosts && !hosts.include?(uri.host.downcase)

          uri.to_s
        rescue URI::InvalidURIError
          nil
        end
      end

      class ResponseCache
        def self.read(provider, canonical_url)
          new(provider, canonical_url).read
        end

        def self.write(provider, canonical_url, presentation)
          new(provider, canonical_url).write(presentation)
        end

        def initialize(provider, canonical_url)
          @key = [:recording_studio_external_embed, :oembed, provider, canonical_url]
        end

        def read
          store = cache_store
          return nil unless store

          value = store.read(@key)
          value if value.is_a?(Presentation) && value.cacheable?
        rescue StandardError
          nil
        end

        def write(presentation)
          store = cache_store
          return unless store

          store.write(@key, presentation, expires_in: configuration.cache_ttl)
        rescue StandardError
          nil
        end

        private

        def cache_store
          return configuration.cache if configuration.cache
          return unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

          Rails.cache
        end

        def configuration
          RecordingStudio::ExternalEmbed.configuration
        end
      end
    end
    private_constant :Oembed
  end
end
