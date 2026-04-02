-- config/needs.lua
-- NeedsConfig: drain rates and thresholds per tier. All rates are per-tick.

NeedsConfig = {
    child = {
        satiation  = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        energy     = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        recreation = { drain = 8 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
    },
    [Tier.SERF] = {
        satiation  = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        energy     = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
        recreation = { drain = 2 * PER_HOUR, soft_threshold = 40, hard_threshold = 15, mood_threshold = 30, mood_penalty = -10 },
    },
    [Tier.FREEMAN] = {
        satiation  = { drain = 3 * PER_HOUR, soft_threshold = 50, hard_threshold = 20, mood_threshold = 50, mood_penalty = -15 },
        energy     = { drain = 3 * PER_HOUR, soft_threshold = 50, hard_threshold = 20, mood_threshold = 50, mood_penalty = -15 },
        recreation = { drain = 3 * PER_HOUR, soft_threshold = 50, hard_threshold = 20, mood_threshold = 50, mood_penalty = -15 },
    },
    [Tier.GENTRY] = {
        satiation  = { drain = 4 * PER_HOUR, soft_threshold = 60, hard_threshold = 25, mood_threshold = 60, mood_penalty = -20 },
        energy     = { drain = 4 * PER_HOUR, soft_threshold = 60, hard_threshold = 25, mood_threshold = 60, mood_penalty = -20 },
        recreation = { drain = 4 * PER_HOUR, soft_threshold = 60, hard_threshold = 25, mood_threshold = 60, mood_penalty = -20 },
    },
}
