use bevy::prelude::*;

/// Marks any entity that character movement rules may move as an object.
#[derive(Component, Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct InteractiveObject;

/// Identifies a pushable object that participates in level completion.
#[derive(Component, Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct BoxObject;
