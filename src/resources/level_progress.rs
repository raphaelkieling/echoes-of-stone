use bevy::prelude::*;

#[derive(Resource)]
pub struct LevelProgress {
    pub levels: Vec<String>,
    pub current_index: usize,
    pub win_emitted: bool,
}

impl LevelProgress {
    pub fn new(levels: Vec<String>) -> Self {
        Self {
            levels,
            current_index: 0,
            win_emitted: false,
        }
    }
}
