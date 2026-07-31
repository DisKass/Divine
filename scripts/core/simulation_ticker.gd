class_name SimulationTicker
extends RefCounted

## Coordinates real-time factory ticks and processes offline simulation.
## Acts as the Orchestrator for the Data-Driven Systems.

signal tick_completed(elapsed_ticks: int)

var state: GameState

var time_accumulator: float = 0.0
var is_active: bool = true

func _init(p_state: GameState) -> void:
	state = p_state

## Internal helper to run a single logical tick using the Systems
func _run_single_tick(delta: float) -> void:
	var miner_speed_mult = ModifierSystem.get_multiplier(state, "miner_speed")
	var factory_speed_mult = ModifierSystem.get_multiplier(state, "factory_speed")
	var sell_mult = ModifierSystem.get_multiplier(state, "sell_multiplier")

	# 1. Process all recipes
	ProductionSystem.tick(state.factory, delta, miner_speed_mult, factory_speed_mult)
	FlowSystem.tick(state, sell_mult)

## Processes real-time game tick accumulation. Call this inside a Node's _process loop.
func process_realtime(delta: float) -> void:
	if not is_active or state == null:
		return

	time_accumulator += minf(delta, 0.1)
	var ticks_run = 0
	var tick_step = 1.0 / 30.0
	var max_ticks_per_frame = 2

	while time_accumulator >= tick_step and ticks_run < max_ticks_per_frame:
		time_accumulator -= tick_step
		_run_single_tick(tick_step)
		ticks_run += 1

	if ticks_run > 0:
		tick_completed.emit(ticks_run)

## Runs offline catch-up simulation based on a saved Unix timestamp.
## Returns a dictionary of results to show to the player.
func catch_up_offline(last_saved_timestamp: int) -> Dictionary:
	if state == null:
		return { "elapsed": 0, "simulated_ticks": 0, "credits_earned": 0.0 }

	var current_time = int(Time.get_unix_time_from_system())
	var elapsed = current_time - last_saved_timestamp

	if elapsed <= 0:
		return { "elapsed": 0, "simulated_ticks": 0, "credits_earned": 0.0 }

	# Cap offline simulation at 30 days (2,592,000 seconds)
	var max_offline = 2592000
	var total_ticks = min(elapsed, max_offline)

	var credits_before = ResourceSystem.get_resource(state, "credits")

	if total_ticks <= 70:
		# Run physically tick-by-tick for small offline periods
		for i in range(total_ticks):
			_run_single_tick(1.0)
		var credits_after = ResourceSystem.get_resource(state, "credits")
		return {
			"elapsed": elapsed,
			"simulated_ticks": total_ticks,
			"credits_earned": credits_after - credits_before
		}
	else:
		# Hybrid approach for long offline periods:
		# 1. Run 50 transient ticks to stabilize buffers and machines
		var transient_ticks = 50
		for i in range(transient_ticks):
			_run_single_tick(1.0)

		# 2. Run 20 ticks to measure steady-state throughput
		var measure_ticks = 20
		var credits_before_measure = ResourceSystem.get_resource(state, "credits")
		for i in range(measure_ticks):
			_run_single_tick(1.0)
		var credits_after_measure = ResourceSystem.get_resource(state, "credits")

		# Calculate average credits earned per tick in steady state
		var measure_earned = credits_after_measure - credits_before_measure
		var throughput = measure_earned / float(measure_ticks)

		# 3. Project the remaining ticks analytically
		var remaining_ticks = total_ticks - transient_ticks - measure_ticks
		var projected_earned = throughput * remaining_ticks
		ResourceSystem.add_resource(state, "credits", projected_earned)

		var credits_after_all = ResourceSystem.get_resource(state, "credits")
		return {
			"elapsed": elapsed,
			"simulated_ticks": total_ticks,
			"credits_earned": credits_after_all - credits_before
		}
