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
local new_errno = require('errno').new
local gettime = require('clock').gettime
local gcfn = require('gcfn')
local isa = require('isa')
local is_uint = isa.uint
local is_string = isa.string
local metamodule = require('metamodule')
local new_metamodule = metamodule.new
local instanceof = metamodule.instanceof

--- @class context
--- @field done boolean
--- @field err? error
--- @field duration? number
--- @field key? string
--- @field val? any
local Context = {}

--- init
--- @param parent context
--- @param duration integer
--- @param key string
--- @param val any
--- @return context ctx
--- @return function cancel
function Context:init(parent, duration, key, val)
    if parent ~= nil and not instanceof(parent, 'context') then
        error('parent must be instance of context', 2)
    end

    if duration then
        if not is_uint(duration) then
            error('duration must be uint', 2)
        end
        self.duration = gettime() + duration / 1000
    end

    if key ~= nil then
        if not is_string(key) then
            error('key must be string', 2)
        elseif val ~= nil then
            self.key = key
            self.val = val
        end
    end

    local gco = gcfn(function(ctx)
        ctx.gced = true
        ctx.done = true
    end, self)

    local ctx = self
    self.parent = parent
    return self, function()
        if not ctx.done then
            gco:disable()
            gco = nil
            ctx.done = true
            ctx.err = new_errno('ECANCELED', nil, 'context')
        end
    end
end

--- deadline
--- @return integer timeout
function Context:deadline()
    return self.duration
end

--- get
--- @param key string
--- @return any val
function Context:get(key)
    if not is_string(key) then
        error('key must be string', 2)
    elseif self.key == key then
        return self.val
    elseif self.parent then
        return self.parent:get(key)
    end
    return nil
end

--- error
--- @return error err
function Context:error()
    if self.gced then
        self.gced = nil
        self.err = new_errno('ECANCELED', 'by GC', 'context')
    end
    return self.err
end

--- is_done
--- @return boolean done
--- @return error? err
function Context:is_done()
    if self.done then
        return true, self:error()
    elseif self.duration and gettime() > self.duration then
        self.done = true
        self.err = new_errno('ETIMEDOUT', nil, 'context')
        return true, self.err
    elseif self.parent then
        self.done, self.err = self.parent:is_done()
        return self.done, self.err
    end
    return false
end

return {
    new = new_metamodule(Context),
}

