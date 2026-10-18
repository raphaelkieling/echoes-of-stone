use bevy::prelude::*;

use crate::components::{GridMovementTween, GridPosition};
use crate::resources::ActionHistory;
use crate::systems::LevelTransition;

/// Restores the previous completed action when the player presses Z.
pub fn undo_system(
    mut commands: Commands,
    keyboard: Res<ButtonInput<KeyCode>>,
    mut action_history: ResMut<ActionHistory>,
    mut entities: Query<(Entity, &mut GridPosition, &Transform)>,
    transition: Res<LevelTransition>,
) {
    if transition.is_active() || !keyboard.just_pressed(KeyCode::KeyZ) {
        return;
    }

    let Some(compensation) = action_history.pop_last() else {
        return;
    };

    for snapshot in compensation.snapshots {
        if let Ok((entity, mut grid_position, transform)) = entities.get_mut(snapshot.entity) {
            let distance = (snapshot.grid_position.x - grid_position.x)
                .abs()
                .max((snapshot.grid_position.y - grid_position.y).abs())
                as u32;
            commands.entity(entity).insert(GridMovementTween::new(
                transform.translation,
                snapshot.transform.translation,
                distance,
            ));
            *grid_position = snapshot.grid_position;
        }
    }
}
