use bevy::prelude::*;

mod components;
mod resources;
mod screens;
mod systems;

fn main() {
    let levels = systems::load_levels();

    let mut app = App::new();
    app.add_plugins(DefaultPlugins.set(ImagePlugin::default_nearest()))
        .insert_resource(systems::LevelHandle::default())
        .insert_resource(resources::LevelProgress::new(levels))
        .init_resource::<resources::ActionHistory>()
        .init_resource::<resources::PlayerSelection>()
        .init_resource::<systems::PlayerOutlineTextures>()
        .init_resource::<systems::LevelTransition>()
        .add_systems(Startup, (setup_camera, systems::setup_transition_overlay))
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
                .chain()
                .run_if(screens::gameplay_is_active),
        )
        .add_plugins(screens::GameScreensPlugin);

    app.run();
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
