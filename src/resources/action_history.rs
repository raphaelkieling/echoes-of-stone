use bevy::prelude::*;

use crate::components::GridPosition;

/// The state needed to restore one entity before an action changed it.
#[derive(Clone)]
pub struct EntitySnapshot {
    pub entity: Entity,
    pub grid_position: GridPosition,
    pub transform: Transform,
}

/// Reverses one completed game action.
pub struct ActionCompensation {
    pub snapshots: Vec<EntitySnapshot>,
}

/// Stack of compensations. The newest action is undone first.
#[derive(Resource, Default)]
pub struct ActionHistory {
    compensations: Vec<ActionCompensation>,
}

impl ActionHistory {
    pub fn record(&mut self, compensation: ActionCompensation) {
        self.compensations.push(compensation);
    }

    pub fn pop_last(&mut self) -> Option<ActionCompensation> {
        self.compensations.pop()
    }
}
