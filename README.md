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

-- create new context with timeout duration 100ms.
local ctx, cancel = context.new(nil, 0.1)
local done, err = busyfunc(ctx)
print(done, err) -- true ...: [ETIMEDOUT:60][context] Operation timed out
```

## Error Handling

the functions are return the error object created by https://github.com/mah0x211/lua-errno module.


## ctx, cancel = context.new( [parent], [duration], [key, val] )

create new context.

**Parameters**

- `parent:context`: a parent context.
- `duration:number`: specify a timeout duration `seconds` as number. if `<0` specified, the context will be timeout immediately.
- `key:string`: a key string to access the the specified value.
- `val:any`: any value associated with `key`.

**Returns**

- `ctx:context`: an instance of context.
- `cancel:function`: cancel function. if this function is not called, the context is never canceled.


## deadl = ctx:deadline()

get an instance of `time.clock.deadline`.  
if the `duration` argument is not provided when calling `context.new`, it attempts to call the `ctx:deadline()` of the `parent` context.
if no `parent` context is specified, it returns `nil`.

**Returns**

- `deadl:time.clock.deadline`: an instance of `time.clock.deadline`.  
  please see https://github.com/mah0x211/lua-time-clock#deadl-sec--deadlinenew-sec- for usage.


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
- `timedout:boolean`: `true` if the context is timed out.

