use bevy::prelude::*;

use crate::components::{
    BoxObject, Floor, GridPosition, InteractiveObject, Player, PlayerClass, Wall,
};
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
/// Dwarves and warriors push chains; wizards swap with a distant object, while
/// telekinetics push the first object in their direction without moving to it.
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
                let Some(chain) = collect_push_chain(destination, direction, player, &queries.p1())
                else {
                    continue;
                };

                if chain.is_empty() {
                    destination
                } else {
                    let last_object_position = chain.last().unwrap().grid_position;
                    let push_distance = if class == PlayerClass::Warrior {
                        max_push_distance(last_object_position, direction, player, &queries.p1())
                    } else {
                        1
                    };
                    if push_distance == 0
                        || !has_clear_push_path(
                            last_object_position,
                            direction,
                            push_distance,
                            player,
                            &queries.p1(),
                        )
                    {
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
            PlayerClass::Telekinetic => {
                if let Some(object) =
                    first_object_in_ray(destination, direction, player, &queries.p1())
                {
                    if !has_clear_push_path(
                        object.grid_position,
                        direction,
                        1,
                        player,
                        &queries.p1(),
                    ) {
                        continue;
                    }

                    snapshots.push(object.clone());
                    let mut objects = queries.p2();
                    let Ok((mut position, mut transform)) = objects.get_mut(object.entity) else {
                        continue;
                    };
                    translate(&mut position, &mut transform, direction);
                }
                destination
            }
            PlayerClass::Sorcerer => {
                if let Some(object) =
                    first_object_in_ray(destination, direction, player, &queries.p1())
                {
                    // A directly adjacent object cannot retreat without colliding with its owner.
                    if object.grid_position == destination {
                        continue;
                    }

                    let recoil_destination = offset(object.grid_position, -direction);
                    if recoil_destination == destination
                        || !can_push_into(recoil_destination, player, &queries.p1())
                    {
                        continue;
                    }

                    snapshots.push(object.clone());
                    let mut objects = queries.p2();
                    let Ok((mut position, mut transform)) = objects.get_mut(object.entity) else {
                        continue;
                    };
                    translate(&mut position, &mut transform, -direction);
                }
                destination
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
        can_push_into(position, player, cells)
    })
}

fn max_push_distance(
    last_object_position: GridPosition,
    direction: IVec2,
    player: Entity,
    cells: &CellQuery<'_, '_>,
) -> i32 {
    let mut distance = 0;
    while can_push_into(
        offset(last_object_position, direction * (distance + 1)),
        player,
        cells,
    ) {
        distance += 1;
    }
    distance
}

fn can_push_into(position: GridPosition, player: Entity, cells: &CellQuery<'_, '_>) -> bool {
    can_occupy(position, player, cells)
        && !cells.iter().any(|(_, cell_position, _, _, object, _, _)| {
            object.is_some() && *cell_position == position
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
    for (entity, cell_position, wall, floor, interactive, character, _) in cells.iter() {
        if *cell_position != position {
            continue;
        }
        has_floor |= floor.is_some();
        if wall.is_some()
            || (character.is_some() && entity != moving_player && interactive.is_none())
        {
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::components::Floor;

    fn test_app() -> App {
        let mut app = App::new();
        app.add_event::<PlayerMoveEvent>()
            .init_resource::<ActionHistory>()
            .add_systems(Update, character_movement_system);
        app
    }

    fn position(x: i32, y: i32) -> GridPosition {
        GridPosition { x, y }
    }

    fn spawn_floor(app: &mut App, x: i32, y: i32) {
        app.world_mut().spawn((Floor, position(x, y)));
    }

    fn spawn_row(app: &mut App, x_start: i32, x_end: i32, y: i32) {
        for x in x_start..=x_end {
            spawn_floor(app, x, y);
        }
    }

    fn spawn_player(app: &mut App, x: i32, y: i32, class: PlayerClass) -> Entity {
        app.world_mut()
            .spawn((
                Player { class },
                InteractiveObject,
                position(x, y),
                Transform::from_xyz(x as f32 * TILE_SIZE, y as f32 * TILE_SIZE, 3.0),
            ))
            .id()
    }

    fn spawn_box(app: &mut App, x: i32, y: i32) -> Entity {
        app.world_mut()
            .spawn((
                InteractiveObject,
                BoxObject,
                position(x, y),
                Transform::from_xyz(x as f32 * TILE_SIZE, y as f32 * TILE_SIZE, 2.0),
            ))
            .id()
    }

    fn spawn_generic_interactive_object(app: &mut App, x: i32, y: i32) -> Entity {
        app.world_mut()
            .spawn((
                InteractiveObject,
                position(x, y),
                Transform::from_xyz(x as f32 * TILE_SIZE, y as f32 * TILE_SIZE, 2.0),
            ))
            .id()
    }

    fn spawn_wall(app: &mut App, x: i32, y: i32) {
        app.world_mut()
            .spawn((Wall, position(x, y), Transform::default()));
    }

    fn move_player(app: &mut App, player: Entity, direction: IVec2) {
        app.world_mut()
            .resource_mut::<Events<PlayerMoveEvent>>()
            .send(PlayerMoveEvent { player, direction });
        app.update();
    }

    fn position_of(app: &mut App, entity: Entity) -> GridPosition {
        let world = app.world_mut();
        let mut query = world.query::<&GridPosition>();
        *query
            .get(world, entity)
            .expect("entity should have a grid position")
    }

    fn translation_of(app: &mut App, entity: Entity) -> Vec3 {
        let world = app.world_mut();
        let mut query = world.query::<&Transform>();
        query
            .get(world, entity)
            .expect("entity should have a transform")
            .translation
    }

    fn history_snapshot_count(app: &mut App) -> usize {
        app.world_mut()
            .resource_mut::<ActionHistory>()
            .pop_last()
            .map_or(0, |action| action.snapshots.len())
    }

    #[test]
    fn dwarf_moves_one_tile_on_empty_floor() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 4, 0);
        let dwarf = spawn_player(&mut app, 1, 0, PlayerClass::Dwarf);

        move_player(&mut app, dwarf, IVec2::X);

        assert_eq!(position_of(&mut app, dwarf), position(2, 0));
        assert_eq!(translation_of(&mut app, dwarf).x, 2.0 * TILE_SIZE);
        assert_eq!(history_snapshot_count(&mut app), 1);
    }

    #[test]
    fn dwarf_pushes_one_box_one_tile() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 4, 0);
        let dwarf = spawn_player(&mut app, 1, 0, PlayerClass::Dwarf);
        let box_entity = spawn_box(&mut app, 2, 0);

        move_player(&mut app, dwarf, IVec2::X);

        assert_eq!(position_of(&mut app, dwarf), position(2, 0));
        assert_eq!(position_of(&mut app, box_entity), position(3, 0));
        assert_eq!(translation_of(&mut app, box_entity).x, 3.0 * TILE_SIZE);
        assert_eq!(history_snapshot_count(&mut app), 2);
    }

    #[test]
    fn dwarf_pushes_any_interactive_object_without_a_box_marker() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 4, 0);
        let dwarf = spawn_player(&mut app, 1, 0, PlayerClass::Dwarf);
        let object = spawn_generic_interactive_object(&mut app, 2, 0);

        move_player(&mut app, dwarf, IVec2::X);

        assert_eq!(position_of(&mut app, dwarf), position(2, 0));
        assert_eq!(position_of(&mut app, object), position(3, 0));
        assert_eq!(history_snapshot_count(&mut app), 2);
    }

    #[test]
    fn dwarf_pushes_a_contiguous_chain_together() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 5, 0);
        let dwarf = spawn_player(&mut app, 1, 0, PlayerClass::Dwarf);
        let first_box = spawn_box(&mut app, 2, 0);
        let second_box = spawn_box(&mut app, 3, 0);

        move_player(&mut app, dwarf, IVec2::X);

        assert_eq!(position_of(&mut app, dwarf), position(2, 0));
        assert_eq!(position_of(&mut app, first_box), position(3, 0));
        assert_eq!(position_of(&mut app, second_box), position(4, 0));
        assert_eq!(translation_of(&mut app, first_box).x, 3.0 * TILE_SIZE);
        let compensation = app
            .world_mut()
            .resource_mut::<ActionHistory>()
            .pop_last()
            .expect("the push should be undoable");
        assert_eq!(compensation.snapshots.len(), 3);
        assert_eq!(compensation.snapshots[0].grid_position, position(1, 0));
        assert_eq!(compensation.snapshots[1].grid_position, position(2, 0));
        assert_eq!(compensation.snapshots[2].grid_position, position(3, 0));
    }

    #[test]
    fn dwarf_cannot_push_a_chain_into_a_wall() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 2, 0);
        spawn_wall(&mut app, 3, 0);
        let dwarf = spawn_player(&mut app, 1, 0, PlayerClass::Dwarf);
        let box_entity = spawn_box(&mut app, 2, 0);

        move_player(&mut app, dwarf, IVec2::X);

        assert_eq!(position_of(&mut app, dwarf), position(1, 0));
        assert_eq!(position_of(&mut app, box_entity), position(2, 0));
        assert_eq!(history_snapshot_count(&mut app), 0);
    }

    #[test]
    fn dwarf_pushes_a_box_and_another_player_as_a_chain() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 4, 0);
        let dwarf = spawn_player(&mut app, 1, 0, PlayerClass::Dwarf);
        let box_entity = spawn_box(&mut app, 2, 0);
        let other_player = spawn_player(&mut app, 3, 0, PlayerClass::Wizard);

        move_player(&mut app, dwarf, IVec2::X);

        assert_eq!(position_of(&mut app, dwarf), position(2, 0));
        assert_eq!(position_of(&mut app, box_entity), position(3, 0));
        assert_eq!(position_of(&mut app, other_player), position(4, 0));
        assert_eq!(history_snapshot_count(&mut app), 3);
    }

    #[test]
    fn warrior_pushes_a_chain_as_far_as_possible_while_moving_one() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 7, 0);
        let warrior = spawn_player(&mut app, 1, 0, PlayerClass::Warrior);
        let first_box = spawn_box(&mut app, 2, 0);
        let second_box = spawn_box(&mut app, 3, 0);

        move_player(&mut app, warrior, IVec2::X);

        assert_eq!(position_of(&mut app, warrior), position(2, 0));
        assert_eq!(position_of(&mut app, first_box), position(6, 0));
        assert_eq!(position_of(&mut app, second_box), position(7, 0));
        assert_eq!(history_snapshot_count(&mut app), 3);
    }

    #[test]
    fn warrior_pushes_until_the_wall_even_if_the_path_is_short() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 3, 0);
        spawn_wall(&mut app, 4, 0);
        let warrior = spawn_player(&mut app, 1, 0, PlayerClass::Warrior);
        let box_entity = spawn_box(&mut app, 2, 0);

        move_player(&mut app, warrior, IVec2::X);

        assert_eq!(position_of(&mut app, warrior), position(2, 0));
        assert_eq!(position_of(&mut app, box_entity), position(3, 0));
        assert_eq!(history_snapshot_count(&mut app), 2);
    }

    #[test]
    fn warrior_pushes_until_another_object_blocks_the_path() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 6, 0);
        let warrior = spawn_player(&mut app, 1, 0, PlayerClass::Warrior);
        let first_box = spawn_box(&mut app, 2, 0);
        let second_box = spawn_box(&mut app, 4, 0);

        move_player(&mut app, warrior, IVec2::X);

        assert_eq!(position_of(&mut app, warrior), position(2, 0));
        assert_eq!(position_of(&mut app, first_box), position(3, 0));
        assert_eq!(position_of(&mut app, second_box), position(4, 0));
        assert_eq!(history_snapshot_count(&mut app), 2);
    }

    #[test]
    fn wizard_swaps_with_a_box_at_a_distance() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 6, 0);
        let wizard = spawn_player(&mut app, 1, 0, PlayerClass::Wizard);
        let box_entity = spawn_box(&mut app, 4, 0);

        move_player(&mut app, wizard, IVec2::X);

        assert_eq!(position_of(&mut app, wizard), position(4, 0));
        assert_eq!(position_of(&mut app, box_entity), position(1, 0));
        assert_eq!(translation_of(&mut app, wizard).x, 4.0 * TILE_SIZE);
        assert_eq!(translation_of(&mut app, box_entity).x, 1.0 * TILE_SIZE);
        assert_eq!(history_snapshot_count(&mut app), 2);
    }

    #[test]
    fn wizard_moves_one_tile_when_no_box_is_in_the_direction() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 4, 0);
        let wizard = spawn_player(&mut app, 1, 0, PlayerClass::Wizard);

        move_player(&mut app, wizard, IVec2::X);

        assert_eq!(position_of(&mut app, wizard), position(2, 0));
        assert_eq!(history_snapshot_count(&mut app), 1);
    }

    #[test]
    fn wizard_does_not_swap_through_a_wall() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 2, 0);
        spawn_row(&mut app, 4, 5, 0);
        spawn_wall(&mut app, 3, 0);
        let wizard = spawn_player(&mut app, 1, 0, PlayerClass::Wizard);
        let box_entity = spawn_box(&mut app, 4, 0);

        move_player(&mut app, wizard, IVec2::X);

        assert_eq!(position_of(&mut app, wizard), position(2, 0));
        assert_eq!(position_of(&mut app, box_entity), position(4, 0));
        assert_eq!(history_snapshot_count(&mut app), 1);
    }

    #[test]
    fn sorcerer_pulls_a_distant_box_against_their_movement() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 6, 0);
        let sorcerer = spawn_player(&mut app, 1, 0, PlayerClass::Sorcerer);
        let box_entity = spawn_box(&mut app, 4, 0);

        move_player(&mut app, sorcerer, IVec2::X);

        assert_eq!(position_of(&mut app, sorcerer), position(2, 0));
        assert_eq!(position_of(&mut app, box_entity), position(3, 0));
        assert_eq!(history_snapshot_count(&mut app), 2);
    }

    #[test]
    fn sorcerer_cannot_move_when_the_box_is_adjacent() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 4, 0);
        let sorcerer = spawn_player(&mut app, 1, 0, PlayerClass::Sorcerer);
        let box_entity = spawn_box(&mut app, 2, 0);

        move_player(&mut app, sorcerer, IVec2::X);

        assert_eq!(position_of(&mut app, sorcerer), position(1, 0));
        assert_eq!(position_of(&mut app, box_entity), position(2, 0));
        assert_eq!(history_snapshot_count(&mut app), 0);
    }

    #[test]
    fn sorcerer_cannot_pull_a_box_onto_their_destination() {
        let mut app = test_app();
        spawn_row(&mut app, 0, 4, 0);
        let sorcerer = spawn_player(&mut app, 1, 0, PlayerClass::Sorcerer);
        let box_entity = spawn_box(&mut app, 3, 0);

        move_player(&mut app, sorcerer, IVec2::X);

        assert_eq!(position_of(&mut app, sorcerer), position(1, 0));
        assert_eq!(position_of(&mut app, box_entity), position(3, 0));
        assert_eq!(history_snapshot_count(&mut app), 0);
    }
}
