local msgpack = require("cmsgpack")

local SAVE = "lib/save-d84093e.lua"
local DELETE = "lib/delete-55e478d.lua"

-- @utility auxiliary functions
local util = {}

local extract_attribs = function(self, attributes)
	local res = {}

	for _, att in ipairs(self.attributes) do
		local val = attributes[att]

		if val and val ~= "" then
			res[#res+1] = att
			res[#res+1] = val
		end
	end

	return res
end

local extract_indices = function(self, attributes)
	local res = {}

	for _, attr in ipairs(self.indices) do
		res[attr] = util.array(attributes[attr])
	end

	return res
end

local extract_uniques = function(self, attributes)
	local res = {}

	for _, attr in ipairs(self.uniques) do
		res[attr] = attributes[attr]
	end

	return res
end

-- regex matcher for unique index violation error in lua proc
local UNIQUE_INDEX_VIOLATION = "UniqueIndexViolation: (%w+)"

local save = function(self, db, attributes)
	local features = {
		name = self.name
	}

	if attributes.id then
		features.id = attributes.id
	end

	local attribs = extract_attribs(self, attributes)
	local indices = extract_indices(self, attributes)
	local uniques = extract_uniques(self, attributes)

	local response = util.script(db, SAVE, "0",
		msgpack.pack(features),
		msgpack.pack(attribs),
		msgpack.pack(indices),
		msgpack.pack(uniques)
	)

	local attr = string.match(response, UNIQUE_INDEX_VIOLATION)

	if attr then
		return nil, { code = "UniqueIndexViolation", attr = attr }
	end

	return response
end

local delete = function(self, db, attributes)
	local features = {
		name = self.name
	}

	if attributes.id then
		features.id = attributes.id
		features.key = self.name .. ':' .. attributes.id
	end

	local uniques = extract_uniques(self, attributes)
	local tracked = self.tracked

	local response = util.script(db, DELETE, "0",
		msgpack.pack(features),
		msgpack.pack(uniques),
		msgpack.pack(tracked)
	)

	return response
end

local to_index = function(self, field, value)
	return string.format("%s:indices:%s:%s", self.name, field, value)
end

local to_indices = function(self, field, value)
	if type(value) == "table" then
		return util.map(value, function(_, val)
			return to_index(self, field, val)
		end)
	else
		return { to_index(self, field, value) }
	end
end

local fetch = function(self, db, id)
	local key = self.name .. ":" .. id

	local values = db:call("HMGET", key, unpack(self.attributes))
	local record = util.zip(self.attributes, values)

	record.id = id

	return record
end

local find = function(self, db, filters)
	local keys = {}

	for k, v in pairs(filters) do
		util.map(to_indices(self, k, v), function(_, filter)
			return filter
		end, keys)
	end

	local ids = db:call("SINTER", unpack(keys))

	return util.map(ids, function(_, id)
		return fetch(self, db, id)
	end)
end

local with = function(self, db, att, val)
	local key = string.format("%s:uniques:%s", self.name, att)
	local id = db:call("HGET", key, val)

	return id and fetch(self, db, id)
end

util.read_file = function(file)
	local f = assert(io.open(file, "r"))
	local o = f:read("*all")

	assert(f:close())

	return o
end

util.array = function(value)
	-- the only case where we avoid indexing the value
	-- altogether.
	if value == nil then
		return {}

	elseif type(value) == "table" then
		-- case where the index value contains an array
		-- e.g. the classic tag=[book classics] example

		local res = {}

		for _, v in ipairs(value) do
			res[#res+1] = v
		end

		return res
	else
		-- for numbers, boolean values, we need it to be
		-- the string representation so we can actually
		-- find it like:
		--
		--	 User:indices:active:false
		--	 User:indices:active:true
		--
		return { tostring(value) }
	end
end

util.script = function(db, file, ...)
	local src = util.read_file(file)
	local sha = db:call("SCRIPT", "LOAD", src)

	return db:call("EVALSHA", sha, ...)
end

util.zip = function(list1, list2)
	local result = {}

	for i, v in ipairs(list1) do
		result[v] = list2[i]
	end

	return result
end

util.map = function(list, fn, result)
	result = result or {}

	for i,v in ipairs(list) do
		result[#result+1] = fn(i, v)
	end

	return result
end

local methods = {
	save = save,
	delete = delete,
	find = find,
	with = with,
	fetch = fetch
}

local model = function(name, schema)
	local self = {}

	setmetatable(self, {__index = methods})

	self.name = name
	self.attributes = schema.attributes or {}
	self.indices = schema.indices or {}
	self.uniques = schema.uniques or {}
	self.tracked = schema.tracked or {}

	return self
end

return {
	model = model
}
