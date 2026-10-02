# frozen_string_literal: true

require "test_helper"
require "json"

class ExternalEmbedOembedTest < Minitest::Test
  def setup
    @calls = []
    RecordingStudio::ExternalEmbed.configuration.resolver = ->(_host) { ["1.1.1.1"] }
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |uri|
      @calls << uri
      [200, payload.to_json]
    end
  end

  def teardown
    RecordingStudio::ExternalEmbed.configuration.http = nil
    RecordingStudio::ExternalEmbed.configuration.resolver = nil
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

    assert_equal "https://play.clips.test/e/abcd1234", embed.embed_url
    assert_nil embed.title
  end

  def test_a_mixed_public_and_private_answer_fails_closed
    RecordingStudio::ExternalEmbed.configuration.resolver = ->(_host) { ["1.1.1.1", "10.0.0.1"] }
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |_uri|
      flunk "any private answer must block the request"
    end

    embed = resolve_clip("https://clips.test/v/abcd1234")

    assert_nil embed.title
    assert_equal true, embed.supported?
  end

  def test_a_failed_oembed_response_keeps_the_constructed_embed
    RecordingStudio::ExternalEmbed.configuration.http = ->(_uri) { [500, "nope"] }

    embed = resolve_clip("https://clips.test/v/abcd1234")

    assert_equal "https://play.clips.test/e/abcd1234", embed.embed_url
    assert_nil embed.title
    assert_nil embed.thumbnail_url
  end

  def test_thumbnail_hosts_are_allowlisted
    RecordingStudio::ExternalEmbed.configuration.http = lambda do |_uri|
      [200, payload.merge("thumbnail_url" => "https://evil.example/a.jpg").to_json]
    end

    embed = resolve_clip("https://clips.test/v/abcd1234")

    assert_nil embed.thumbnail_url
    assert_equal "Clip title", embed.title
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
end
