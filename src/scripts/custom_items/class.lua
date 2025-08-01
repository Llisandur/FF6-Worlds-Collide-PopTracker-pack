-- This file is sourced from https://github.com/jonstoler/class.lua, and is licensed freely for any purpose, given thanks. Thank you.
-- License from https://github.com/jonstoler/class.lua/blob/master/LICENSE.md as of retrieving this source on 4/8/2019

-- By attaching this document to the given files (the "work"), you, the licensee, are hereby granted free usage in both personal and
-- commerical environments, without any obligation of attribution or payment (monetary or otherwise). The licensee is free to use, copy,
-- modify, publish, distribute, sublicence, and/or merchandise the work, subject to the licensee inflecting a positive message unto someone.
-- This includes (but is not limited to): smiling, being nice, saying "thank you", assisting other persons, or any similar actions percolating the given concept.

-- The above copyright notice serves as a permissions notice also, and may optionally be included in copies or portions of the work.

-- The work is provided "as is", without warranty or support, express or implied. The author(s) are not liable for any damages, misuse, or other claim, whether from or as a consequence of usage of the given work.

Class = {}

-- default (empty) constructor
function Class:init(...) end

-- create a subclass
function Class:extend(obj)
  local obj = obj or {}

  local function copyTable(table, destination)
    local table = table or {}
    local result = destination or {}

    for k, v in pairs(table) do
      if not result[k] then
        if type(v) == "table" and k ~= "__index" and k ~= "__newindex" then
          result[k] = copyTable(v)
        else
          result[k] = v
        end
      end
    end

    return result
  end

  copyTable(self, obj)

  obj._ = obj._ or {}

  local mt = {}

  -- create new objects directly, like o = Object()
  mt.__call = function(self, ...)
    return self:new(...)
  end

  -- allow for getters and setters
  mt.__index = function(table, key)
    local val = rawget(table._, key)
    if val and type(val) == "table" and (val.get ~= nil or val.value ~= nil) then
      if val.get then
        if type(val.get) == "function" then
          return val.get(table, val.value)
        else
          return val.get
        end
      elseif val.value then
        return val.value
      end
    else
      return val
    end
  end

  mt.__newindex = function(table, key, value)
    local val = rawget(table._, key)
    if val and type(val) == "table" and ((val.set ~= nil and val._ == nil) or val.value ~= nil) then
      local v = value
      if val.set then
        if type(val.set) == "function" then
          v = val.set(table, value, val.value)
        else
          v = val.set
        end
      end
      val.value = v
      if val and val.afterSet then val.afterSet(table, v) end
    else
      table._[key] = value
    end
  end

  setmetatable(obj, mt)

  return obj
end

-- set properties outside the constructor or other functions
function Class:set(prop, value)
  if not value and type(prop) == "table" then
    for k, v in pairs(prop) do
      rawset(self._, k, v)
    end
  else
    rawset(self._, prop, value)
  end
end

-- create an instance of an object with constructor parameters
function Class:new(...)
  local obj = self:extend({})
  if obj.init then obj:init(...) end
  return obj
end


function class(attr)
  attr = attr or {}
  return Class:extend(attr)
end
