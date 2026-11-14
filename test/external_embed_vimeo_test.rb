# frozen_string_literal: true

require "test_helper"
require "json"
require "active_support/cache"
require "active_support/testing/time_helpers"

class ExternalEmbedVimeoTest < Minitest::Test
  include ActiveSupport::Testing::TimeHelpers

  VIDEO_ID = "524933864"
  UNLISTED_HASH = "a1B2c3D4e5"
  EMBED_URL = "https://player.vimeo.com/video/#{VIDEO_ID}".freeze
  EMBED_WITH_HASH = "#{EMBED_URL}?h=#{UNLISTED_HASH}".freeze
  CANONICAL_URL = "https://vimeo.com/#{VIDEO_ID}".freeze
  CANONICAL_WITH_HASH = "#{CANONICAL_URL}/#{UNLISTED_HASH}".freeze

  def setup
    @calls = []
    config = RecordingStudio::ExternalEmbed.configuration
    config.resolver = ->(_host) { ["1.1.1.1"] }
    config.http = lambda do |uri|
      @calls << uri
      [200, payload.to_json]
    end
    config.cache = nil
    config.cache_ttl = 12.hours
  end

  def teardown
    config = RecordingStudio::ExternalEmbed.configuration
    config.http = nil
    config.resolver = nil
    config.cache = nil
    config.cache_ttl = 12.hours
  end

  def test_public_vimeo_urls_share_one_player_url
    urls = [
      "https://vimeo.com/#{VIDEO_ID}",
      "https://www.vimeo.com/#{VIDEO_ID}",
      "http://vimeo.com/#{VIDEO_ID}",
      "HTTPS://VIMEO.COM/#{VIDEO_ID}",
      "https://vimeo.com./#{VIDEO_ID}",
      "https://vimeo.com/#{VIDEO_ID}/",
      "https://vimeo.com/#{VIDEO_ID}?fl=1&autoplay=1",
      "https://player.vimeo.com/video/#{VIDEO_ID}",
      "https://player.vimeo.com/video/#{VIDEO_ID}/"
    ]

    urls.each do |url|
      embed = RecordingStudio::ExternalEmbed.resolve(url)

      assert_equal true, embed.supported?, url
      assert_equal :vimeo, embed.provider, url
      assert_equal "Vimeo", embed.provider_label, url
      assert_equal :video, embed.content_type, url
      assert_equal VIDEO_ID, embed.external_id, url
      assert_equal EMBED_URL, embed.embed_url, url
      assert_equal CANONICAL_URL, embed.canonical_url, url
      assert_equal Rational(16, 9), embed.aspect_ratio, url
      assert_equal 560, embed.width, url
      assert_equal 315, embed.height, url
    end
  end

  def test_unlisted_urls_keep_the_hash_on_the_player_and_canonical_urls
    urls = [
      "https://vimeo.com/#{VIDEO_ID}/#{UNLISTED_HASH}",
      "https://www.vimeo.com/#{VIDEO_ID}/#{UNLISTED_HASH}",
      "https://vimeo.com/#{VIDEO_ID}/#{UNLISTED_HASH}/",
      "https://player.vimeo.com/video/#{VIDEO_ID}?h=#{UNLISTED_HASH}",
      "https://player.vimeo.com/video/#{VIDEO_ID}?autoplay=1&h=#{UNLISTED_HASH}",
      "http://player.vimeo.com/video/#{VIDEO_ID}?h=#{UNLISTED_HASH}"
    ]

    urls.each do |url|
      embed = RecordingStudio::ExternalEmbed.resolve(url)

      assert_equal EMBED_WITH_HASH, embed.embed_url, url
      assert_equal CANONICAL_WITH_HASH, embed.canonical_url, url
      assert_equal VIDEO_ID, embed.external_id, url
      refute_includes embed.embed_url, "stolen", url
    end
  end

  def test_short_ids_and_hashes_are_preserved
    embed = RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/7/a")

    assert_equal "https://player.vimeo.com/video/7?h=a", embed.embed_url
    assert_equal "https://vimeo.com/7/a", embed.canonical_url
    assert_equal "7", embed.external_id
  end

  def test_lookalike_hosts_are_unsupported
    [
      "https://vimeo.com.evil.example/#{VIDEO_ID}",
      "https://www.vimeo.com.evil.example/#{VIDEO_ID}",
      "https://player.vimeo.com.evil.example/video/#{VIDEO_ID}",
      "https://notvimeo.com/#{VIDEO_ID}",
      "https://vimeo.com.evil.com/#{VIDEO_ID}/#{UNLISTED_HASH}"
    ].each do |url|
      result = RecordingStudio::ExternalEmbed.resolve(url)

      assert_equal false, result.supported?, url
      assert_equal :unsupported, result.reason, url
      refute_respond_to result, :embed_url
    end

    assert_empty @calls
  end

  def test_malformed_vimeo_urls_do_not_build_an_embed_url
    [
      "https://vimeo.com/abc",
      "https://vimeo.com/#{VIDEO_ID}abc",
      "https://vimeo.com/video/#{VIDEO_ID}",
      "https://vimeo.com/#{VIDEO_ID}/bad_hash",
      "https://vimeo.com/#{VIDEO_ID}/abc-def",
      "https://vimeo.com/#{VIDEO_ID}/abc/def",
      "https://vimeo.com/#{VIDEO_ID}/../../secret",
      "https://vimeo.com/#{'1' * 65}",
      "https://vimeo.com/#{VIDEO_ID}/#{'a' * 65}",
      "https://player.vimeo.com/video/abc",
      "https://player.vimeo.com/video/#{VIDEO_ID}?h=bad_hash",
      "https://player.vimeo.com/video/#{VIDEO_ID}?h=",
      "https://player.vimeo.com/video/#{VIDEO_ID}/#{UNLISTED_HASH}",
      "https://player.vimeo.com/",
      "https://vimeo.com/"
    ].each do |url|
      result = RecordingStudio::ExternalEmbed.resolve(url)

      assert_equal false, result.supported?, url
      assert_equal :malformed, result.reason, url
      assert_equal ["That URL is missing a valid id."], result.errors, url
      refute_respond_to result, :embed_url
    end

    assert_empty @calls
  end

  def test_oembed_metadata_is_copied_and_provider_html_is_discarded
    embed = RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/#{VIDEO_ID}?utm=1")

    assert_equal EMBED_URL, embed.embed_url
    assert_equal "Vimeo title", embed.title
    assert_equal "Ada", embed.author_name
    assert_equal "https://vimeo.com/ada", embed.author_url
    assert_equal "https://i.vimeocdn.com/video/123_640.jpg", embed.thumbnail_url
    assert_nil embed.description
    refute_includes embed.embed_url, "stolen"
    query = URI.decode_www_form(@calls.fetch(0).query).to_h
    assert_equal CANONICAL_URL, query["url"]
    assert_equal "json", query["format"]
    assert_equal "vimeo.com", @calls.fetch(0).host
    assert_equal "/api/oembed.json", @calls.fetch(0).path
  end

  def test_unlisted_oembed_requests_the_canonical_url_with_the_hash
    embed = RecordingStudio::ExternalEmbed.resolve("https://player.vimeo.com/video/#{VIDEO_ID}?h=#{UNLISTED_HASH}")

    assert_equal EMBED_WITH_HASH, embed.embed_url
    query = URI.decode_www_form(@calls.fetch(0).query).to_h
    assert_equal CANONICAL_WITH_HASH, query["url"]
    refute_includes embed.embed_url, "stolen"
  end

  def test_thumbnail_host_must_be_i_vimeocdn
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |_uri|
      [200, payload.merge("thumbnail_url" => "https://i.vimeocdn.com.evil.example/a.jpg").to_json]
    end

    embed = RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/#{VIDEO_ID}")

    assert_nil embed.thumbnail_url
    assert_equal "Vimeo title", embed.title
  end

  def test_oembed_width_and_height_set_the_aspect_ratio
    stub_dimensions(1000, 1000)

    embed = RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/#{VIDEO_ID}")

    assert_equal Rational(1, 1), embed.aspect_ratio
    assert_equal 560, embed.width
    assert_equal 560, embed.height
  end

  def test_missing_or_non_numeric_dimensions_keep_the_default_aspect
    stub_dimensions(1000, nil)
    missing = RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/#{VIDEO_ID}")

    stub_dimensions("1000", "1000")
    strings = RecordingStudio::ExternalEmbed.resolve("https://www.vimeo.com/#{VIDEO_ID}")

    assert_equal Rational(16, 9), missing.aspect_ratio
    assert_equal 560, missing.width
    assert_equal 315, missing.height
    assert_equal Rational(16, 9), strings.aspect_ratio
  end

  def test_a_failed_oembed_lookup_still_returns_the_embed
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |uri|
      @calls << uri
      [500, "nope"]
    end

    embed = RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/#{VIDEO_ID}")

    assert_equal true, embed.supported?
    assert_equal EMBED_URL, embed.embed_url
    assert_equal CANONICAL_URL, embed.canonical_url
    assert_nil embed.title
    assert_nil embed.thumbnail_url
    assert_equal Rational(16, 9), embed.aspect_ratio
  end

  def test_a_successful_lookup_is_cached_by_provider_and_canonical_url
    cache = RememberingCache.new
    RecordingStudio::ExternalEmbed.configuration.cache = cache

    first = RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/#{VIDEO_ID}")
    second = RecordingStudio::ExternalEmbed.resolve("https://www.vimeo.com/#{VIDEO_ID}")
    other = RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/111")

    assert_equal "Vimeo title", first.title
    assert_equal first.title, second.title
    assert_equal 2, @calls.size
    assert_equal 2, cache.writes.size
    assert_equal [:recording_studio_external_embed, :oembed, :vimeo, CANONICAL_URL], cache.writes.first[:name]
    assert_equal 12.hours, cache.writes.first[:expires_in]
    assert_equal "https://vimeo.com/111", cache.writes.last[:name].last
    assert_equal "Vimeo title", other.title
  end

  def test_a_failed_lookup_is_not_cached
    cache = RememberingCache.new
    RecordingStudio::ExternalEmbed.configuration.cache = cache
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |uri|
      @calls << uri
      [500, "nope"]
    end

    2.times { RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/#{VIDEO_ID}") }

    assert_equal 2, @calls.size
    assert_empty cache.writes
  end

  def test_cache_ttl_expires_successful_lookups
    RecordingStudio::ExternalEmbed.configuration.cache = ActiveSupport::Cache::MemoryStore.new
    RecordingStudio::ExternalEmbed.configuration.cache_ttl = 30.minutes

    RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/#{VIDEO_ID}")
    travel 29.minutes do
      RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/#{VIDEO_ID}")
    end
    travel 31.minutes do
      RecordingStudio::ExternalEmbed.resolve("https://vimeo.com/#{VIDEO_ID}")
    end

    assert_equal 2, @calls.size
  end

  def payload
    {
      "type" => "video",
      "title" => "Vimeo title",
      "author_name" => "Ada",
      "author_url" => "https://vimeo.com/ada",
      "thumbnail_url" => "https://i.vimeocdn.com/video/123_640.jpg",
      "html" => "<iframe src=\"https://player.vimeo.com/video/999?h=stolen\"></iframe>",
      "width" => 640,
      "height" => 360,
      "description" => "not copied"
    }
  end

  def stub_dimensions(width, height)
    body = payload.merge("width" => width, "height" => height)
    RecordingStudio::ExternalEmbed.configuration.http = ->(_uri) { [200, body.to_json] }
  end

  class RememberingCache
    attr_reader :writes

    def initialize
      @values = {}
      @writes = []
    end

    def read(name)
      @values[name]
    end

    def write(name, value, expires_in:)
      @writes << { name: name, expires_in: expires_in }
      @values[name] = value
    end
  end
end
