use std::collections::HashMap;

use bevy::prelude::*;
use bevy::render::render_resource::TextureFormat;

use crate::components::Player;
use crate::resources::PlayerSelection;
use crate::systems::level_spawner::LevelEntity;

const PLAYER_FRAME_SIZE: u32 = 32;
const OUTLINE_RADIUS: i32 = 1;

#[derive(Component)]
pub struct PlayerOutline {
    player: Entity,
}

#[derive(Component)]
pub struct PlayerOutlineCreated;

#[derive(Resource, Default)]
pub struct PlayerOutlineTextures(HashMap<AssetId<Image>, Handle<Image>>);

/// Creates a white alpha-outline sprite for each player once its image is loaded.
pub fn spawn_player_outline_system(
    mut commands: Commands,
    players: Query<(Entity, &Sprite, &Transform), (With<Player>, Without<PlayerOutlineCreated>)>,
    mut images: ResMut<Assets<Image>>,
    mut texture_cache: ResMut<PlayerOutlineTextures>,
) {
    for (player, sprite, transform) in &players {
        let source_id = sprite.image.id();
        let outline_image = if let Some(handle) = texture_cache.0.get(&source_id) {
            handle.clone()
        } else {
            let Some(outline_image) = images.get(&sprite.image).and_then(build_outline_image)
            else {
                continue;
            };
            let handle = images.add(outline_image);
            texture_cache.0.insert(source_id, handle.clone());
            handle
        };

        let mut outline_sprite = sprite.clone();
        outline_sprite.image = outline_image;
        outline_sprite.color = Color::WHITE;

        let mut outline_transform = transform.clone();
        outline_transform.translation.z -= 0.05;

        commands.entity(player).insert(PlayerOutlineCreated);
        commands.spawn((
            outline_sprite,
            outline_transform,
            Visibility::Hidden,
            PlayerOutline { player },
            LevelEntity,
        ));
    }
}

/// Follows players and shows the selected player's pixel-art silhouette border.
pub fn active_player_outline_system(
    selection: Res<PlayerSelection>,
    players: Query<&Transform, (With<Player>, Without<PlayerOutline>)>,
    mut outlines: Query<(&PlayerOutline, &mut Transform, &mut Visibility), Without<Player>>,
) {
    for (outline, mut outline_transform, mut visibility) in &mut outlines {
        let Ok(player_transform) = players.get(outline.player) else {
            *visibility = Visibility::Hidden;
            continue;
        };

        outline_transform.translation = player_transform.translation;
        outline_transform.translation.z -= 0.05;
        *visibility = if selection.active_player == Some(outline.player) {
            Visibility::Visible
        } else {
            Visibility::Hidden
        };
    }
}

fn build_outline_image(source: &Image) -> Option<Image> {
    let size = source.texture_descriptor.size;
    let width = size.width as usize;
    let height = size.height as usize;
    let frame_size = PLAYER_FRAME_SIZE as usize;

    if !matches!(
        source.texture_descriptor.format,
        TextureFormat::Rgba8Unorm | TextureFormat::Rgba8UnormSrgb
    ) || source.data.len() != width.checked_mul(height)?.checked_mul(4)?
        || width % frame_size != 0
        || height % frame_size != 0
    {
        return None;
    }

    let mut result = source.clone();
    let mut output = vec![0; source.data.len()];

    for y in 0..height {
        for x in 0..width {
            let pixel = (y * width + x) * 4;
            output[pixel..pixel + 3].copy_from_slice(&[255, 255, 255]);

            // Keep each atlas frame isolated so neighboring sprites cannot leak into its edge.
            let frame_left = x / frame_size * frame_size;
            let frame_top = y / frame_size * frame_size;
            let min_x = frame_left as i32;
            let max_x = (frame_left + frame_size - 1) as i32;
            let min_y = frame_top as i32;
            let max_y = (frame_top + frame_size - 1) as i32;
            let is_outline = source.data[pixel + 3] == 0
                && (-OUTLINE_RADIUS..=OUTLINE_RADIUS).any(|dy| {
                    (-OUTLINE_RADIUS..=OUTLINE_RADIUS).any(|dx| {
                        let neighbor_x = x as i32 + dx;
                        let neighbor_y = y as i32 + dy;
                        neighbor_x >= min_x
                            && neighbor_x <= max_x
                            && neighbor_y >= min_y
                            && neighbor_y <= max_y
                            && source.data
                                [(neighbor_y as usize * width + neighbor_x as usize) * 4 + 3]
                                > 0
                    })
                });

            output[pixel + 3] = if is_outline { 255 } else { 0 };
        }
    }

    result.data = output;
    Some(result)
}
