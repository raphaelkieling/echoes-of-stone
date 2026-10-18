use bevy::prelude::*;

use crate::components::{GridPosition, InteractiveObject, InteractiveObjectKind, Target};
use crate::resources::{ActionHistory, LevelProgress, PlayerSelection};
use crate::systems::level_spawner::{spawn_level_contents, LevelEntity, LevelHandle};

pub const BASE_CAMERA_SCALE: f32 = 0.68;
const TRANSITION_DURATION: f32 = 0.65;
const TRANSITION_MAX_ALPHA: f32 = 0.32;
const TRANSITION_ZOOM_STRENGTH: f32 = 0.05;

#[derive(Event, Clone, Copy, Debug)]
pub struct LevelWin;

#[derive(Resource, Default)]
pub struct LevelTransition {
    active: bool,
    elapsed: f32,
    midpoint_reached: bool,
    advance_requested: bool,
}

impl LevelTransition {
    pub fn is_active(&self) -> bool {
        self.active
    }

    pub fn reset(&mut self) {
        self.active = false;
        self.elapsed = 0.0;
        self.midpoint_reached = false;
        self.advance_requested = false;
    }
}

#[derive(Component)]
pub struct TransitionOverlay;

pub fn setup_transition_overlay(mut commands: Commands) {
    commands.spawn((
        Node {
            position_type: PositionType::Absolute,
            left: Val::Px(0.0),
            top: Val::Px(0.0),
            width: Val::Percent(100.0),
            height: Val::Percent(100.0),
            ..default()
        },
        BackgroundColor(Color::srgba(0.0, 0.0, 0.0, 0.0)),
        ZIndex(100),
        TransitionOverlay,
    ));
}

/// Starts a short fade/zoom only when another level is available.
pub fn begin_level_transition_system(
    mut level_wins: EventReader<LevelWin>,
    progress: Res<LevelProgress>,
    mut transition: ResMut<LevelTransition>,
) {
    if level_wins.read().next().is_none()
        || transition.active
        || progress.current_index + 1 >= progress.levels.len()
    {
        return;
    }

    transition.active = true;
    transition.elapsed = 0.0;
    transition.midpoint_reached = false;
    transition.advance_requested = false;
}

/// Fades the screen and applies a tiny camera zoom pulse around the level swap.
pub fn animate_level_transition_system(
    time: Res<Time>,
    mut transition: ResMut<LevelTransition>,
    mut cameras: Query<&mut Projection, With<Camera2d>>,
    mut overlays: Query<&mut BackgroundColor, With<TransitionOverlay>>,
) {
    if transition.active {
        transition.elapsed += time.delta_secs();
        let progress = (transition.elapsed / TRANSITION_DURATION).clamp(0.0, 1.0);
        let pulse = 0.5 * (1.0 - (std::f32::consts::TAU * progress).cos());

        for mut projection in &mut cameras {
            if let Projection::Orthographic(orthographic) = &mut *projection {
                orthographic.scale = BASE_CAMERA_SCALE * (1.0 - TRANSITION_ZOOM_STRENGTH * pulse);
            }
        }
        for mut background in &mut overlays {
            background.0 = Color::srgba(0.0, 0.0, 0.0, TRANSITION_MAX_ALPHA * pulse);
        }

        if progress >= 0.5 && !transition.midpoint_reached {
            transition.midpoint_reached = true;
            transition.advance_requested = true;
        }
        if progress >= 1.0 {
            transition.active = false;
        }
    } else {
        for mut projection in &mut cameras {
            if let Projection::Orthographic(orthographic) = &mut *projection {
                orthographic.scale = BASE_CAMERA_SCALE;
            }
        }
        for mut background in &mut overlays {
            background.0 = Color::srgba(0.0, 0.0, 0.0, 0.0);
        }
    }
}

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
    mut transition: ResMut<LevelTransition>,
    mut progress: ResMut<LevelProgress>,
    mut level_handle: ResMut<LevelHandle>,
    mut action_history: ResMut<ActionHistory>,
    mut player_selection: ResMut<PlayerSelection>,
    level_entities: Query<Entity, With<LevelEntity>>,
    asset_server: Res<AssetServer>,
    mut atlas_layouts: ResMut<Assets<TextureAtlasLayout>>,
) {
    if !transition.advance_requested {
        return;
    }
    transition.advance_requested = false;

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
