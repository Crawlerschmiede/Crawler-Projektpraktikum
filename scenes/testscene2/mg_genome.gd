# Genome + helper functions (klein und eigenständig)

class_name MGGenome

class Genome:
    var door_fill_chance: float
    var max_corridors: int
    var max_corridor_chain: int
    var corridor_bias: float

    func clone() -> Genome:
        var g := Genome.new()
        g.door_fill_chance = door_fill_chance
        g.max_corridors = max_corridors
        g.max_corridor_chain = max_corridor_chain
        g.corridor_bias = corridor_bias
        return g

    func describe() -> String:
        return (
            "door_fill=" + str(door_fill_chance)
            + ", max_corridors=" + str(max_corridors)
            + ", max_chain=" + str(max_corridor_chain)
            + ", corridor_bias=" + str(corridor_bias)
        )


class EvalResult:
    var genome: Genome
    var rooms_placed: int = 0
    var corridors_placed: int = 0
    var seed: int = 0


class GenStats:
    var rooms: int = 0
    var corridors: int = 0


func make_default_genome(base_door_fill_chance: float, base_max_corridors: int, base_max_corridor_chain: int) -> Genome:
    var g := Genome.new()
    g.door_fill_chance = base_door_fill_chance
    g.max_corridors = base_max_corridors
    g.max_corridor_chain = base_max_corridor_chain
    g.corridor_bias = 1.0
    return g


func random_genome(_rng) -> Genome:
    var g := Genome.new()
    g.door_fill_chance = clamp(_rng.randf_range(0.60, 1.0), 0.0, 1.0)
    g.max_corridors = int(clamp(_rng.randi_range(0, 25), 0, 9999))
    g.max_corridor_chain = int(clamp(_rng.randi_range(1, 4), 0, 10))
    g.corridor_bias = clamp(_rng.randf_range(0.6, 1.6), 0.1, 3.0)
    return g


func crossover(a: Genome, b: Genome, _rng) -> Genome:
    var c := a.clone()
    if _rng.randf() < 0.5:
        c.door_fill_chance = b.door_fill_chance
    if _rng.randf() < 0.5:
        c.max_corridors = b.max_corridors
    if _rng.randf() < 0.5:
        c.max_corridor_chain = b.max_corridor_chain
    if _rng.randf() < 0.5:
        c.corridor_bias = b.corridor_bias
    return c


func mutate(g: Genome, _rng) -> void:
    if _rng.randf() < 0.5:
        g.door_fill_chance = clamp(g.door_fill_chance + _rng.randf_range(-0.12, 0.12), 0.2, 1.0)
    if _rng.randf() < 0.5:
        g.max_corridors = int(clamp(g.max_corridors + _rng.randi_range(-4, 6), 0, 40))
    if _rng.randf() < 0.5:
        g.max_corridor_chain = int(clamp(g.max_corridor_chain + _rng.randi_range(-1, 1), 0, 6))
    if _rng.randf() < 0.5:
        g.corridor_bias = clamp(g.corridor_bias + _rng.randf_range(-0.25, 0.25), 0.3, 2.5)
