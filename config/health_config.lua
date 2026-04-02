-- config/health.lua
-- InjuryConfig, IllnessConfig, MalnourishedConfig. All rates are per-tick.


InjuryConfig = {
    bruised = { initial_damage = 10, recovery = 0.5  * PER_HOUR },
    wounded = { initial_damage = 30, recovery = 0.2  * PER_HOUR },
    maimed  = { initial_damage = 50, recovery = 0.05 * PER_HOUR },
}

IllnessConfig = {
    cold        = { damage = 0.1 * PER_HOUR, recovery_chance = 0.08,  recovery = 0.4  * PER_HOUR },
    flu         = { damage = 0.2 * PER_HOUR, recovery_chance = 0.08,  recovery = 0.4  * PER_HOUR },
    the_flux    = { damage = 0.4 * PER_HOUR, recovery_chance = 0.10,  recovery = 0.3  * PER_HOUR },
    consumption = { damage = 0.1 * PER_HOUR, recovery_chance = 0.005, recovery = 0.2  * PER_HOUR },
    pox         = { damage = 0.3 * PER_HOUR, recovery_chance = 0.02,  recovery = 0.2  * PER_HOUR },
    pestilence  = { damage = 0.5 * PER_HOUR, recovery_chance = 0.01,  recovery = 0.15 * PER_HOUR },
}

MalnourishedConfig = { damage = 0.3 * PER_HOUR, recovery = 0.5 * PER_HOUR }
