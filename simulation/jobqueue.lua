-- simulation/jobqueue.lua
-- Single flat array of all work tasks (regular and hauling jobs).
-- World and hauling system post jobs; units query and claim them.
-- Swap-and-pop deletion on completion or discard.

local registry = require("core.registry")
local log      = require("core.log")

local math_sqrt = math.sqrt

-- Distance-equivalent score gained per tick of job age.
-- Ensures old unclaimed jobs eventually outcompete closer newer ones.
local AGE_WEIGHT = 0.1

-- Built lazily after config/jobs.lua sets ChildJobs.
local child_job_set = nil
local function isChildEligible(job_type)
    if child_job_set == nil then
        child_job_set = {}
        for _, t in ipairs(ChildJobs) do
            child_job_set[t] = true
        end
    end
    return child_job_set[job_type] == true
end

--- Return true if unit meets the eligibility requirements for job.
local function isEligible(unit, job)
    -- Hauling jobs: any unit
    if job.type == "haul" then return true end

    local cfg = JobConfig[job.type]
    if cfg == nil then return false end

    if unit.is_child then
        return isChildEligible(job.type)
    end

    if cfg.job_tier == JobTier.T1 then return true end
    if cfg.job_tier == JobTier.T2 then return unit.tier >= Tier.FREEMAN end
    if cfg.job_tier == JobTier.T3 then return unit.tier >= Tier.GENTRY end
    return false
end

local jobqueue = {
    jobs = {},   -- flat array
}

--- Create a job and add it to the queue. params must include `type` and `posted_tick`.
function jobqueue:postJob(params)
    local job = {
        id          = registry:nextId(),
        type        = params.type,
        claimed_by  = nil,
        posted_tick = params.posted_tick or 0,

        x         = params.x         or 0,
        y         = params.y         or 0,
        target_id = params.target_id or nil,
        progress  = 0,

        resource       = params.resource       or nil,
        source_id      = params.source_id      or nil,
        destination_id = params.destination_id or nil,
    }

    registry:insert(job)
    table.insert(self.jobs, job)
    log:debug("JOB", "posted %s (id=%d) at (%d,%d)", job.type, job.id, job.x, job.y)
    return job
end

--- Scan the queue and claim the best eligible job for unit.
--- Score = -distance + age * AGE_WEIGHT. Returns the claimed job or nil.
function jobqueue:claimJob(unit, time)
    local best       = nil
    local best_score = -math.huge

    for i = 1, #self.jobs do
        local job = self.jobs[i]
        if job.claimed_by == nil and isEligible(unit, job) then
            local dx    = unit.x - job.x
            local dy    = unit.y - job.y
            local dist  = math_sqrt(dx * dx + dy * dy)
            local age   = time.tick - job.posted_tick
            local score = -dist + age * AGE_WEIGHT
            if score > best_score then
                best       = job
                best_score = score
            end
        end
    end

    if best ~= nil then
        best.claimed_by     = unit.id
        unit.current_job_id = best.id
        log:debug("JOB", "%s claimed %s (id=%d)", unit.name, best.type, best.id)
    end

    return best
end

--- Release a job back to the queue without removing it (unit interrupted or abandoned).
function jobqueue:releaseJob(job_id)
    local job = registry[job_id]
    if job then
        job.claimed_by = nil
    end
end

--- Remove a completed job. Swap-and-pop.
function jobqueue:completeJob(job_id)
    for i = 1, #self.jobs do
        if self.jobs[i].id == job_id then
            registry:remove(job_id)
            self.jobs[i] = self.jobs[#self.jobs]
            self.jobs[#self.jobs] = nil
            log:debug("JOB", "completed job %d", job_id)
            return
        end
    end
end

--- Remove a discarded job (target destroyed, building demolished, etc.). Swap-and-pop.
function jobqueue:discardJob(job_id)
    for i = 1, #self.jobs do
        if self.jobs[i].id == job_id then
            registry:remove(job_id)
            self.jobs[i] = self.jobs[#self.jobs]
            self.jobs[#self.jobs] = nil
            log:debug("JOB", "discarded job %d", job_id)
            return
        end
    end
end

--- Clear all jobs. Called on new game / quit-to-menu.
function jobqueue:reset()
    self.jobs = {}
end

--- Stub: return serializable state. Full implementation in Phase 11.
function jobqueue:serialize()   return {} end
function jobqueue:deserialize(data) end

return jobqueue
