-- config/jobs.lua
-- JobConfig and ChildJobs.

JobConfig = {
    -- T1: any tier, attribute only, no skill cap
    hauler      = { job_tier = JobTier.T1, attribute = "strength"                                        },
    woodcutter  = { job_tier = JobTier.T1, attribute = "strength",     work_ticks = 8 * TICKS_PER_HOUR  },
    miner       = { job_tier = JobTier.T1, attribute = "strength",     work_ticks = 8 * TICKS_PER_HOUR  },
    stonecutter = { job_tier = JobTier.T1, attribute = "strength",     work_ticks = 8 * TICKS_PER_HOUR  },
    miller      = { job_tier = JobTier.T1, attribute = "strength"                                        },
    farmer      = { job_tier = JobTier.T1, attribute = "wisdom",       work_ticks = 4 * TICKS_PER_HOUR  },
    fisher      = { job_tier = JobTier.T1, attribute = "wisdom",       work_ticks = 4 * TICKS_PER_HOUR  },
    gatherer    = { job_tier = JobTier.T1, attribute = "wisdom",       work_ticks = 4 * TICKS_PER_HOUR  },

    -- T2: Freeman+, attribute + skill with cap
    guard       = { job_tier = JobTier.T2, attribute = "strength",     skill = "melee_combat",  max_skill = 5 },
    smith       = { job_tier = JobTier.T2, attribute = "dexterity",    skill = "smithing",      max_skill = 5 },
    huntsman    = { job_tier = JobTier.T2, attribute = "dexterity",    skill = "hunting",       max_skill = 5 },
    tailor      = { job_tier = JobTier.T2, attribute = "dexterity",    skill = "tailoring",     max_skill = 5 },
    baker       = { job_tier = JobTier.T2, attribute = "intelligence", skill = "baking",        max_skill = 5 },
    brewer      = { job_tier = JobTier.T2, attribute = "intelligence", skill = "brewing",       max_skill = 5 },
    builder     = { job_tier = JobTier.T2, attribute = "intelligence", skill = "construction",  max_skill = 5 },
    teacher     = { job_tier = JobTier.T2, attribute = "intelligence", skill = "scholarship",   max_skill = 5 },
    herbalist   = { job_tier = JobTier.T2, attribute = "wisdom",       skill = "herbalism",     max_skill = 5 },
    healer      = { job_tier = JobTier.T2, attribute = "wisdom",       skill = "medicine",      max_skill = 5 },
    priest      = { job_tier = JobTier.T2, attribute = "wisdom",       skill = "priesthood",    max_skill = 5 },
    barkeep     = { job_tier = JobTier.T2, attribute = "charisma",     skill = "barkeeping",    max_skill = 5 },
    merchant    = { job_tier = JobTier.T2, attribute = "charisma",     skill = "trading",       max_skill = 5 },

    -- T3: Gentry only, attribute + skill with higher cap
    knight      = { job_tier = JobTier.T3, attribute = "strength",     skill = "melee_combat",  max_skill = 10 },
    armorer     = { job_tier = JobTier.T3, attribute = "dexterity",    skill = "smithing",      max_skill = 10 },
    jeweler     = { job_tier = JobTier.T3, attribute = "dexterity",    skill = "jewelry",       max_skill = 10 },
    architect   = { job_tier = JobTier.T3, attribute = "intelligence", skill = "construction",  max_skill = 10 },
    scholar     = { job_tier = JobTier.T3, attribute = "intelligence", skill = "scholarship",   max_skill = 10 },
    physician   = { job_tier = JobTier.T3, attribute = "wisdom",       skill = "medicine",      max_skill = 10 },
    bishop      = { job_tier = JobTier.T3, attribute = "wisdom",       skill = "priesthood",    max_skill = 10 },
    steward     = { job_tier = JobTier.T3, attribute = "charisma",     skill = "trading",       max_skill = 10 },
    leader      = { job_tier = JobTier.T3, attribute = "charisma",     skill = "leadership",    max_skill = 10 },
}

-- Jobs children are eligible for (subset of T1)
ChildJobs = { "hauler", "farmer", "gatherer", "fisher" }
