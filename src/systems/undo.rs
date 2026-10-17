use bevy::prelude::*;

use crate::components::GridPosition;
use crate::resources::ActionHistory;

/// Restores the previous completed action when the player presses Z.
pub fn undo_system(
    keyboard: Res<ButtonInput<KeyCode>>,
    mut action_history: ResMut<ActionHistory>,
    mut entities: Query<(&mut GridPosition, &mut Transform)>,
) {
    if !keyboard.just_pressed(KeyCode::KeyZ) {
        return;
    }

    let Some(compensation) = action_history.pop_last() else {
        return;
    };

    for snapshot in compensation.snapshots {
        if let Ok((mut grid_position, mut transform)) = entities.get_mut(snapshot.entity) {
            *grid_position = snapshot.grid_position;
            *transform = snapshot.transform;
        }
    }
}
