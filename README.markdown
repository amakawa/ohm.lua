ohm.lua
=======

A port of the popular [ohm](http://github.com/soveran/ohm) library
to Lua.

## example

```lua
-- define this in models/user.lua
local ohm = require("ohm")

return ohm.model("User", {
    attributes = {
        "lname",
        "fname",
        "email"
    },

    indices = {
        "full_name"
    },

    uniques = {
        "email"
    }
})

-- using it: (e.g. in app.lua)

local user = require("models/user")
local resp = require("resp")

local attributes = {
    email = "john@example.org",
    fname = "John",
    lname = "Doe",
    full_name = "John Doe",
}

local db = resp.new("localhost", 6379)
local id = assert(user:save(db, attributes))

assert("1" == id)
```

## license

MIT
