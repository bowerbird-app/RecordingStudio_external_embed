# frozen_string_literal: true

module RecordingStudio
  module ExternalEmbed
    module YouTube
      ID = /\A[A-Za-z0-9_-]{11}\z/
      WATCH_HOSTS = %w[www.youtube.com youtube.com m.youtube.com].freeze
      SHORT_HOSTS = %w[youtu.be www.youtu.be].freeze
      HOSTS = (WATCH_HOSTS + SHORT_HOSTS).freeze

      def self.build
        Provider.define(:youtube) { YouTube.apply(self) }
      end

      def self.apply(builder)
        builder.host(*HOSTS)
        builder.label "YouTube"
        builder.embed_host "www.youtube-nocookie.com"
        builder.embeds_as "https://www.youtube-nocookie.com/embed/{id}"
        builder.canonical "https://www.youtube.com/watch?v={id}"
        landscape_match(builder)
        portrait_match(builder)
      end

      def self.landscape_match(builder)
        builder.match(content_type: :video, aspect: Rational(16, 9)) { YouTube.landscape(self) }
      end

      def self.portrait_match(builder)
        builder.match(content_type: :video, aspect: Rational(9, 16)) { YouTube.portrait(self) }
      end

      def self.landscape(matcher)
        matcher.query "v", pattern: ID, path: %r{\A/watch/?\z}, hosts: WATCH_HOSTS
        matcher.path %r{\A/(?<id>[A-Za-z0-9_-]{11})/?\z}, hosts: SHORT_HOSTS
        matcher.path %r{\A/embed/(?<id>[A-Za-z0-9_-]{11})/?\z}, hosts: WATCH_HOSTS
      end

      def self.portrait(matcher)
        matcher.path %r{\A/shorts/(?<id>[A-Za-z0-9_-]{11})/?\z}, hosts: WATCH_HOSTS
      end
    end
  end
end
