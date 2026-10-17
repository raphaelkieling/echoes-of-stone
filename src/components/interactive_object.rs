use bevy::prelude::*;

/// Marks an object the player can interact with on the grid.
#[derive(Component, Clone, Copy, Debug, PartialEq, Eq)]
pub struct InteractiveObject {
    pub kind: InteractiveObjectKind,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum InteractiveObjectKind {
    Box,
}

impl InteractiveObject {
    pub const BOX: Self = Self {
        kind: InteractiveObjectKind::Box,
    };
}
