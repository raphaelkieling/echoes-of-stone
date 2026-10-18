use bevy::prelude::*;

mod components;
mod resources;
mod systems;

fn main() {
    let levels = systems::load_levels();
    let first_level = levels.first().cloned().unwrap_or_default();

    App::new()
        .add_plugins(DefaultPlugins.set(ImagePlugin::default_nearest()))
        // Resources needed by a system must exist before Bevy builds that system.
        // Startup systems can run in parallel, so inserting this from another
        // startup system is too late for `spawn_level_system`.
        .insert_resource(systems::LevelHandle(first_level))
        .insert_resource(resources::LevelProgress::new(levels))
        .init_resource::<resources::ActionHistory>()
        .init_resource::<resources::PlayerSelection>()
        .init_resource::<systems::PlayerOutlineTextures>()
        .init_resource::<systems::LevelTransition>()
        .add_systems(
            Startup,
            (
                setup_camera,
                systems::spawn_level,
                systems::setup_transition_overlay,
            ),
        )
        .add_event::<systems::PlayerMoveEvent>()
        .add_event::<systems::LevelWin>()
        .add_systems(
            Update,
            (
                systems::switch_active_player_system,
                systems::player_movement_system,
                systems::character_movement_system,
                systems::undo_system,
                systems::check_level_win_system,
                systems::begin_level_transition_system,
                systems::animate_level_transition_system,
                systems::advance_level_system,
                systems::spawn_player_outline_system,
                systems::active_player_outline_system,
            )
                .chain(),
        )
        .run();
}

fn setup_camera(mut commands: Commands) {
    commands.spawn((
        Camera2d,
        Projection::Orthographic(OrthographicProjection {
            scale: systems::BASE_CAMERA_SCALE,
            ..OrthographicProjection::default_2d()
        }),
    ));
}
