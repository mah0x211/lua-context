# lua-context

[![test](https://github.com/mah0x211/lua-context/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-context/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-context/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-context)

The context module provides golang-like context functionality.


## Installation

```
luarocks install context
```


## Usage

```lua
local context = require('context')

local function busyfunc(ctx)
    while true do
        --
        -- do something
        --

        local done, err = ctx:is_done()
        if done then
            return done, err
        end
    end
end

-- create new context with timeout
local ctx, cancel = context.new(nil, 100)
local done, err = busyfunc(ctx)
print(done, err) -- true ...: [ETIMEDOUT:60][context] Operation timed out
```

## Error Handling

the functions are return the error object created by https://github.com/mah0x211/lua-errno module.


## ctx, cancel = context.new( [parent], [duration], [key, val] )

create new context.

**Parameters**

- `parent:context`: a parent context.
- `duration:integer`: specify a timeout duration `milliseconds` as unsigned integer.
- `key:string`: a key string to access the the specified value.
- `val:any`: any value associated with `key`.

**Returns**

- `ctx:context`: an instance of context.
- `cancel:function`: cancel function.


## deadline = ctx:deadline()

get a deadline based on a monotonic clock.

**Returns**

- `deadline:number`: number of seconds based on monotonic clock.


## val = ctx:get( key )

get a value associated with `key`. if `key` does not exist in `ctx`, traverse the `parent` context.

**Parameters**

- `key:string`: a key string.

**Returns**

- `val:any`: any value associated with key, or `nil`.


## err = ctx:error()

get a error value.

**Returns**

- `err:error`: if `is_done` method returned `true`, err will be one of the following value;
  - `errno.ECANCELED`: a context was canceled by the `cancel` function or `GC`.
  - `errno.ETIMEDOUT`: the specified duration has elapsed.


## done, err = ctx:is_done()

detects whether a context is done.

**Returns**

- `done:boolean`: `true` on done.
- `err:error`: if a done is `true`, err will be one of the following value;
  - `errno.ECANCELED`: a context was canceled by the `cancel` function or `GC`.
  - `errno.ETIMEDOUT`: the specified duration has elapsed.


