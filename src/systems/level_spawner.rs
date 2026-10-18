use bevy::prelude::*;
use std::fs;

use crate::components::{
    Floor, GridPosition, InteractiveObject, Player, PlayerClass, Target, Wall,
};

pub const TILE_SIZE: f32 = 64.0;

#[derive(Component)]
pub struct LevelEntity;

const FLOOR_LAYER: f32 = 0.0;
const TARGET_LAYER: f32 = 1.0;
const OBJECT_LAYER: f32 = 2.0;
const PLAYER_LAYER: f32 = 3.0;

const TILEMAP_SOURCE_TILE_SIZE: u32 = 32;
const TILEMAP_COLUMNS: u32 = 17;
const TILEMAP_ROWS: u32 = 26;
const TILEMAP_TILE_INDEX: usize = 0; // source tile (0, 0)
const TARGET_TILE_INDEX: usize = 16 * TILEMAP_COLUMNS as usize + 9; // source tile (9, 16)
const BOX_TILE_INDEX: usize = (18 - 1) * TILEMAP_COLUMNS as usize + (7 - 1); // (17, 6), one based
const PLAYER_FRAME_SIZE: u32 = 32;
const PLAYER_FRAME_COLUMNS: u32 = 7;
const PLAYER_FRAME_ROWS: u32 = 7;
const DWARF_FRAME_INDEX: usize = 0; // source frame (0, 0)
const WIZARD_FRAME_INDEX: usize = 4 * PLAYER_FRAME_COLUMNS as usize + 1; // source frame (1, 4)
const WARRIOR_FRAME_INDEX: usize = PLAYER_FRAME_COLUMNS as usize + 4; // source frame (4, 1)
pub const PLAYER_DISPLAY_SIZE: f32 = 72.0;

#[derive(Resource, Clone)]
pub struct LevelHandle(pub String);

impl Default for LevelHandle {
    fn default() -> Self {
        Self(String::new())
    }
}

pub fn load_levels() -> Vec<String> {
    let mut level_files: Vec<(u32, std::path::PathBuf)> = fs::read_dir("maps")
        .expect("Failed to read maps directory")
        .filter_map(Result::ok)
        .filter_map(|entry| {
            let path = entry.path();
            if path.extension().and_then(|extension| extension.to_str()) != Some("txt") {
                return None;
            }

            let number = path
                .file_stem()?
                .to_str()?
                .strip_prefix("lvl_")?
                .parse::<u32>()
                .ok()?;
            Some((number, path))
        })
        .collect();
    level_files.sort_by_key(|(number, _)| *number);

    level_files
        .into_iter()
        .map(|(_, path)| {
            fs::read_to_string(&path)
                .unwrap_or_else(|error| panic!("Failed to read {}: {error}", path.display()))
        })
        .collect()
}

fn tile_transform(position: Vec3, layer: f32) -> Transform {
    Transform::from_translation(position.with_z(layer))
}

fn atlas_sprite(
    image: Handle<Image>,
    layout: Handle<TextureAtlasLayout>,
    index: usize,
    display_size: f32,
) -> Sprite {
    let mut sprite = Sprite::from_atlas_image(image, TextureAtlas { layout, index });
    sprite.custom_size = Some(Vec2::splat(display_size));
    sprite
}

fn spawn_floor(
    commands: &mut Commands,
    position: Vec3,
    grid_position: GridPosition,
    tilemap: Handle<Image>,
    tilemap_layout: Handle<TextureAtlasLayout>,
) {
    commands.spawn((
        atlas_sprite(tilemap, tilemap_layout, TILEMAP_TILE_INDEX, TILE_SIZE),
        tile_transform(position, FLOOR_LAYER),
        Floor,
        LevelEntity,
        grid_position,
    ));
}

pub fn spawn_level(
    mut commands: Commands,
    level_handle: Res<LevelHandle>,
    asset_server: Res<AssetServer>,
    mut atlas_layouts: ResMut<Assets<TextureAtlasLayout>>,
) {
    spawn_level_contents(
        &mut commands,
        &level_handle.0,
        &asset_server,
        &mut atlas_layouts,
    );
}

pub(crate) fn spawn_level_contents(
    commands: &mut Commands,
    level: &str,
    asset_server: &AssetServer,
    atlas_layouts: &mut Assets<TextureAtlasLayout>,
) {
    let non_empty: Vec<&str> = level.lines().filter(|line| !line.is_empty()).collect();
    if non_empty.is_empty() {
        return;
    }

    let height = non_empty.len() as i32;
    let width = non_empty
        .iter()
        .map(|line| line.chars().count())
        .max()
        .unwrap_or(0) as i32;
    let offset_x = -(width - 1) as f32 * TILE_SIZE / 2.0;
    let offset_y = (height - 1) as f32 * TILE_SIZE / 2.0;

    let tilemap: Handle<Image> = asset_server.load("tiles.png");
    let player_image: Handle<Image> = asset_server.load("rogues.png");

    let tilemap_layout = atlas_layouts.add(TextureAtlasLayout::from_grid(
        UVec2::splat(TILEMAP_SOURCE_TILE_SIZE),
        TILEMAP_COLUMNS,
        TILEMAP_ROWS,
        None,
        None,
    ));
    // Use only the first 32x32 rogue cell for a static player sprite.
    let player_layout = atlas_layouts.add(TextureAtlasLayout::from_grid(
        UVec2::splat(PLAYER_FRAME_SIZE),
        PLAYER_FRAME_COLUMNS,
        PLAYER_FRAME_ROWS,
        None,
        None,
    ));

    for (y, line) in non_empty.iter().enumerate() {
        let grid_y = height - 1 - y as i32;
        for (x, ch) in line.chars().enumerate() {
            let position = Vec3::new(
                offset_x + x as f32 * TILE_SIZE,
                offset_y - y as f32 * TILE_SIZE,
                0.0,
            );
            let grid_position = GridPosition {
                x: x as i32,
                y: grid_y,
            };

            match ch {
                'W' => {
                    commands.spawn((
                        Sprite::from_color(Color::srgb(0.4, 0.4, 0.4), Vec2::splat(TILE_SIZE)),
                        tile_transform(position, OBJECT_LAYER),
                        Wall,
                        LevelEntity,
                        grid_position,
                    ));
                }
                '#' => {
                    spawn_floor(
                        commands,
                        position,
                        grid_position,
                        tilemap.clone(),
                        tilemap_layout.clone(),
                    );
                    commands.spawn((
                        atlas_sprite(
                            tilemap.clone(),
                            tilemap_layout.clone(),
                            BOX_TILE_INDEX,
                            TILE_SIZE,
                        ),
                        tile_transform(position, OBJECT_LAYER),
                        InteractiveObject::BOX,
                        LevelEntity,
                        grid_position,
                    ));
                }
                '1' | '2' | '3' => {
                    let (class, frame_index) = match ch {
                        '1' => (PlayerClass::Dwarf, DWARF_FRAME_INDEX),
                        '2' => (PlayerClass::Wizard, WIZARD_FRAME_INDEX),
                        '3' => (PlayerClass::Warrior, WARRIOR_FRAME_INDEX),
                        _ => unreachable!(),
                    };
                    spawn_floor(
                        commands,
                        position,
                        grid_position,
                        tilemap.clone(),
                        tilemap_layout.clone(),
                    );
                    commands.spawn((
                        atlas_sprite(
                            player_image.clone(),
                            player_layout.clone(),
                            frame_index,
                            PLAYER_DISPLAY_SIZE,
                        ),
                        tile_transform(position, PLAYER_LAYER),
                        Player { class },
                        LevelEntity,
                        grid_position,
                    ));
                }
                'F' => {
                    spawn_floor(
                        commands,
                        position,
                        grid_position,
                        tilemap.clone(),
                        tilemap_layout.clone(),
                    );
                    commands.spawn((
                        atlas_sprite(
                            tilemap.clone(),
                            tilemap_layout.clone(),
                            TARGET_TILE_INDEX,
                            TILE_SIZE,
                        ),
                        tile_transform(position, TARGET_LAYER),
                        Target,
                        LevelEntity,
                        grid_position,
                    ));
                }
                ' ' => spawn_floor(
                    commands,
                    position,
                    grid_position,
                    tilemap.clone(),
                    tilemap_layout.clone(),
                ),
                _ => {}
            }
        }
    }
}
