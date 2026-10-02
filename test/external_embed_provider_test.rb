# frozen_string_literal: true

require "test_helper"

class ExternalEmbedProviderTest < Minitest::Test
  def test_a_registered_provider_resolves_without_editing_youtube
    embed = RecordingStudio::ExternalEmbed.with_providers(fixture_provider) do
      RecordingStudio::ExternalEmbed.resolve("https://videos.test/v/abcd1234")
    end

    assert_equal true, embed.supported?
    assert_equal :fixture, embed.provider
    assert_equal "abcd1234", embed.external_id
    assert_equal "https://play.videos.test/e/abcd1234", embed.embed_url
    assert_equal "https://videos.test/v/abcd1234", embed.canonical_url
  end

  def test_replacing_providers_removes_the_built_in_youtube_catalog
    result = RecordingStudio::ExternalEmbed.with_providers(fixture_provider, replace: true) do
      RecordingStudio::ExternalEmbed.resolve("https://youtu.be/dQw4w9WgXcQ")
    end

    assert_equal false, result.supported?
    assert_equal :unsupported, result.reason
    restored = RecordingStudio::ExternalEmbed.resolve("https://youtu.be/dQw4w9WgXcQ")
    assert_equal "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ", restored.embed_url
  end

  def test_register_rejects_a_duplicate_host
    provider = fixture_provider
    RecordingStudio::ExternalEmbed.register(provider)

    error = assert_raises(RecordingStudio::ExternalEmbed::Conflict) do
      RecordingStudio::ExternalEmbed.register(fixture_provider)
    end

    assert_equal "provider is already registered", error.message
  ensure
    reset_catalog!
  end

  def test_a_template_cannot_point_the_iframe_at_an_undeclared_host
    error = assert_raises(RecordingStudio::ExternalEmbed::DefinitionError) do
      RecordingStudio::ExternalEmbed::Provider.define(:bad) do
        host "videos.test"
        embeds_as "https://evil.example/e/{id}"
        canonical "https://videos.test/v/{id}"
        match content_type: :video, aspect: Rational(16, 9) do
          path %r{\A/v/(?<id>[a-z0-9]{8})\z}
        end
      end
    end

    assert_equal "template is not a trusted https url", error.message
  end

  def test_freeze_blocks_later_registration
    RecordingStudio::ExternalEmbed.freeze_catalog!

    assert_raises(RecordingStudio::ExternalEmbed::Conflict) do
      RecordingStudio::ExternalEmbed.register(fixture_provider)
    end
  ensure
    reset_catalog!
  end

  def fixture_provider
    RecordingStudio::ExternalEmbed::Provider.define(:fixture) do
      host "videos.test"
      label "Fixture"
      embed_host "play.videos.test"
      embeds_as "https://play.videos.test/e/{id}"
      canonical "https://videos.test/v/{id}"
      match content_type: :video, aspect: Rational(16, 9) do
        path %r{\A/v/(?<id>[a-z0-9]{8})\z}
      end
    end
  end

  def reset_catalog!
    RecordingStudio::ExternalEmbed.instance_variable_set(:@providers, nil)
    RecordingStudio::ExternalEmbed.instance_variable_set(:@catalog, nil)
    RecordingStudio::ExternalEmbed.instance_variable_set(:@catalog_frozen, false)
  end
end
