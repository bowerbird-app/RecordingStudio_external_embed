# frozen_string_literal: true

require "uri"

module RecordingStudio
  module ExternalEmbed
    class Embed
      ATTRIBUTES = %i[
        source_url canonical_url provider provider_label content_type external_id
        title description author_name author_url thumbnail_url embed_url
        width height aspect_ratio
      ].freeze
      SYMBOL_NAME = /\A[a-z][a-z0-9_]*\z/
      ID_PATTERN = /\A[A-Za-z0-9_-]{1,64}\z/

      attr_reader(*ATTRIBUTES)

      def self.materialize(**attrs)
        new(**attrs)
      end
      private_class_method :new

      def initialize(**attrs)
        ATTRIBUTES.each { |name| instance_variable_set(:"@#{name}", attrs[name]) }
        validate!
        freeze
      end

      def supported?
        true
      end

      def valid?
        true
      end

      def errors
        [].freeze
      end

      def reason
        nil
      end

      def ==(other)
        other.is_a?(Embed) && ATTRIBUTES.all? { |name| public_send(name) == other.public_send(name) }
      end

      private

      def validate!
        require_https_url(embed_url, "embed url must be a trusted https url")
        require_https_url(canonical_url, "canonical url must be https")
        require_symbol(provider, "provider is invalid")
        require_symbol(content_type, "content type is invalid")
        require_external_id
        require_dimensions
        drop_untrusted_urls
      end

      def require_https_url(value, message)
        raise ArgumentError, message unless trusted_https?(value)
      end

      def require_symbol(value, message)
        raise ArgumentError, message unless value.is_a?(Symbol) && value.match?(SYMBOL_NAME)
      end

      def require_external_id
        return if external_id.is_a?(String) && external_id.match?(ID_PATTERN)

        raise ArgumentError, "external id is invalid"
      end

      def require_dimensions
        raise ArgumentError, "aspect ratio is invalid" unless aspect_ratio.is_a?(Rational) && aspect_ratio.positive?
        raise ArgumentError, "dimensions are invalid" unless positive_integer?(width) && positive_integer?(height)
      end

      def drop_untrusted_urls
        @thumbnail_url = nil unless thumbnail_url.nil? || trusted_https?(thumbnail_url)
        @author_url = nil unless author_url.nil? || trusted_https?(author_url)
      end

      def trusted_https?(value)
        uri = URI.parse(value.to_s)
        uri.is_a?(URI::HTTPS) && uri.host && uri.userinfo.nil? && (uri.port.nil? || uri.port == 443)
      rescue URI::InvalidURIError
        false
      end

      def positive_integer?(value)
        value.is_a?(Integer) && value.positive?
      end
    end

    class Unresolved
      MESSAGES = {
        invalid: "That URL can't be embedded.",
        unsupported: "That URL is not from a supported provider.",
        malformed: "That URL is missing a valid id."
      }.freeze

      attr_reader :source, :reason, :message

      def self.invalid(input)
        new(source: stored_source(input), reason: :invalid)
      end

      def self.unsupported(input)
        new(source: stored_source(input), reason: :unsupported)
      end

      def self.malformed(input)
        new(source: stored_source(input), reason: :malformed)
      end

      def self.stored_source(input)
        return nil unless input.is_a?(String)

        text = input.strip
        text.bytesize > 256 ? "#{text.byteslice(0, 256)}..." : text
      end
      private_class_method :new, :stored_source

      def initialize(source:, reason:)
        raise ArgumentError, "unknown reason" unless MESSAGES.key?(reason)

        @source = source
        @reason = reason
        @message = MESSAGES.fetch(reason)
        freeze
      end

      def supported?
        false
      end

      def valid?
        false
      end

      def errors
        [message].freeze
      end

      def ==(other)
        other.is_a?(Unresolved) && source == other.source && reason == other.reason
      end
    end
  end
end
