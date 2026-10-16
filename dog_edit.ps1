$p='EnemyDog/enemy_dog.gd'
$s=Get-Content $p -Raw
$s=$s.Replace('@export var attack_range: float = 28.0','@export var attack_range: float = 48.0').Replace('@export var bite_windup_time: float = 0.10','@export var bite_windup_time: float = 0.45').Replace('@export var retreat_time_min: float = 0.20','@export var retreat_time_min: float = 0.65').Replace('@export var retreat_time_max: float = 0.45','@export var retreat_time_max: float = 0.95').Replace('@export var retreat_speed_multiplier: float = 1.25','@export var retreat_speed_multiplier: float = 0.55')
$a=$s.IndexOf('func _state_pounce(delta: float)'); $b=$s.IndexOf('func _state_retreat', $a)
$s=$s.Substring(0,$a)+@"
func _state_pounce(delta: float) -> void:
	pounce_recovery_timer -= delta
	var speed := pounce_attack_speed if pounce_mode_attack else obstacle_pounce_speed
	velocity.x = float(pounce_dir) * speed
	if pounce_mode_attack and is_instance_valid(player):
		var dx := player.global_position.x - global_position.x
		# Brake beside the target instead of overshooting and retreating in midair.
		if absf(dx) <= attack_range or signf(dx) != float(pounce_dir):
			velocity.x = 0.0
	if is_on_floor() and velocity.y >= 0.0 and pounce_recovery_timer <= 0.0:
		jump_cooldown_timer = jump_cooldown_time
		if _has_target() and absf(player.global_position.x - global_position.x) <= attack_range and absf(player.global_position.y - global_position.y) < 45.0:
			facing_dir = int(sign(player.global_position.x - global_position.x)) if not is_zero_approx(player.global_position.x - global_position.x) else facing_dir
			_scale_sprite()
			_update_sensors()
			_set_state(State.BITE)
		else:
			_set_state(State.CHASE if _has_target() else State.SEARCH)

"@+$s.Substring($b)
$s=$s.Replace("`t`t`t_play(`"bite`")`r`n`t`t`t_play_sfx(bite_sfx, sfx_bite)","`t`t`t_play(`"alert`")")
[IO.File]::WriteAllText((Join-Path (Get-Location) $p),$s)
