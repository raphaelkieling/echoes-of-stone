use bevy::prelude::*;

use crate::components::{GridPosition, InteractiveObject, InteractiveObjectKind, Player, Wall};
use crate::resources::{ActionCompensation, ActionHistory, EntitySnapshot};
use crate::systems::{level_spawner::TILE_SIZE, PlayerMoveEvent};

/// Resolves movement into boxes after the player requests a grid step.
pub fn interactive_object_box_system(
    mut move_events: EventReader<PlayerMoveEvent>,
    mut action_history: ResMut<ActionHistory>,
    mut position_queries: ParamSet<(
        Query<(Entity, &mut GridPosition, &mut Transform), With<Player>>,
        Query<&GridPosition, With<Wall>>,
        Query<(Entity, &GridPosition, &InteractiveObject), With<InteractiveObject>>,
        Query<(&mut GridPosition, &mut Transform), With<InteractiveObject>>,
    )>,
) {
    for PlayerMoveEvent(direction) in move_events.read().copied() {
        let player_before = {
            let mut players = position_queries.p0();
            let Ok((entity, position, transform)) = players.get_single_mut() else {
                continue;
            };
            EntitySnapshot {
                entity,
                grid_position: *position,
                transform: transform.clone(),
            }
        };

        let destination = offset(player_before.grid_position, direction);
        if occupied_by_wall(destination, &position_queries.p1()) {
            continue;
        }

        let box_entity = position_queries
            .p2()
            .iter()
            .find_map(|(entity, position, object)| {
                (object.kind == InteractiveObjectKind::Box && *position == destination)
                    .then_some(entity)
            });

        let mut snapshots = vec![player_before];

        if let Some(box_entity) = box_entity {
            let box_destination = offset(destination, direction);
            let destination_blocked = occupied_by_wall(box_destination, &position_queries.p1())
                || position_queries
                    .p2()
                    .iter()
                    .any(|(_, position, _)| *position == box_destination);

            if destination_blocked {
                continue;
            }

            let mut boxes = position_queries.p3();
            let Ok((mut box_position, mut box_transform)) = boxes.get_mut(box_entity) else {
                continue;
            };
            snapshots.push(EntitySnapshot {
                entity: box_entity,
                grid_position: *box_position,
                transform: box_transform.clone(),
            });
            move_entity(&mut box_position, &mut box_transform, direction);
        }

        let mut players = position_queries.p0();
        let Ok((_, mut player_position, mut player_transform)) = players.get_single_mut() else {
            continue;
        };
        move_entity(&mut player_position, &mut player_transform, direction);
        action_history.record(ActionCompensation { snapshots });
    }
}

fn offset(position: GridPosition, direction: IVec2) -> GridPosition {
    GridPosition {
        x: position.x + direction.x,
        y: position.y + direction.y,
    }
}

fn occupied_by_wall(position: GridPosition, walls: &Query<&GridPosition, With<Wall>>) -> bool {
    walls.iter().any(|wall_position| *wall_position == position)
}

fn move_entity(position: &mut GridPosition, transform: &mut Transform, direction: IVec2) {
    *position = offset(*position, direction);
    transform.translation += Vec3::new(
        direction.x as f32 * TILE_SIZE,
        direction.y as f32 * TILE_SIZE,
        0.0,
    );
}
