use bevy::prelude::*;

/// A single grid step requested by the player.
#[derive(Event, Clone, Copy, Debug)]
pub struct PlayerMoveEvent(pub IVec2);

pub fn player_movement_system(
    keyboard: Res<ButtonInput<KeyCode>>,
    mut move_events: EventWriter<PlayerMoveEvent>,
) {
    if keyboard.just_pressed(KeyCode::KeyZ) {
        return;
    }

    let direction = if keyboard.just_pressed(KeyCode::KeyW)
        || keyboard.just_pressed(KeyCode::ArrowUp)
    {
        Some(IVec2::Y)
    } else if keyboard.just_pressed(KeyCode::KeyS) || keyboard.just_pressed(KeyCode::ArrowDown) {
        Some(IVec2::NEG_Y)
    } else if keyboard.just_pressed(KeyCode::KeyA) || keyboard.just_pressed(KeyCode::ArrowLeft) {
        Some(IVec2::NEG_X)
    } else if keyboard.just_pressed(KeyCode::KeyD) || keyboard.just_pressed(KeyCode::ArrowRight) {
        Some(IVec2::X)
    } else {
        None
    };

    if let Some(direction) = direction {
        move_events.send(PlayerMoveEvent(direction));
    }
}
