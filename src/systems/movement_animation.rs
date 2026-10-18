use bevy::prelude::*;

use crate::components::GridMovementTween;

/// Smoothly interpolates grid entities after their logical positions change.
pub fn animate_grid_movement_system(
    time: Res<Time>,
    mut commands: Commands,
    mut moving_entities: Query<(Entity, &mut Transform, &mut GridMovementTween)>,
) {
    for (entity, mut transform, mut tween) in &mut moving_entities {
        tween.elapsed += time.delta_secs();
        let progress = (tween.elapsed / tween.duration).clamp(0.0, 1.0);
        let eased_progress = progress * progress * (3.0 - 2.0 * progress);
        transform.translation = tween
            .start_translation
            .lerp(tween.end_translation, eased_progress);

        if progress >= 1.0 {
            transform.translation = tween.end_translation;
            commands.entity(entity).remove::<GridMovementTween>();
        }
    }
}
