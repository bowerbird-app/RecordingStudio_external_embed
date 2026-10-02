# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/tailwind_gem_sources")

class TailwindGemSourcesTest < ActiveSupport::TestCase
  test "generated sources scan the installed flatpack card and the default layout" do
    css = TailwindGemSources.css
    paths = css.scan(/@source "([^"]+)"/).flatten.flat_map { |glob| Dir.glob(glob) }

    assert paths.any? { |path| path.end_with?("flat_pack/card/component.rb") }
    assert paths.any? { |path| path.end_with?("layouts/recording_studio/default_layout.html.erb") }
    refute_includes css, "@theme"
    refute_includes css, "--color-fp-primary"
  end

  test "built tailwind stylesheet includes flatpack and layout utilities" do
    built = Rails.root.join("app/assets/builds/tailwind.css").read

    assert_includes built, "border-2"
    assert_includes built, "max-w-6xl"
    assert_includes built, "alert-success-background-color"
  end
end
