use bevy::prelude::*;

use crate::components::{GridPosition, InteractiveObject, InteractiveObjectKind, Target};
use crate::resources::{ActionHistory, LevelProgress, PlayerSelection};
use crate::systems::level_spawner::{spawn_level_contents, LevelEntity, LevelHandle};

#[derive(Event, Clone, Copy, Debug)]
pub struct LevelWin;

/// Emits one win event when every box is on a target.
pub fn check_level_win_system(
    mut progress: ResMut<LevelProgress>,
    boxes: Query<(&GridPosition, &InteractiveObject)>,
    targets: Query<&GridPosition, With<Target>>,
    mut level_wins: EventWriter<LevelWin>,
) {
    if progress.win_emitted {
        return;
    }

    let box_positions: Vec<GridPosition> = boxes
        .iter()
        .filter(|(_, object)| object.kind == InteractiveObjectKind::Box)
        .map(|(position, _)| *position)
        .collect();
    let target_positions: Vec<GridPosition> = targets.iter().copied().collect();

    let all_boxes_on_targets = !box_positions.is_empty()
        && target_positions.len() >= box_positions.len()
        && box_positions
            .iter()
            .all(|position| target_positions.contains(position));

    if all_boxes_on_targets {
        progress.win_emitted = true;
        level_wins.send(LevelWin);
    }
}

/// Reuses the level spawner to replace the current map with the next one.
pub fn advance_level_system(
    mut commands: Commands,
    mut level_wins: EventReader<LevelWin>,
    mut progress: ResMut<LevelProgress>,
    mut level_handle: ResMut<LevelHandle>,
    mut action_history: ResMut<ActionHistory>,
    mut player_selection: ResMut<PlayerSelection>,
    level_entities: Query<Entity, With<LevelEntity>>,
    asset_server: Res<AssetServer>,
    mut atlas_layouts: ResMut<Assets<TextureAtlasLayout>>,
) {
    if level_wins.read().next().is_none() {
        return;
    }

    let next_index = progress.current_index + 1;
    let Some(next_level) = progress.levels.get(next_index).cloned() else {
        return;
    };

    for entity in &level_entities {
        commands.entity(entity).despawn();
    }

    progress.current_index = next_index;
    progress.win_emitted = false;
    level_handle.0 = next_level.clone();
    action_history.clear();
    player_selection.active_player = None;

    spawn_level_contents(
        &mut commands,
        &next_level,
        &asset_server,
        &mut atlas_layouts,
    );
}
