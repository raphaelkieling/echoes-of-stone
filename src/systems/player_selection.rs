use bevy::prelude::*;

use crate::components::Player;
use crate::resources::PlayerSelection;

/// Keeps a valid active player and cycles through all players when G is pressed.
pub fn switch_active_player_system(
    keyboard: Res<ButtonInput<KeyCode>>,
    players: Query<Entity, With<Player>>,
    mut selection: ResMut<PlayerSelection>,
) {
    let mut player_entities: Vec<Entity> = players.iter().collect();
    player_entities.sort_by_key(|entity| entity.to_bits());

    if player_entities.is_empty() {
        selection.active_player = None;
        return;
    }

    let Some(active_index) = player_entities
        .iter()
        .position(|entity| Some(*entity) == selection.active_player)
    else {
        selection.active_player = Some(player_entities[0]);
        return;
    };

    if keyboard.just_pressed(KeyCode::KeyG) {
        let next_index = (active_index + 1) % player_entities.len();
        selection.active_player = Some(player_entities[next_index]);
    }
}
