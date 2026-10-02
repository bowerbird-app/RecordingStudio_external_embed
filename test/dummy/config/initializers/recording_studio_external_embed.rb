# frozen_string_literal: true

# Dummy-only provider catalog for smoke-testing embeds. The gem still ships YouTube as the sole built-in.
RecordingStudio::ExternalEmbed.configure do |config|
  config.open_timeout = 1
  config.read_timeout = 2
  config.max_bytes = 65_536
end

BRIGHTCOVE_ACCOUNT = "1752604549001"
BRIGHTCOVE_PLAYER = "default_default"
TWITCH_EMBED_PARENTS = ENV.fetch(
  "TWITCH_EMBED_PARENTS",
  "localhost,127.0.0.1,ripeness-unreached-wham.ngrok-free.dev"
).split(",").map(&:strip).reject(&:empty?)
TWITCH_PARENT_QUERY = TWITCH_EMBED_PARENTS.map { |host| "parent=#{host}" }.join("&")

RecordingStudio::ExternalEmbed.register(
  RecordingStudio::ExternalEmbed::Provider.define(:vimeo) do
    host "vimeo.com", "www.vimeo.com", "player.vimeo.com"
    embed_host "player.vimeo.com"
    label "Vimeo"
    embeds_as "https://player.vimeo.com/video/{id}"
    canonical "https://vimeo.com/{id}"
    oembed endpoint: "https://vimeo.com/api/oembed.json", thumbnail_hosts: ["i.vimeocdn.com"]
    match content_type: :video, aspect: Rational(16, 9) do
      path %r{\A/(?:video/)?(?<id>\d+)/?\z}, hosts: %w[vimeo.com www.vimeo.com]
      path %r{\A/video/(?<id>\d+)/?\z}, hosts: %w[player.vimeo.com]
    end
  end
)

RecordingStudio::ExternalEmbed.register(
  RecordingStudio::ExternalEmbed::Provider.define(:loom) do
    host "www.loom.com"
    embed_host "www.loom.com"
    label "Loom"
    embeds_as "https://www.loom.com/embed/{id}"
    canonical "https://www.loom.com/share/{id}"
    match content_type: :video, aspect: Rational(16, 9) do
      path %r{\A/share/(?<id>[a-f0-9]{10,64})/?\z}i
      path %r{\A/embed/(?<id>[a-f0-9]{10,64})/?\z}i
      path %r{\A/share/(?<id>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/?\z}i
    end
  end
)

RecordingStudio::ExternalEmbed.register(
  RecordingStudio::ExternalEmbed::Provider.define(:wistia) do
    host "fast.wistia.net", "fast.wistia.com", "wistia.com", "www.wistia.com"
    embed_host "fast.wistia.net"
    label "Wistia"
    embeds_as "https://fast.wistia.net/embed/iframe/{id}"
    canonical "https://wistia.com/medias/{id}"
    oembed endpoint: "https://fast.wistia.com/oembed", thumbnail_hosts: ["embed-ssl.wistia.com", "embed.wistia.com"]
    match content_type: :video, aspect: Rational(16, 9) do
      path %r{\A/embed/iframe/(?<id>[a-z0-9]+)/?\z}i, hosts: %w[fast.wistia.net fast.wistia.com]
      query "wmediaid", pattern: /\A[a-z0-9]+\z/i, path: %r{\A/watch/.+\z}, hosts: %w[wistia.com www.wistia.com]
    end
  end
)

RecordingStudio::ExternalEmbed.register(
  RecordingStudio::ExternalEmbed::Provider.define(:brightcove) do
    host "players.brightcove.net"
    embed_host "players.brightcove.net"
    label "Brightcove"
    player_path = "/#{BRIGHTCOVE_ACCOUNT}/#{BRIGHTCOVE_PLAYER}/index.html"
    embeds_as "https://players.brightcove.net#{player_path}?videoId={id}"
    canonical "https://players.brightcove.net#{player_path}?videoId={id}"
    match content_type: :video, aspect: Rational(16, 9) do
      query "videoId", pattern: /\A\d+\z/, path: %r{\A/#{BRIGHTCOVE_ACCOUNT}/#{BRIGHTCOVE_PLAYER}/index\.html\z}
    end
  end
)

RecordingStudio::ExternalEmbed.register(
  RecordingStudio::ExternalEmbed::Provider.define(:dailymotion) do
    host "www.dailymotion.com", "dai.ly"
    embed_host "www.dailymotion.com"
    label "Dailymotion"
    embeds_as "https://www.dailymotion.com/embed/video/{id}"
    canonical "https://www.dailymotion.com/video/{id}"
    oembed endpoint: "https://www.dailymotion.com/services/oembed", thumbnail_hosts: ["s1.dmcdn.net", "s2.dmcdn.net"]
    match content_type: :video, aspect: Rational(16, 9) do
      path %r{\A/video/(?<id>x[a-z0-9]+)/?\z}i, hosts: %w[www.dailymotion.com]
      path %r{\A/(?<id>x[a-z0-9]+)/?\z}i, hosts: %w[dai.ly]
    end
  end
)

TWITCH_CLIP_EMBED = "https://clips.twitch.tv/embed?clip={id}&#{TWITCH_PARENT_QUERY}"

RecordingStudio::ExternalEmbed.register(
  RecordingStudio::ExternalEmbed::Provider.define(:twitch) do
    host "www.twitch.tv", "twitch.tv", "player.twitch.tv", "m.twitch.tv"
    embed_host "player.twitch.tv", "clips.twitch.tv"
    label "Twitch VOD"
    embeds_as "https://player.twitch.tv/?video=v{id}&#{TWITCH_PARENT_QUERY}"
    canonical "https://www.twitch.tv/videos/{id}"
    match content_type: :video, aspect: Rational(16, 9) do
      path %r{\A/videos/(?<id>\d+)/?\z}, hosts: %w[www.twitch.tv twitch.tv m.twitch.tv]
      path %r{\A/[^/]+/clip/(?<id>[A-Za-z0-9_-]+)/?\z},
        hosts: %w[m.twitch.tv],
        embeds_as: TWITCH_CLIP_EMBED
    end
  end
)

RecordingStudio::ExternalEmbed.register(
  RecordingStudio::ExternalEmbed::Provider.define(:twitch_clip) do
    host "clips.twitch.tv"
    embed_host "clips.twitch.tv"
    label "Twitch clip"
    embeds_as TWITCH_CLIP_EMBED
    canonical "https://clips.twitch.tv/{id}"
    match content_type: :video, aspect: Rational(16, 9) do
      path %r{\A/(?<id>[A-Za-z0-9_-]+)/?\z}
    end
  end
)
