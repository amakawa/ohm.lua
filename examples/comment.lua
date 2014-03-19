local ohm = require("ohm")

return ohm.model("Comment", {
	attributes = {
		"body",
		"name",
		"email"
	}
})
