local M = {}

function M.new(name, max_size)
  local cache = {
    name = name or "unnamed",
    max_size = max_size or 100,
    data = {},
    access_order = {},
    stats = { hits = 0, misses = 0, size = 0 },
  }

  function cache:get(key)
    local value = self.data[key]
    if value ~= nil then
      self.stats.hits = self.stats.hits + 1
      -- Move to end (most recently used)
      self:_update_access(key)
      return value
    else
      self.stats.misses = self.stats.misses + 1
      return nil
    end
  end

  function cache:set(key, value)
    if value == nil then
      self:delete(key)
      return
    end

    local is_new = self.data[key] == nil
    self.data[key] = value

    if is_new then
      self.stats.size = self.stats.size + 1
      table.insert(self.access_order, key)
      -- Evict oldest if over max size
      self:_evict_if_needed()
    else
      -- Update access order for existing key
      self:_update_access(key)
    end
  end

  function cache:delete(key)
    if self.data[key] ~= nil then
      self.data[key] = nil
      self.stats.size = self.stats.size - 1
      -- Remove from access order
      for i, k in ipairs(self.access_order) do
        if k == key then
          table.remove(self.access_order, i)
          break
        end
      end
    end
  end

  function cache:clear()
    self.data = {}
    self.access_order = {}
    self.stats = { hits = 0, misses = 0, size = 0 }
  end

  function cache:_update_access(key)
    -- Remove from current position
    for i, k in ipairs(self.access_order) do
      if k == key then
        table.remove(self.access_order, i)
        break
      end
    end
    -- Add to end
    table.insert(self.access_order, key)
  end

  function cache:_evict_if_needed()
    while self.stats.size > self.max_size do
      local oldest_key = table.remove(self.access_order, 1)
      if oldest_key then
        self.data[oldest_key] = nil
        self.stats.size = self.stats.size - 1
      else
        break
      end
    end
  end

  function cache:stats_report()
    local hit_ratio = 0
    if self.stats.hits + self.stats.misses > 0 then
      hit_ratio = self.stats.hits / (self.stats.hits + self.stats.misses) * 100
    end
    return string.format("%s: %d hits, %d misses (%.1f%% hit ratio), %d/%d items",
           self.name, self.stats.hits, self.stats.misses, hit_ratio, self.stats.size, self.max_size)
  end

  return cache
end

-- Global cache instances
M.icons = M.new("icons", 50)
M.symbols = M.new("symbols", 20)
M.highlights = M.new("highlights", 30)

return M