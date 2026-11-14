# frozen_string_literal: true

require "test_helper"

class RecordingStudioExternalEmbedTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.3.0", RecordingStudio::ExternalEmbed::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, RecordingStudio::ExternalEmbed::Engine
  end

  def test_gemspec_requires_recording_studio_6_1
    gemspec = File.read(File.expand_path("../recording_studio_external_embed.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", ">= 6.1.0"'
    refute_includes gemspec, '"recording_studio", "~> 4'
  end

  def test_gemspec_excludes_cursor_config
    spec = Gem::Specification.load(File.expand_path("../recording_studio_external_embed.gemspec", __dir__))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files, "gemspec must not package .cursor/ (got #{cursor_files.inspect})"
  end

  def test_cursor_environment_is_repo_managed_without_snapshot
    path = File.expand_path("../.cursor/environment.json", __dir__)
    json = JSON.parse(File.read(path))

    assert_equal "recording-studio-external-embed", json["name"]
    assert_equal ".cursor/install.sh", json["install"]
    assert_equal ".cursor/start.sh", json["start"]
    refute json.key?("snapshot"), "snapshot pins a Personal build and skips install"
    refute json.key?("agentCanUpdateSnapshot")
  end

  def test_cursor_install_still_fetches_skills
    install_script = File.read(File.expand_path("../.cursor/install.sh", __dir__))

    assert_includes install_script, "fetch-skills.sh"
  end

  def test_dummy_gemfile_pins_recording_studio_6_1_and_flatpack
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))
    root_gemfile = File.read(File.expand_path("../Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v6.10.0"'
    assert_includes root_gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v6.10.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.37.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.14.1", require: false'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.15.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_cache", tag: "v0.6.3"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.8.0"'
    assert_includes gemfile, 'tag: "v0.1.366"'
    assert_includes root_gemfile, 'tag: "v0.1.366"'
    refute_includes gemfile, "widen_recording_studio_requirement"
    refute_includes gemfile, "recording_studio/v3.0.0"
    refute_includes gemfile, 'tag: "v0.1.133"'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.5.0"'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.8.0"'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.15.0"'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.17.0"'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.18.0"'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.11.0", require: false'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v6.7.0"'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.31.0"'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.14.0", require: false'
    refute_includes gemfile, 'tag: "v0.1.356"'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v6.1.0"'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.6.0"'
    refute_includes gemfile, 'github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.10.0", require: false'
    refute_includes gemfile, 'tag: "0.3.1"'
  end

  def test_dummy_schema_includes_accessible_depends_on_recording_id
    schema = File.read(File.expand_path("dummy/db/schema.rb", __dir__))
    migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20260911024811_add_depends_on_recording_id_to_recording_studio_accesses.rb",
        __dir__
      )
    )

    assert_includes schema, 't.uuid "depends_on_recording_id"'
    assert_includes schema, "index_recording_studio_accesses_on_depends_on_recording_id"
    assert_includes migration, "add_column :recording_studio_accesses, :depends_on_recording_id, :uuid"
  end

  def test_dummy_schema_includes_accessible_invitations_and_string_roles
    schema = File.read(File.expand_path("dummy/db/schema.rb", __dir__))
    invitation_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_create_recording_studio_access_invitations.rb", __dir__)
    ).sole
    role_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_change_recording_studio_accesses_role_to_string.rb", __dir__)
    ).sole

    assert_includes schema, 'create_table "recording_studio_access_invitations"'
    assert_includes schema, 't.string "role", default: "view", null: false'
    assert_includes File.read(invitation_migration), "create_table :recording_studio_access_invitations"
    assert_includes File.read(role_migration), "change_column :recording_studio_accesses, :role, :string"
  end

  def test_dummy_schema_includes_accessible_audience_tables
    schema = File.read(File.expand_path("dummy/db/schema.rb", __dir__))
    constraints_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_create_recording_studio_access_constraints.rb", __dir__)
    ).sole
    rules_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_create_recording_studio_access_rules.rb", __dir__)
    ).sole

    assert_includes schema, 'create_table "recording_studio_access_constraints"'
    assert_includes schema, 'create_table "recording_studio_access_rules"'
    assert_includes schema, 't.string "allowed_audiences", default: [], null: false, array: true'
    assert_includes File.read(constraints_migration), "create_table :recording_studio_access_constraints"
    assert_includes File.read(rules_migration), "create_table :recording_studio_access_rules"
  end

  def test_dummy_schema_includes_event_root_recording_id
    schema = File.read(File.expand_path("dummy/db/schema.rb", __dir__))
    migration = Dir.glob(
      File.expand_path(
        "dummy/db/migrate/*_add_root_recording_id_to_recording_studio_events.recording_studio.rb",
        __dir__
      )
    ).sole

    assert_includes schema, 't.uuid "root_recording_id", null: false'
    assert_includes schema, "index_rs_events_on_root_and_timeline"
    assert_includes schema, "index_rs_events_on_impersonator_and_occurred_at"
    assert_includes File.read(migration), "add_column :recording_studio_events, :root_recording_id, :uuid"
  end

  def test_gem_does_not_ship_a_database_migration
    assert_empty Dir.glob(File.expand_path("../db/migrate/*.rb", __dir__))
  end

  def test_dummy_app_uses_recording_studio_default_layout
    controller_source = File.read(File.expand_path("dummy/app/controllers/application_controller.rb", __dir__))

    assert_includes controller_source, "recording_studio_layout"
    assert_includes controller_source, 'devise_controller? ? "application"'
    refute_includes controller_source, "UsesDefaultLayout"
    refute_includes controller_source, '"recording_studio/default_layout"'
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))

    default_layout = File.read(
      File.expand_path("dummy/app/views/layouts/recording_studio/default_layout.html.erb", __dir__)
    )
    assert_includes default_layout, "FlatPack::SidebarLayout::Component"
    assert_includes default_layout, 'storage_key: "flat-pack-sidebar-layout"'
    assert_includes default_layout, "h-full overflow-hidden overscroll-none"
    assert_includes default_layout, "flat_pack_page_nav_tag"
    assert_includes default_layout, "FlatPack::PageTitle::Component.new(title: heading, subtitle: subtitle)"
    assert_operator default_layout.index('stylesheet_link_tag "flat_pack/variables"'), :<,
                    default_layout.index('stylesheet_link_tag "flat_pack/application"')
    assert_operator default_layout.index('stylesheet_link_tag "flat_pack/application"'), :<,
                    default_layout.index('stylesheet_link_tag "flat_pack/rich_text"')
    assert_operator default_layout.index('stylesheet_link_tag "flat_pack/rich_text"'), :<,
                    default_layout.index('stylesheet_link_tag "tailwind"')
    refute_includes default_layout, "flex min-h-screen"
    refute_includes default_layout, "seo_image"
    refute_includes default_layout, "body_theme"
    refute_includes default_layout, "page_nav_back_"
  end

  def test_dummy_login_layout_keeps_flatpack_assets_without_tight_main_offset
    application_layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes application_layout, '<html data-theme="rounded">'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/application"'
    assert_operator application_layout.index('stylesheet_link_tag "flat_pack/variables"'), :<,
                    application_layout.index('stylesheet_link_tag "flat_pack/application"')
    assert_operator application_layout.index('stylesheet_link_tag "flat_pack/application"'), :<,
                    application_layout.index('stylesheet_link_tag "flat_pack/rich_text"')
    assert_operator application_layout.index('stylesheet_link_tag "flat_pack/rich_text"'), :<,
                    application_layout.index('stylesheet_link_tag "tailwind"')
    assert_includes application_layout, "javascript_importmap_tags"
    refute File.exist?(File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__))
    assert_includes application_layout, "min-h-screen"
    refute_includes application_layout, "mt-28"
    refute_includes application_layout, "flat_pack_sidebar"
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "../../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}"
    assert_includes tailwind_source, "flatpack-*/app/components/**/*.{rb,erb}"
    assert_includes tailwind_source, "../../../vendor/bundle/**/recording_studio/app/views/**/*.erb"
    assert_includes tailwind_source, "recordingstudio-*/app/views/**/*.erb"
    assert_includes tailwind_source, '@import "../builds/tailwind/gem_sources.css"'
    refute_includes tailwind_source, "@theme"
    refute_includes tailwind_source, ":root {"
    refute_includes tailwind_source, "--color-fp-primary"
  end

  def test_recording_studio_keeps_strict_recordable_declarations_enabled
    initializer_source = File.read(File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__))

    assert_includes initializer_source, "config.require_recordable_declarations = true"
    assert_includes initializer_source, "config.recordable_types = [ \"Workspace\", \"Folder\", \"Page\" ]"
    refute_includes initializer_source, "config.include_children"
    refute_includes initializer_source, "config.features."
    refute_includes initializer_source, "v3"
  end

  def test_dummy_readme_explains_dummy_app_purpose
    readme_source = File.read(File.expand_path("dummy/README.md", __dir__))

    assert_includes readme_source, "This Rails app is the host sandbox for RecordingStudio::ExternalEmbed."
    assert_includes readme_source, "/recording_studio"
    assert_includes readme_source, "redirects to `/`"
    refute_includes readme_source, "flat_pack_sidebar"
  end

  def test_product_readme_explains_the_embed_boundary
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "RecordingStudio::ExternalEmbed"
    assert_includes readme, "RecordingStudioEmbeddable"
    assert_includes readme, "youtube-nocookie.com/embed"
    assert_includes readme, "player.vimeo.com/video"
    assert_includes readme, "vimeo.com/api/oembed.json"
    assert_includes readme, "cache_ttl"
    assert_includes readme, "i.vimeocdn.com"
    assert_includes readme, "Provider.define"
    upgrading = File.read(File.expand_path("../UPGRADING.md", __dir__))
    assert_includes upgrading, "Remove a host registration for `:vimeo`"
    assert_includes upgrading, "config.cache_ttl"
    assert_includes readme, "Rails 8.1, and `recording_studio` 6.1 or newer"
    refute_includes readme, "v0.1.133"
    refute_includes readme, "v3 declarations"
    refute_includes readme, "RecordingStudio v3"
    refute_includes readme, "ExampleService"
    refute_includes readme, "recording_studio/v3.0.0"
  end

  def test_dummy_home_page_renders_an_external_embed
    view_source = File.read(File.expand_path("dummy/app/views/home/index.html.erb", __dir__))

    assert_includes view_source, 'title: "External embeds"'
    assert_includes view_source, "recording_studio_external_embed(url)"
    assert_includes view_source, "demo_embeds"
    assert_includes view_source, "recording_studio_external_embed"
    assert_includes view_source, "FlatPack::Card::Component"
    assert_includes view_source, "dummy_page_nav"
    refute_includes view_source, 'title: "Demo"'
    refute_includes view_source, "FlatPack::Breadcrumb::Component"
  end

  def test_dummy_docs_pages_use_minimal_flatpack_documentation_components
    docs_view_paths = Dir[File.expand_path("dummy/app/views/docs/*.html.erb", __dir__)].reject do |view_path|
      File.basename(view_path).start_with?("_")
    end
    refute_empty docs_view_paths

    docs_view_paths.each do |view_path|
      view_source = File.read(view_path)

      assert_includes view_source, "dummy_page_nav", view_path
      assert_includes view_source, "subtitle:", view_path
      refute_includes view_source, "FlatPack::PageTitle::Component", view_path
      refute_includes view_source, "FlatPack::Card::Component", view_path
      refute_includes view_source, "FlatPack::Breadcrumb::Component", view_path
    end

    methods_view = File.read(File.expand_path("dummy/app/views/docs/methods.html.erb", __dir__))
    assert_includes methods_view, "FlatPack::SectionTitle::Component"
    assert_includes methods_view, "FlatPack::CodeBlock::Component"

    gem_views_view = File.read(File.expand_path("dummy/app/views/docs/gem_views.html.erb", __dir__))
    assert_includes gem_views_view, "FlatPack::Table::Component"
    refute_includes gem_views_view, "FlatPack::List::Component"

    recordable_types_view = File.read(File.expand_path("dummy/app/views/docs/recordable_types.html.erb", __dir__))
    assert_includes recordable_types_view, "FlatPack::List::Component"
    refute_includes recordable_types_view, "v3 parent/root"

    recordings_tree_view = File.read(File.expand_path("dummy/app/views/docs/recordings_tree.html.erb", __dir__))
    assert_includes recordings_tree_view, "FlatPack::Tree::Component"
    refute_includes recordings_tree_view, "Current structure"
    refute_includes recordings_tree_view, "This tree is generated from RecordingStudio::Recording records"
  end

  def test_lockfiles_use_rack_3_2_8_or_newer
    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      spec_line = File.readlines(lockfile).find { |line| line.match?(/\A    rack \(/) }
      version = spec_line[/rack \(([^)]+)\)/, 1]
      assert Gem::Version.new(version) >= Gem::Version.new("3.2.8"), "#{lockfile} rack #{version}"
    end
  end

  def test_lockfiles_keep_the_existing_view_component_pin
    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      spec_line = File.readlines(lockfile).find { |line| line.match?(/\A    view_component \(/) }
      assert_equal "4.19.0", spec_line[/view_component \(([^)]+)\)/, 1], lockfile
    end
  end

  def test_lockfiles_keep_minitest_5
    [File.expand_path("../Gemfile.lock", __dir__), File.expand_path("dummy/Gemfile.lock", __dir__)].each do |lockfile|
      spec_line = File.readlines(lockfile).find { |line| line.match?(/\A    minitest \(/) }
      version = spec_line[/minitest \(([^)]+)\)/, 1]
      assert version.start_with?("5."), "#{lockfile} minitest #{version}"
    end
  end

  def test_template_leftover_docs_and_flatpack_kwargs_shim_are_gone
    root = File.expand_path("..", __dir__)

    refute File.exist?(File.join(root, "UPDATE_SUMMARY.md"))
    refute File.exist?(File.join(root, "MIGRATION_NOTES.md"))
    refute File.exist?(File.join(root, "test/dummy/config/initializers/flatpack_removed_kwargs.rb"))
    refute File.exist?(File.join(root, "test/support/widen_recording_studio_requirement.rb"))
    refute_includes File.read(File.join(root, "test/dummy/config/initializers/recording_studio_root_switchable.rb")),
                    ":application_layout"
  end

  def test_engine_does_not_ship_a_home_view
    refute File.exist?(
      File.expand_path("../app/views/recording_studio/external_embed/home/index.html.erb", __dir__)
    )
  end
end
