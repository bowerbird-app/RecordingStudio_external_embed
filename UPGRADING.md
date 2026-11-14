# Upgrading

This gem requires `recording_studio` 6.1.0 or newer (`>= 6.1.0` in the gemspec), Rails `~> 8.1.0`, and Ruby 3.3 or newer.

The dummy host pins Recording Studio `v6.10.0`, Flatpack `v0.1.366`, Accessible `v0.37.0`, Trashable `v0.14.1`, Cache `v0.6.3`, Root Switchable `v0.15.0`, and Metrics `v0.8.0`. Those tags declare `recording_studio` 6.1 or newer, so the dummy does not rewrite gemspec requirements.

Hosts on an older Recording Studio core need to:

1. Upgrade `recording_studio` to 6.1.0 or newer (6.10.0 matches this dummy). Recording Studio 6.9 and newer also need the `root_recording_id` column on `recording_studio_events`. Copy `20261114090000_add_root_recording_id_to_recording_studio_events` from core and migrate.
2. Run `bundle update recording_studio recording_studio_external_embed`.
3. Follow Recording Studio upgrade notes in that gem before expecting this addon to boot.

`RecordingStudio::ExternalEmbed.configuration.layout` defaults to nil. Nil uses the host's `RecordingStudio.configuration.layout`, then `recording_studio/default_layout`. Set a layout name, `false`, or a `controller:` callable when this engine should use a different shell.

Recording Studio 6.5 and newer refuses `RecordingStudio.record!` until the host sets `config.authorize_write` and supplies an actor. The dummy initializer allows a write when `Current.actor` is present.

Root Switchable 0.12 and newer refuses the mounted switch page unless the signed-in actor has Recording Studio Accessible `:view` on the current root. The dummy seeds that grant for the admin user.
