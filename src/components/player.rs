use bevy::prelude::*;

#[derive(Component, Clone, Copy, Debug, PartialEq, Eq)]
pub struct Player {
    pub class: PlayerClass,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PlayerClass {
    Dwarf,
    Wizard,
    Warrior,
    Telekinetic,
    Sorcerer,
}
