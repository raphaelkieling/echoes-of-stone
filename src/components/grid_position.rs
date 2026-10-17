use bevy::prelude::*;

#[derive(Component, Clone, Copy, Debug, PartialEq, Eq)]
pub struct GridPosition {
    pub x: i32,
    pub y: i32,
}
