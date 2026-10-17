use bevy::prelude::*;
use std::fs;

use crate::components::{Floor, GridPosition, InteractiveObject, Player, Target, Wall};

pub const TILE_SIZE: f32 = 32.0;
const FLOOR_LAYER: f32 = 0.0;
const TARGET_LAYER: f32 = 1.0;
const OBJECT_LAYER: f32 = 2.0;
const PLAYER_LAYER: f32 = 3.0;

#[derive(Resource, Clone)]
pub struct LevelHandle(pub String);

impl Default for LevelHandle {
    fn default() -> Self {
        Self(String::new())
    }
}

pub fn load_level() -> String {
    fs::read_to_string("maps/lvl_0.txt").expect("Failed to read level file")
}

fn tile_sprite(color: Color, tile_size: f32) -> Sprite {
    Sprite {
        color,
        custom_size: Some(Vec2::splat(tile_size)),
        ..default()
    }
}

fn tile_transform(position: Vec3, layer: f32) -> Transform {
    Transform::from_translation(position.with_z(layer))
}

fn spawn_floor(commands: &mut Commands, position: Vec3, grid_position: GridPosition) {
    commands.spawn((
        tile_sprite(Color::srgb(0.9, 0.9, 0.9), TILE_SIZE),
        tile_transform(position, FLOOR_LAYER),
        Floor,
        grid_position,
    ));
}

pub fn spawn_level(mut commands: Commands, level_handle: Res<LevelHandle>) {
    let level_str = &level_handle.0;
    let non_empty: Vec<String> = level_str
        .lines()
        .map(|l| l.to_string())
        .filter(|l| !l.is_empty())
        .collect();
    if non_empty.is_empty() {
        return;
    }

    let height = non_empty.len() as i32;
    let width = non_empty
        .iter()
        .map(|l| l.chars().count())
        .max()
        .unwrap_or(0) as i32;

    let tile_size = TILE_SIZE;
    let offset_x = -(width - 1) as f32 * tile_size / 2.0;
    let offset_y = (height - 1) as f32 * tile_size / 2.0;

    for (y, line) in non_empty.iter().enumerate() {
        let y_grid = height - 1 - (y as i32);
        let chars: Vec<char> = line.chars().collect();
        for (x, &ch) in chars.iter().enumerate() {
            let x_grid = x as i32;
            let pos = Vec3::new(
                offset_x + (x as f32) * tile_size,
                offset_y - (y as f32) * tile_size,
                0.0,
            );

            let grid_pos = GridPosition {
                x: x_grid,
                y: y_grid,
            };

            match ch {
                'W' => {
                    commands
                        .spawn((
                            tile_sprite(Color::srgb(0.4, 0.4, 0.4), tile_size),
                            tile_transform(pos, OBJECT_LAYER),
                        ))
                        .insert(Wall)
                        .insert(grid_pos);
                }
                '#' => {
                    spawn_floor(&mut commands, pos, grid_pos);
                    commands
                        .spawn((
                            tile_sprite(Color::srgb(0.8, 0.6, 0.2), tile_size),
                            tile_transform(pos, OBJECT_LAYER),
                        ))
                        .insert(InteractiveObject::BOX)
                        .insert(grid_pos);
                }
                '@' => {
                    spawn_floor(&mut commands, pos, grid_pos);
                    commands
                        .spawn((
                            tile_sprite(Color::srgb(0.2, 0.6, 0.8), tile_size),
                            tile_transform(pos, PLAYER_LAYER),
                        ))
                        .insert(Player)
                        .insert(grid_pos);
                }
                'F' => {
                    spawn_floor(&mut commands, pos, grid_pos);
                    commands
                        .spawn((
                            tile_sprite(Color::srgb(0.3, 0.8, 0.3), tile_size),
                            tile_transform(pos, TARGET_LAYER),
                        ))
                        .insert(Target)
                        .insert(grid_pos);
                }
                ' ' => {
                    spawn_floor(&mut commands, pos, grid_pos);
                }
                _ => {}
            }
        }
    }
}
