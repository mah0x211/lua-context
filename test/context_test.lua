require('luacov')
local assert = require('assert')
local errno = require('errno')
local gettime = require('time.clock').gettime
local sleep = require('time.sleep')
local context = require('context')

local testcase = {}

function testcase.new()
    -- test that create new context
    local ctx, cancel = context.new()
    assert.match(ctx, '^context: ', false)
    assert.is_func(cancel)
    assert.is_nil(ctx:deadline())
    assert.is_nil(ctx:time_left())
    assert.is_nil(ctx:error())

    -- test that is_done return false if not cancelled
    local ok, err = ctx:is_done()
    assert.is_false(ok)
    assert.is_nil(err)

    -- test that is_done return true and ECANCELED if cancelled
    assert.is_nil(cancel())
    ok, err = ctx:is_done()
    assert.is_true(ok)
    assert.equal(err.type, errno.ECANCELED)
    assert.equal(ctx:error(), err)
end

function testcase.with_duration()
    -- test that create new context with duration
    local duration = 0.2
    local ctx, cancel = context.new(nil, duration)
    assert.match(ctx, '^context: ', false)
    assert.is_func(cancel)
    local deadl = assert(ctx:deadline())
    assert.less(deadl:time(), gettime() + duration)
    local tl = assert(ctx:time_left())
    assert.less_or_equal(tl, 0.2)
    assert.greater(tl, 0.19)

    -- test that is_done return false if not timed out or cancelled
    local ok, err = ctx:is_done()
    assert.is_false(ok)
    assert.is_nil(err)

    -- test that is_done return true and ETIMEDOUT
    sleep(duration)
    ok, err = ctx:is_done()
    assert.is_true(ok)
    assert.equal(err.type, errno.ETIMEDOUT)

    -- test that time_left return 0
    assert.equal(ctx:time_left(), 0)

    -- test that is_done return true and ETIMEDOUT immediately
    ctx, cancel = context.new(nil, -1)
    ok, err = ctx:is_done()
    assert.is_true(ok)
    assert.equal(err.type, errno.ETIMEDOUT)

    -- test that throws an error if duration is not finite number
    err = assert.throws(context.new, nil, 0 / 0)
    assert.match(err, 'duration must be finite number')
end

function testcase.with_keyval()
    -- test that create new context with key-value pair
    local ctx, cancel = context.new(nil, nil, 'hello', 'world')
    assert.match(ctx, '^context: ', false)
    assert.is_func(cancel)

    -- test that get value for key
    assert.equal(ctx:get('hello'), 'world')

    -- test that return nil if key-value pair is not defined
    assert.is_nil(ctx:get('foo'))

    -- test that get parent-value
    local child = context.new(ctx, nil, 'foo', 'bar')
    assert.equal(child:get('hello'), 'world')
    assert.equal(child:get('foo'), 'bar')

    -- test that cannot get parent-value
    local gchild = context.new(child, nil, 'foo', 'baa')
    assert.equal(gchild:get('hello'), 'world')
    assert.equal(gchild:get('foo'), 'baa')
    assert.equal(child:get('foo'), 'bar')

    -- test that throws an error if key is invalid
    local err = assert.throws(ctx.get, ctx)
    assert.match(err, 'key must be string')

    err = assert.throws(context.new, nil, nil, true)
    assert.match(err, 'key must be string')
end

function testcase.with_parent()
    -- test that create new context with parent
    local pctx, pcancel = context.new()
    assert.match(pctx, '^context: ', false)
    assert.is_func(pcancel)
    local ctx, cancel = context.new(pctx)
    assert.match(ctx, '^context: ', false)
    assert.is_func(cancel)

    -- test that is_done return false if not cancelled
    local ok, err = ctx:is_done()
    assert.is_false(ok)
    assert.is_nil(err)

    -- test that is_done returns true and ECANCELED after parent is cancelled
    assert.is_nil(pcancel())
    for _, c in ipairs({
        pctx,
        ctx,
    }) do
        ok, err = c:is_done()
        assert.is_true(ok)
        assert.equal(err.type, errno.ECANCELED)
        assert.equal(c:error(), err)
    end

    -- test that is_done return true and ETIMEDOUT
    pctx, pcancel = context.new(nil, 0.2)
    ctx, cancel = context.new(pctx)
    -- confirm that deadline is retrieved from parent
    local deadl = assert(ctx:deadline())
    assert.equal(deadl, pctx:deadline())
    -- confirm that time_left is retrieved from parent
    local tl = assert(ctx:time_left())
    assert.less_or_equal(tl, 0.2)
    assert.greater(tl, 0.19)

    sleep(0.2)
    for _, c in ipairs({
        pctx,
        ctx,
    }) do
        ok, err = c:is_done()
        assert.is_true(ok)
        assert.equal(err.type, errno.ETIMEDOUT)
        assert.equal(c:error(), err)
    end

    -- test that throws an error if parent is not instance of context
    err = assert.throws(context.new, {})
    assert.match(err, 'parent must be instance of context')
end

for k, f in pairs(testcase) do
    local ok, err = xpcall(f, debug.traceback)
    if ok then
        print(k .. ': ok')
    else
        print(k .. ': failed')
        print(err)
    end
end
