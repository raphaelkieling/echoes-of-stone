use bevy::prelude::*;

/// Visual interpolation for a grid entity whose logical move has completed.
#[derive(Component, Clone, Copy, Debug)]
pub struct GridMovementTween {
    pub start_translation: Vec3,
    pub end_translation: Vec3,
    pub elapsed: f32,
    pub duration: f32,
}

impl GridMovementTween {
    pub fn new(start_translation: Vec3, end_translation: Vec3, grid_distance: u32) -> Self {
        const SECONDS_PER_TILE: f32 = 0.12;
        const MAX_DURATION: f32 = 0.36;

        Self {
            start_translation,
            end_translation,
            elapsed: 0.0,
            duration: (grid_distance.max(1) as f32 * SECONDS_PER_TILE).min(MAX_DURATION),
        }
    }
}
