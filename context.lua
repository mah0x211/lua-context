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
local new_metamodule = require('metamodule').new
local instanceof = require('metamodule').instanceof

--- @class time.clock.deadline
--- @field time fun():number
--- @field remain fun():number

--- @type fun(duration?: number):(d:time.clock.deadline, sec:number)
local new_deadline = require('time.clock.deadline').new

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
--- @field parent context?
--- @field done boolean
--- @field err any
--- @field timedout boolean?
--- @field deadl? time.clock.deadline
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
        self.deadl = new_deadline(duration)
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
--- @return time.clock.deadline? deadl
function Context:deadline()
    if self.deadl then
        return self.deadl
    elseif not self.parent then
        return nil
    end
    return self.parent:deadline()
end

--- get
--- @param key string
--- @return any val
function Context:get(key)
    if type(key) ~= 'string' then
        error('key must be string', 2)
    elseif self.key == key then
        return self.val
    elseif not self.parent then
        return nil
    end
    return self.parent:get(key)
end

--- error
--- @return any err
function Context:error()
    return self.err
end

--- is_done
--- @return boolean done
--- @return any err
--- @return boolean? timedout
function Context:is_done()
    if self.done then
        return true, self.err, self.timedout
    end

    if self.deadl then
        self.done = self.deadl:remain() == 0
        if self.done then
            self.err = new_errno('ETIMEDOUT', nil, 'context')
            self.timedout = true
            return true, self.err, true
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

