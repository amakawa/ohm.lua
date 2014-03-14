local resp = require("lib/resp-31bf5e0")
local user = require("examples/user")

local attributes = {
	email = "john@example.org",
	fname = "John",
	lname = "Doe",
	full_name = "John Doe",
}

local db = resp.new("localhost", 6379)

-- setup
assert(db:call("FLUSHDB"))

-- case 1: saving a new entry
local id = assert(user:save(db, attributes))
assert(id == "1")

-- case 1.1: verify the hash
local values = db:call("HMGET", "User:1", "email", "fname", "lname")
assert(3 == db:call("HLEN", "User:1"))
assert(values[1] == "john@example.org")
assert(values[2] == "John")
assert(values[3] == "Doe")

-- case 1.2: verify indices
local indices = db:call("SMEMBERS", "User:indices:full_name:John Doe")
assert(indices[1] == "1")

local _indices = db:call("SMEMBERS", "User:1:_indices")
assert(_indices[1] == "User:indices:full_name:John Doe")

-- case 1.3: verify uniques
local id = db:call("HGET", "User:uniques:email", "john@example.org")
assert(id == "1")

local _uniques = db:call("HGETALL", "User:1:_uniques")
assert(_uniques[1] == "User:uniques:email")
assert(_uniques[2] == "john@example.org")

-- case 1.4: verify User:all set
local all = db:call("SMEMBERS", "User:all")
assert(#all == 1)
assert(all[1] == "1")

-- case 2: unique index violation
local _, err = user:save(db, attributes)
assert(err.code == "UniqueIndexViolation")
assert(err.attr == "email")

-- case 3: updating an existing entry
attributes = {
	id = "1",
	fname = "Jane",
	lname = "Cruz",
	full_name = "Jane Cruz",
	email = "jane@example.org",
}

assert("1" == user:save(db, attributes))

-- case 3.1: verify the hash
local values = db:call("HMGET", "User:1", "email", "fname", "lname")
assert(3 == db:call("HLEN", "User:1"))
assert(values[1] == "jane@example.org")
assert(values[2] == "Jane")
assert(values[3] == "Cruz")

-- case 3.2: verify indices
local indices = db:call("SMEMBERS", "User:indices:full_name:Jane Cruz")
assert(indices[1] == "1")

local _indices = db:call("SMEMBERS", "User:1:_indices")
assert(_indices[1] == "User:indices:full_name:Jane Cruz")

-- case 3.3: verify uniques
local id = db:call("HGET", "User:uniques:email", "jane@example.org")
assert(id == "1")

local _uniques = db:call("HGETALL", "User:1:_uniques")
assert(_uniques[1] == "User:uniques:email")
assert(_uniques[2] == "jane@example.org")

-- case 3.4: verify User:all set
local all = db:call("SMEMBERS", "User:all")
assert(#all == 1)
assert(all[1] == "1")

-- We've won ;-)
print("All tests passed.")
