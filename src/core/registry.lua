-- core/registry.lua
-- Global entity registry. Provides ID allocation and cross-type lookup by ID.
-- registry.next_id is serialized; restored from save on load.

local registry = {}

registry.next_id = 0

function registry.nextId()
    registry.next_id = registry.next_id + 1
    return registry.next_id
end

-- Allocates an ID, inserts entity into the typed collection array,
-- registers it in registry[id], and returns the entity.
function registry.createEntity(collection, entity)
    entity.id = registry.nextId()
    collection[#collection + 1] = entity
    registry[entity.id] = entity
    return entity
end

return registry
