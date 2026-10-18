use bevy::{hierarchy::DespawnRecursiveExt, prelude::*};

use crate::resources::{ActionHistory, LevelProgress, PlayerSelection};
use crate::systems::level_spawner::{spawn_level_contents, LevelEntity};
use crate::systems::{LevelHandle, LevelTransition};

use super::{GameScreen, PauseMenuState, ScreenUiRoot};

const PAUSE_OPTIONS: [&str; 4] = ["CONTINUE", "RESTART", "LEVELS", "QUIT"];

#[derive(Component)]
struct PauseMenuText;

#[derive(Component)]
struct PauseMenuRoot;

pub(super) struct PlayingScreenPlugin;

impl Plugin for PlayingScreenPlugin {
    fn build(&self, app: &mut App) {
        app.init_resource::<PauseMenuState>()
            .add_systems(PreUpdate, clear_restart_frame_guard)
            .add_systems(OnEnter(GameScreen::Playing), crate::systems::spawn_level)
            .add_systems(OnExit(GameScreen::Playing), cleanup_playing_screen)
            .add_systems(
                Update,
                pause_menu_input_system.run_if(in_state(GameScreen::Playing)),
            );
    }
}

fn clear_restart_frame_guard(mut pause_menu: ResMut<PauseMenuState>) {
    pause_menu.block_gameplay_this_frame = false;
}

fn pause_menu_text(selected: usize) -> String {
    let mut text = String::from("PAUSED\n\n");
    for (index, label) in PAUSE_OPTIONS.iter().enumerate() {
        let marker = if index == selected { ">" } else { " " };
        text.push_str(&format!("{marker} {label}\n"));
    }
    text
}

fn spawn_pause_menu(commands: &mut Commands, selected: usize) {
    commands
        .spawn((
            Node {
                width: Val::Percent(100.0),
                height: Val::Percent(100.0),
                align_items: AlignItems::Center,
                justify_content: JustifyContent::Center,
                ..default()
            },
            ScreenUiRoot,
            PauseMenuRoot,
        ))
        .with_children(|root| {
            root.spawn((
                Text::new(pause_menu_text(selected)),
                TextFont {
                    font_size: 28.0,
                    ..default()
                },
                TextColor(Color::WHITE),
                PauseMenuText,
            ));
        });
}

fn pause_menu_input_system(
    mut commands: Commands,
    keyboard: Res<ButtonInput<KeyCode>>,
    mut pause_menu: ResMut<PauseMenuState>,
    mut menu_text: Query<&mut Text, With<PauseMenuText>>,
    pause_menu_entities: Query<Entity, With<PauseMenuRoot>>,
    mut next_screen: ResMut<NextState<GameScreen>>,
    mut app_exit: EventWriter<AppExit>,
    level_handle: Res<LevelHandle>,
    asset_server: Res<AssetServer>,
    mut atlas_layouts: ResMut<Assets<TextureAtlasLayout>>,
    level_entities: Query<Entity, With<LevelEntity>>,
    mut action_history: ResMut<ActionHistory>,
    mut player_selection: ResMut<PlayerSelection>,
    mut progress: ResMut<LevelProgress>,
    mut level_transition: ResMut<LevelTransition>,
) {
    if !pause_menu.is_open {
        if keyboard.just_pressed(KeyCode::Escape) && !level_transition.is_active() {
            pause_menu.is_open = true;
            pause_menu.selected_option = 0;
            spawn_pause_menu(&mut commands, pause_menu.selected_option);
        }
        return;
    }

    if keyboard.just_pressed(KeyCode::Escape) {
        for entity in &pause_menu_entities {
            commands.entity(entity).despawn_recursive();
        }
        pause_menu.is_open = false;
        return;
    }

    if keyboard.just_pressed(KeyCode::ArrowDown) || keyboard.just_pressed(KeyCode::KeyS) {
        pause_menu.selected_option = (pause_menu.selected_option + 1) % PAUSE_OPTIONS.len();
    } else if keyboard.just_pressed(KeyCode::ArrowUp) || keyboard.just_pressed(KeyCode::KeyW) {
        pause_menu.selected_option =
            (pause_menu.selected_option + PAUSE_OPTIONS.len() - 1) % PAUSE_OPTIONS.len();
    }

    for mut text in &mut menu_text {
        **text = pause_menu_text(pause_menu.selected_option);
    }

    if !keyboard.just_pressed(KeyCode::Enter) && !keyboard.just_pressed(KeyCode::NumpadEnter) {
        return;
    }

    match pause_menu.selected_option {
        0 => {
            for entity in &pause_menu_entities {
                commands.entity(entity).despawn_recursive();
            }
            pause_menu.is_open = false;
        }
        1 => {
            for entity in &pause_menu_entities {
                commands.entity(entity).despawn_recursive();
            }
            for entity in &level_entities {
                commands.entity(entity).despawn();
            }
            spawn_level_contents(
                &mut commands,
                &level_handle.0,
                &asset_server,
                &mut atlas_layouts,
            );
            action_history.clear();
            player_selection.active_player = None;
            progress.win_emitted = false;
            level_transition.reset();
            pause_menu.is_open = false;
            pause_menu.block_gameplay_this_frame = true;
        }
        2 => {
            for entity in &pause_menu_entities {
                commands.entity(entity).despawn_recursive();
            }
            pause_menu.is_open = false;
            next_screen.set(GameScreen::LevelSelect);
        }
        _ => {
            app_exit.send(AppExit::Success);
        }
    }
}

fn cleanup_playing_screen(
    mut commands: Commands,
    level_entities: Query<Entity, With<LevelEntity>>,
    pause_menu_entities: Query<Entity, With<PauseMenuRoot>>,
    mut action_history: ResMut<ActionHistory>,
    mut player_selection: ResMut<PlayerSelection>,
    mut progress: ResMut<LevelProgress>,
    mut pause_menu: ResMut<PauseMenuState>,
) {
    for entity in &level_entities {
        commands.entity(entity).despawn();
    }
    for entity in &pause_menu_entities {
        commands.entity(entity).despawn_recursive();
    }
    action_history.clear();
    player_selection.active_player = None;
    progress.win_emitted = false;
    pause_menu.is_open = false;
}
