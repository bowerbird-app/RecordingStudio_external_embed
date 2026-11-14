# frozen_string_literal: true

require "test_helper"
require "json"
require "openssl"
require "resolv"

class ExternalEmbedOembedTest < Minitest::Test
  CLIP_EMBED = "https://play.clips.test/e/abcd1234"

  def setup
    @calls = []
    config = RecordingStudio::ExternalEmbed.configuration
    config.resolver = ->(_host) { ["1.1.1.1"] }
    config.http = lambda do |uri|
      @calls << uri
      [200, payload.to_json]
    end
    config.cache = nil
    config.max_bytes = 65_536
  end

  def teardown
    config = RecordingStudio::ExternalEmbed.configuration
    config.http = nil
    config.resolver = nil
    config.cache = nil
    config.max_bytes = 65_536
  end

  def test_oembed_metadata_is_copied_and_provider_html_is_discarded
    embed = resolve_clip("https://clips.test/v/abcd1234?utm=1")

    assert_equal true, embed.supported?
    assert_equal "https://play.clips.test/e/abcd1234", embed.embed_url
    assert_equal "https://clips.test/v/abcd1234", embed.canonical_url
    assert_equal "Clip title", embed.title
    assert_equal "Ada", embed.author_name
    assert_equal "https://clips.test/ada", embed.author_url
    assert_equal "https://img.clips.test/a.jpg", embed.thumbnail_url
    assert_nil embed.description
    assert_equal :fetched, embed.metadata_status
    assert_equal false, embed.metadata_retryable?
    query = URI.decode_www_form(@calls.fetch(0).query).to_h
    assert_equal "https://clips.test/v/abcd1234", query["url"]
    assert_equal "json", query["format"]
    assert_equal "oembed.clips.test", @calls.fetch(0).host
  end

  def test_private_addresses_skip_the_request_and_still_return_an_embed
    RecordingStudio::ExternalEmbed.configuration.resolver = ->(_host) { ["127.0.0.1"] }
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |_uri|
      flunk "private addresses must not be fetched"
    end

    embed = resolve_clip("https://clips.test/v/abcd1234")

    assert_equal CLIP_EMBED, embed.embed_url
    assert_nil embed.title
    assert_equal :failed, embed.metadata_status
    assert_equal false, embed.metadata_retryable?
  end

  def test_a_mixed_public_and_private_answer_fails_closed
    RecordingStudio::ExternalEmbed.configuration.resolver = ->(_host) { ["1.1.1.1", "10.0.0.1"] }
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |_uri|
      flunk "any private answer must block the request"
    end

    embed = resolve_clip("https://clips.test/v/abcd1234")

    assert_nil embed.title
    assert_equal true, embed.supported?
    assert_equal :failed, embed.metadata_status
    assert_equal false, embed.metadata_retryable?
  end

  def test_live_oembed_http_is_blocked_in_tests
    RecordingStudio::ExternalEmbed.configuration.http = nil
    gateway = RecordingStudio::ExternalEmbed.const_get(:Oembed)::Gateway.new(nil, nil, :clip)

    error = assert_raises(RuntimeError) do
      gateway.send(:fetch, URI("https://oembed.invalid/oembed"))
    end

    assert_equal "oEmbed HTTP must be stubbed in tests", error.message
  end

  def test_a_failed_oembed_response_keeps_the_constructed_embed
    RecordingStudio::ExternalEmbed.configuration.http = ->(_uri) { [500, "nope"] }

    embed = resolve_clip("https://clips.test/v/abcd1234")

    assert_equal CLIP_EMBED, embed.embed_url
    assert_nil embed.title
    assert_nil embed.thumbnail_url
    assert_equal :transient_failure, embed.metadata_status
    assert_equal true, embed.metadata_retryable?
  end

  def test_a_successful_lookup_without_a_thumbnail_is_fetched
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |_uri|
      [200, payload.merge("thumbnail_url" => nil).to_json]
    end

    embed = resolve_clip("https://clips.test/v/abcd1234")

    assert_equal :fetched, embed.metadata_status
    assert_equal false, embed.metadata_retryable?
    assert_equal "Clip title", embed.title
    assert_nil embed.thumbnail_url
  end

  def test_a_provider_without_an_oembed_endpoint_reports_none
    RecordingStudio::ExternalEmbed.configuration.http = ->(_uri) { flunk "must not fetch" }

    embed = RecordingStudio::ExternalEmbed.with_providers(define_plain_clip) do
      RecordingStudio::ExternalEmbed.resolve("https://clips.test/v/abcd1234")
    end

    assert_equal :none, embed.metadata_status
    assert_equal false, embed.metadata_retryable?
    assert_equal CLIP_EMBED, embed.embed_url
    assert_nil embed.title
  end

  def test_a_successful_lookup_with_no_metadata_reports_none_and_is_not_cached
    cache = RememberingCache.new
    RecordingStudio::ExternalEmbed.configuration.cache = cache
    bodies = [
      {},
      { "html" => "<iframe src=\"https://evil.example\"></iframe>", "type" => "video" }
    ]

    bodies.each do |body|
      @calls.clear
      RecordingStudio::ExternalEmbed.configuration.http = lambda do |uri|
        @calls << uri
        [200, body.to_json]
      end

      2.times do
        embed = resolve_clip("https://clips.test/v/abcd1234")

        assert_equal :none, embed.metadata_status
        assert_equal false, embed.metadata_retryable?
        assert_nil embed.title
        assert_nil embed.thumbnail_url
        assert_equal CLIP_EMBED, embed.embed_url
      end

      assert_equal 2, @calls.size
    end

    assert_empty cache.writes
  end

  def test_a_cached_hit_reports_fetched
    cache = RememberingCache.new
    RecordingStudio::ExternalEmbed.configuration.cache = cache

    first = resolve_clip("https://clips.test/v/abcd1234")
    RecordingStudio::ExternalEmbed.configuration.http = ->(_uri) { flunk "cached lookup must not fetch" }
    second = resolve_clip("https://clips.test/v/abcd1234")

    assert_equal :fetched, first.metadata_status
    assert_equal :fetched, second.metadata_status
    assert_equal false, second.metadata_retryable?
    assert_equal "Clip title", second.title
    assert_equal "https://img.clips.test/a.jpg", second.thumbnail_url
    assert_equal 1, @calls.size
    assert_equal 1, cache.writes.size
  end

  def test_transient_lookup_failures_are_retryable_and_are_not_cached
    cache = RememberingCache.new
    RecordingStudio::ExternalEmbed.configuration.cache = cache
    transient = [
      ->(_) { raise Timeout::Error, "slow" },
      ->(_) { raise SocketError, "down" },
      ->(_) { raise Errno::ECONNRESET },
      ->(_) { raise IOError, "closed" },
      ->(_) { raise OpenSSL::SSL::SSLError, "bad cert" },
      ->(_) { raise Net::ProtocolError, "bad response" },
      ->(_) { [429, "slow down"] },
      ->(_) { [500, "nope"] },
      ->(_) { [503, "unavailable"] }
    ]

    transient.each do |responder|
      @calls.clear
      RecordingStudio::ExternalEmbed.configuration.http = lambda do |uri|
        @calls << uri
        responder.call(uri)
      end

      2.times do
        embed = resolve_clip("https://clips.test/v/abcd1234")

        assert_equal :transient_failure, embed.metadata_status
        assert_equal true, embed.metadata_retryable?
        assert_equal CLIP_EMBED, embed.embed_url
        assert_nil embed.title
      end

      assert_equal 2, @calls.size
    end

    assert_empty cache.writes
  end

  def test_dns_failures_are_retryable_and_do_not_fetch
    RecordingStudio::ExternalEmbed.configuration.http = ->(_uri) { flunk "must not fetch" }
    [
      ->(_host) { raise Resolv::ResolvError, "dns" },
      ->(_host) { [] }
    ].each do |resolver|
      RecordingStudio::ExternalEmbed.configuration.resolver = resolver

      embed = resolve_clip("https://clips.test/v/abcd1234")

      assert_equal :transient_failure, embed.metadata_status
      assert_equal true, embed.metadata_retryable?
      assert_equal CLIP_EMBED, embed.embed_url
    end
  end

  def test_permanent_lookup_failures_are_not_retryable_and_are_not_cached
    cache = RememberingCache.new
    RecordingStudio::ExternalEmbed.configuration.cache = cache
    permanent = [
      ->(_) { [404, "missing"] },
      ->(_) { [400, "bad"] },
      ->(_) { [401, "no"] },
      ->(_) { [200, "not-json"] },
      ->(_) { [200, "[]"] },
      ->(_) { [200, "null"] },
      ->(_) { [200, ""] }
    ]

    permanent.each do |responder|
      @calls.clear
      RecordingStudio::ExternalEmbed.configuration.http = lambda do |uri|
        @calls << uri
        responder.call(uri)
      end

      2.times do
        embed = resolve_clip("https://clips.test/v/abcd1234")

        assert_equal :failed, embed.metadata_status
        assert_equal false, embed.metadata_retryable?
        assert_equal CLIP_EMBED, embed.embed_url
        assert_nil embed.title
      end

      assert_equal 2, @calls.size
    end

    assert_empty cache.writes
  end

  def test_an_oversized_body_is_a_permanent_failure
    RecordingStudio::ExternalEmbed.configuration.max_bytes = 32
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |uri|
      @calls << uri
      [200, { "title" => "x" * 80 }.to_json]
    end

    embed = resolve_clip("https://clips.test/v/abcd1234")

    assert_equal :failed, embed.metadata_status
    assert_equal false, embed.metadata_retryable?
    assert_nil embed.title
    assert_equal CLIP_EMBED, embed.embed_url
  end

  def test_thumbnail_hosts_are_allowlisted
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |_uri|
      [200, payload.merge("thumbnail_url" => "https://evil.example/a.jpg").to_json]
    end

    embed = resolve_clip("https://clips.test/v/abcd1234")

    assert_nil embed.thumbnail_url
    assert_equal "Clip title", embed.title
    assert_equal :fetched, embed.metadata_status
    assert_equal false, embed.metadata_retryable?
  end

  def test_endpoint_must_be_a_public_https_name
    [
      "http://oembed.clips.test/oembed",
      "https://127.0.0.1/oembed",
      "https://user@oembed.clips.test/oembed",
      "https://oembed.clips.test:8443/oembed",
      "javascript:alert(1)"
    ].each do |endpoint|
      assert_raises(RecordingStudio::ExternalEmbed::DefinitionError, endpoint) do
        define_clip(endpoint)
      end
    end
  end

  def payload
    {
      "type" => "rich",
      "title" => "Clip title",
      "author_name" => "Ada",
      "author_url" => "https://clips.test/ada",
      "thumbnail_url" => "https://img.clips.test/a.jpg",
      "html" => "<iframe src=\"https://evil.example/embed\"></iframe><script>alert(1)</script>"
    }
  end

  def resolve_clip(url)
    RecordingStudio::ExternalEmbed.with_providers(define_clip("https://oembed.clips.test/oembed")) do
      RecordingStudio::ExternalEmbed.resolve(url)
    end
  end

  def define_clip(endpoint)
    RecordingStudio::ExternalEmbed::Provider.define(:clip) do
      host "clips.test"
      label "Clip"
      embed_host "play.clips.test"
      embeds_as "https://play.clips.test/e/{id}"
      canonical "https://clips.test/v/{id}"
      oembed endpoint: endpoint, thumbnail_hosts: ["img.clips.test"]
      match content_type: :video, aspect: Rational(16, 9) do
        path %r{\A/v/(?<id>[a-z0-9]{8})\z}
      end
    end
  end

  def define_plain_clip
    RecordingStudio::ExternalEmbed::Provider.define(:clip) do
      host "clips.test"
      label "Clip"
      embed_host "play.clips.test"
      embeds_as "https://play.clips.test/e/{id}"
      canonical "https://clips.test/v/{id}"
      match content_type: :video, aspect: Rational(16, 9) do
        path %r{\A/v/(?<id>[a-z0-9]{8})\z}
      end
    end
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
