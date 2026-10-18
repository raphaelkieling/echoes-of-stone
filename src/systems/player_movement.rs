use bevy::prelude::*;

use crate::resources::PlayerSelection;
use crate::systems::LevelTransition;

/// A single grid step requested by the player.
#[derive(Event, Clone, Copy, Debug)]
pub struct PlayerMoveEvent {
    pub player: Entity,
    pub direction: IVec2,
}

pub fn player_movement_system(
    keyboard: Res<ButtonInput<KeyCode>>,
    mut move_events: EventWriter<PlayerMoveEvent>,
    selection: Res<PlayerSelection>,
    transition: Res<LevelTransition>,
) {
    if transition.is_active()
        || keyboard.just_pressed(KeyCode::KeyG)
        || selection.active_player.is_none()
    {
        return;
    }

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
        if let Some(player) = selection.active_player {
            move_events.send(PlayerMoveEvent { player, direction });
        }
    }
}
