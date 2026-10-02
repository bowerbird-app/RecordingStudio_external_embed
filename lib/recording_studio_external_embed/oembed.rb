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
        attr_reader :title, :author_name, :author_url, :thumbnail_url

        def self.empty
          new(title: nil, author_name: nil, author_url: nil, thumbnail_url: nil)
        end

        def initialize(title:, author_name:, author_url:, thumbnail_url:)
          @title = title
          @author_name = author_name
          @author_url = author_url
          @thumbnail_url = thumbnail_url
          freeze
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
        def self.lookup(endpoint, canonical_url)
          new(endpoint, canonical_url).lookup
        end

        def initialize(endpoint, canonical_url)
          @endpoint = endpoint
          @canonical_url = canonical_url
        end

        def lookup
          uri = request_uri
          return Presentation.empty unless uri && safe_destination?(uri)

          status, body = fetch(uri)
          return Presentation.empty unless status.to_i == 200

          map(body)
        rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error,
               SocketError, Resolv::ResolvError, OpenSSL::SSL::SSLError, Net::ProtocolError
          Presentation.empty
        end

        private

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

        def safe_destination?(uri)
          @address = AddressGuard.safe_address(resolve(uri.host))
          !@address.nil?
        end

        def resolve(host)
          resolver = RecordingStudio::ExternalEmbed.configuration.resolver
          return resolver.call(host) if resolver

          Resolv.getaddresses(host)
        end

        def fetch(uri)
          client = RecordingStudio::ExternalEmbed.configuration.http
          return client.call(uri) if client

          live_fetch(uri)
        end

        def live_fetch(uri)
          response = pinned_http(uri).start { |client| client.request(Net::HTTP::Get.new(uri)) }
          limited_body(response)
        end

        def pinned_http(uri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.ipaddr = @address
          http.use_ssl = true
          http.open_timeout = configuration.open_timeout
          http.read_timeout = configuration.read_timeout
          http.max_retries = 0
          http
        end

        def limited_body(response)
          body = response.body.to_s
          return [response.code.to_i, nil] if body.bytesize > configuration.max_bytes

          [response.code.to_i, body]
        end

        def configuration
          RecordingStudio::ExternalEmbed.configuration
        end

        def map(body)
          data = parsed_hash(body)
          return Presentation.empty unless data

          data.delete("html")
          Presentation.new(
            title: clean_text(data["title"]),
            author_name: clean_text(data["author_name"]),
            author_url: https_url(data["author_url"]),
            thumbnail_url: https_url(data["thumbnail_url"], hosts: @endpoint.thumbnail_hosts)
          )
        end

        def parsed_hash(body)
          return nil if body.to_s.bytesize > configuration.max_bytes

          data = JSON.parse(body.to_s)
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
    end
    private_constant :Oembed
  end
end
