use bevy::prelude::*;

mod components;
mod resources;
mod systems;

fn main() {
    App::new()
        .add_plugins(DefaultPlugins)
        // Resources needed by a system must exist before Bevy builds that system.
        // Startup systems can run in parallel, so inserting this from another
        // startup system is too late for `spawn_level_system`.
        .insert_resource(systems::LevelHandle(systems::load_level()))
        .init_resource::<resources::ActionHistory>()
        .add_systems(Startup, (setup_camera, spawn_level_system))
        .add_event::<systems::PlayerMoveEvent>()
        .add_systems(
            Update,
            (
                systems::player_movement_system,
                systems::interactive_object_box_system,
                systems::undo_system,
            )
                .chain(),
        )
        .run();
}

fn setup_camera(mut commands: Commands) {
    commands.spawn(Camera2d);
}

fn spawn_level_system(commands: Commands, level_handle: Res<systems::LevelHandle>) {
    systems::spawn_level(commands, level_handle);
}
