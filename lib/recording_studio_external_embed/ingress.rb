# frozen_string_literal: true

require "uri"

module RecordingStudio
  module ExternalEmbed
    class Ingress
      MAX_BYTES = 2048

      attr_reader :original, :host, :path, :query

      def self.parse(input)
        stripped = stripped_input(input)
        return nil unless stripped

        uri = URI.parse(stripped)
        return nil unless acceptable?(uri, stripped)

        host = normalize_host(uri.host)
        return nil unless host

        new(stripped, host, uri.path.to_s, query_hash(uri))
      rescue URI::InvalidURIError
        nil
      end

      def self.stripped_input(input)
        return nil unless input.is_a?(String)

        stripped = input.strip
        return nil if stripped.empty? || stripped.bytesize > MAX_BYTES || stripped.match?(/[[:space:]]/)

        stripped
      end

      def self.acceptable?(uri, stripped)
        http_uri?(uri) && uri.userinfo.nil? && !explicit_port?(stripped)
      end

      def self.explicit_port?(stripped)
        stripped.match?(%r{\Ahttps?://[^/?#]*:\d+}i)
      end

      def self.http_uri?(uri)
        uri.is_a?(URI::HTTP) && %w[http https].include?(uri.scheme)
      end

      def self.normalize_host(host)
        return nil if host.nil?

        value = host.to_s.downcase
        value = value.delete_suffix(".") if value.end_with?(".") && !value.end_with?("..")
        return nil unless plain_host?(value)

        value
      end

      def self.plain_host?(value)
        value.match?(/\A[a-z0-9.-]+\z/) && !value.start_with?(".") && !value.end_with?(".") && !value.include?("..")
      end

      def self.query_hash(uri)
        hash = {}
        URI.decode_www_form(uri.query || "").each do |key, value|
          hash[key] ||= value
        end
        hash.freeze
      end

      private_class_method :new, :stripped_input, :acceptable?, :explicit_port?, :http_uri?,
                           :normalize_host, :plain_host?, :query_hash

      def initialize(original, host, path, query)
        @original = original
        @host = host
        @path = path
        @query = query
        freeze
      end
    end
  end
end
