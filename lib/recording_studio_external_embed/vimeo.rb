# frozen_string_literal: true

module RecordingStudio
  module ExternalEmbed
    module Vimeo
      DIGIT_ID = "[0-9]{1,64}"
      TOKEN = "[A-Za-z0-9]{1,64}"
      HASH = /\A#{TOKEN}\z/
      SITE_HOSTS = %w[vimeo.com www.vimeo.com].freeze
      PLAYER_HOSTS = %w[player.vimeo.com].freeze
      HOSTS = (SITE_HOSTS + PLAYER_HOSTS).freeze
      EMBED = "https://player.vimeo.com/video/{id}"
      EMBED_WITH_HASH = "https://player.vimeo.com/video/{id}?h={hash}"
      CANONICAL = "https://vimeo.com/{id}"
      CANONICAL_WITH_HASH = "https://vimeo.com/{id}/{hash}"
      SITE_ID = %r{\A/(?<id>#{DIGIT_ID})/?\z}
      SITE_HASH = %r{\A/(?<id>#{DIGIT_ID})/(?<hash>#{TOKEN})/?\z}
      PLAYER = %r{\A/video/(?<id>#{DIGIT_ID})/?\z}

      def self.build
        Provider.define(:vimeo) { Vimeo.apply(self) }
      end

      def self.apply(builder)
        builder.host(*HOSTS)
        builder.label "Vimeo"
        builder.embeds_as EMBED
        builder.canonical CANONICAL
        builder.oembed endpoint: "https://vimeo.com/api/oembed.json", thumbnail_hosts: ["i.vimeocdn.com"]
        builder.match(content_type: :video, aspect: Rational(16, 9)) { Vimeo.matches(self) }
      end

      def self.matches(matcher)
        unlisted(matcher)
        listed(matcher)
      end

      def self.unlisted(matcher)
        matcher.path SITE_HASH, hosts: SITE_HOSTS, embeds_as: EMBED_WITH_HASH, canonical: CANONICAL_WITH_HASH
        matcher.path PLAYER,
                     hosts: PLAYER_HOSTS,
                     hash_param: "h",
                     hash_pattern: HASH,
                     embeds_as: EMBED_WITH_HASH,
                     canonical: CANONICAL_WITH_HASH
      end

      def self.listed(matcher)
        matcher.path SITE_ID, hosts: SITE_HOSTS
        matcher.path PLAYER, hosts: PLAYER_HOSTS
      end
    end
  end
end
