use bevy::prelude::*;

#[derive(Resource, Default)]
pub struct PlayerSelection {
    pub active_player: Option<Entity>,
}
