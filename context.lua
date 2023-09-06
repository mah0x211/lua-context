--
-- Copyright (C) 2022 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
local type = type
local new_errno = require('errno').new
local gettime = require('time.clock').gettime
local metamodule = require('metamodule')
local new_metamodule = metamodule.new
local instanceof = metamodule.instanceof

--- constants
local INF_POS = math.huge
local INF_NEG = -math.huge

--- is_finite returns true if x is finite number
--- @param x number
--- @return boolean
local function is_finite(x)
    return type(x) == 'number' and (x < INF_POS and x >= INF_NEG)
end

--- @class context
--- @field done boolean
--- @field err any
--- @field etime? number
--- @field key? string
--- @field val? any
local Context = {}

--- init
--- @param parent context
--- @param duration number?
--- @param key string
--- @param val any
--- @return context ctx
--- @return function cancel
function Context:init(parent, duration, key, val)
    if parent ~= nil and not instanceof(parent, 'context') then
        error('parent must be instance of context', 2)
    end

    if duration then
        if not is_finite(duration) then
            error('duration must be finite number', 2)
        elseif duration < 0 then
            duration = 0
        end
        self.etime = gettime() + duration
    end

    if key ~= nil then
        if type(key) ~= 'string' then
            error('key must be string', 2)
        elseif val ~= nil then
            self.key = key
            self.val = val
        end
    end

    local ctx = self
    self.parent = parent
    return self, function()
        if not ctx.done then
            ctx.done = true
            ctx.err = new_errno('ECANCELED', nil, 'context')
        end
    end
end

--- deadline
--- @return number? deadline
function Context:deadline()
    return self.etime
end

--- get
--- @param key string
--- @return any val
function Context:get(key)
    if type(key) ~= 'string' then
        error('key must be string', 2)
    elseif self.key == key then
        return self.val
    elseif self.parent then
        return self.parent:get(key)
    end
    return nil
end

--- error
--- @return any err
function Context:error()
    return self.err
end

--- is_done
--- @return boolean done
--- @return any err
function Context:is_done()
    if self.done then
        return true, self:error()
    end

    if self.etime then
        self.done = gettime() >= self.etime
        if self.done then
            self.err = new_errno('ETIMEDOUT', nil, 'context')
            return true, self.err
        end
    end

    if self.parent then
        self.done, self.err = self.parent:is_done()
        return self.done, self.err
    end
    return false
end

return {
    new = new_metamodule(Context),
}

