use bevy::prelude::*;

use crate::components::{Floor, GridPosition, InteractiveObject, Player, PlayerClass, Wall};
use crate::resources::{ActionCompensation, ActionHistory, EntitySnapshot};
use crate::systems::{level_spawner::TILE_SIZE, PlayerMoveEvent};

type CellQuery<'w, 's> = Query<
    'w,
    's,
    (
        Entity,
        &'static GridPosition,
        Option<&'static Wall>,
        Option<&'static Floor>,
        Option<&'static InteractiveObject>,
        Option<&'static Player>,
        Option<&'static Transform>,
    ),
>;

/// Resolves movement according to the active character's ability.
/// Dwarves push contiguous chains; wizards swap with the first object in a ray.
pub fn character_movement_system(
    mut move_events: EventReader<PlayerMoveEvent>,
    mut action_history: ResMut<ActionHistory>,
    mut queries: ParamSet<(
        Query<(Entity, &mut GridPosition, &mut Transform, &Player)>,
        CellQuery,
        Query<(&mut GridPosition, &mut Transform), With<InteractiveObject>>,
    )>,
) {
    for PlayerMoveEvent { player, direction } in move_events.read().copied() {
        let (player_before, class) = {
            let mut players = queries.p0();
            let Ok((entity, position, transform, player_component)) = players.get_mut(player)
            else {
                continue;
            };
            (
                EntitySnapshot {
                    entity,
                    grid_position: *position,
                    transform: transform.clone(),
                },
                player_component.class,
            )
        };

        let destination = offset(player_before.grid_position, direction);
        if !can_occupy(destination, player, &queries.p1()) {
            continue;
        }

        let mut snapshots = vec![player_before.clone()];
        let player_destination = match class {
            PlayerClass::Dwarf | PlayerClass::Warrior => {
                let push_distance = if class == PlayerClass::Warrior { 2 } else { 1 };
                let Some(chain) = collect_push_chain(destination, direction, player, &queries.p1())
                else {
                    continue;
                };

                if chain.is_empty() {
                    destination
                } else {
                    let last_object_position = chain.last().unwrap().grid_position;
                    if !has_clear_push_path(
                        last_object_position,
                        direction,
                        push_distance,
                        player,
                        &queries.p1(),
                    ) {
                        continue;
                    }

                    snapshots.extend(chain.iter().cloned());
                    // Preserve the chain while moving each object by the class's push distance.
                    let displacement = direction * push_distance;
                    for object in chain.iter().rev() {
                        let mut objects = queries.p2();
                        let Ok((mut position, mut transform)) = objects.get_mut(object.entity)
                        else {
                            continue;
                        };
                        translate(&mut position, &mut transform, displacement);
                    }
                    destination
                }
            }
            PlayerClass::Wizard => {
                if let Some(object) =
                    first_object_in_ray(destination, direction, player, &queries.p1())
                {
                    snapshots.push(object.clone());
                    let mut objects = queries.p2();
                    let Ok((mut position, mut transform)) = objects.get_mut(object.entity) else {
                        continue;
                    };
                    set_position(&mut position, &mut transform, player_before.grid_position);
                    object.grid_position
                } else {
                    destination
                }
            }
        };

        {
            let mut players = queries.p0();
            let Ok((_, mut position, mut transform, _)) = players.get_mut(player) else {
                continue;
            };
            set_position(&mut position, &mut transform, player_destination);
        }
        action_history.record(ActionCompensation { snapshots });
    }
}

fn has_clear_push_path(
    last_object_position: GridPosition,
    direction: IVec2,
    distance: i32,
    player: Entity,
    cells: &CellQuery<'_, '_>,
) -> bool {
    (1..=distance).all(|step| {
        let position = offset(last_object_position, direction * step);
        can_occupy(position, player, cells)
            && !cells.iter().any(|(_, cell_position, _, _, object, _, _)| {
                object.is_some() && *cell_position == position
            })
    })
}

fn collect_push_chain(
    first_position: GridPosition,
    direction: IVec2,
    player: Entity,
    cells: &CellQuery<'_, '_>,
) -> Option<Vec<EntitySnapshot>> {
    let mut chain = Vec::new();
    let mut position = first_position;

    loop {
        if !can_occupy(position, player, cells) {
            return None;
        }

        let object =
            cells
                .iter()
                .find_map(|(entity, cell_position, _, _, interactive, _, transform)| {
                    (interactive.is_some() && *cell_position == position).then(|| EntitySnapshot {
                        entity,
                        grid_position: *cell_position,
                        transform: transform
                            .expect("interactive objects must have a Transform")
                            .clone(),
                    })
                });

        let Some(object) = object else {
            return Some(chain);
        };
        chain.push(object);
        position = offset(position, direction);
    }
}

fn first_object_in_ray(
    first_position: GridPosition,
    direction: IVec2,
    player: Entity,
    cells: &CellQuery<'_, '_>,
) -> Option<EntitySnapshot> {
    let mut position = first_position;
    loop {
        if !can_occupy(position, player, cells) {
            return None;
        }

        if let Some(object) =
            cells
                .iter()
                .find_map(|(entity, cell_position, _, _, interactive, _, transform)| {
                    (interactive.is_some() && *cell_position == position).then(|| EntitySnapshot {
                        entity,
                        grid_position: *cell_position,
                        transform: transform
                            .expect("interactive objects must have a Transform")
                            .clone(),
                    })
                })
        {
            return Some(object);
        }

        // Floors bound the ray, so it ends at walls or the edge of the map.
        position = offset(position, direction);
    }
}

fn can_occupy(position: GridPosition, moving_player: Entity, cells: &CellQuery<'_, '_>) -> bool {
    let mut has_floor = false;
    for (entity, cell_position, wall, floor, _, character, _) in cells.iter() {
        if *cell_position != position {
            continue;
        }
        has_floor |= floor.is_some();
        if wall.is_some() || (character.is_some() && entity != moving_player) {
            return false;
        }
    }
    has_floor
}

fn offset(position: GridPosition, direction: IVec2) -> GridPosition {
    GridPosition {
        x: position.x + direction.x,
        y: position.y + direction.y,
    }
}

fn translate(position: &mut GridPosition, transform: &mut Transform, displacement: IVec2) {
    set_position(position, transform, offset(*position, displacement));
}

fn set_position(position: &mut GridPosition, transform: &mut Transform, target: GridPosition) {
    let delta_x = target.x - position.x;
    let delta_y = target.y - position.y;
    *position = target;
    transform.translation += Vec3::new(delta_x as f32 * TILE_SIZE, delta_y as f32 * TILE_SIZE, 0.0);
}
