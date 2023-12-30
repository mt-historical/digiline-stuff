
-- Created by jogag
-- Part of the Digiline Stuff pack
-- Mod: Digiprinter - a digiline-controlled printer
-- It prints paper via the Writable Paper (memorandum) mod
-- then it sends "OK" or "ERR_PAPER" or "ERR_SPACE"

local OK_MSG = "OK"
local NO_PAPER_MSG = "ERR_PAPER"
local NO_SPACE_MSG = "ERR_SPACE"
local BUSY_MSG = "ERR_BUSY"

local PRINT_DELAY = 3

-- taken from pipeworks mod
local function facedir_to_dir(facedir)
	--a table of possible dirs
	return ({{x=0, y=0, z=1},
		{x=1, y=0, z=0},
		{x=0, y=0, z=-1},
		{x=-1, y=0, z=0},
		{x=0, y=-1, z=0},
		{x=0, y=1, z=0}})

			--indexed into by a table of correlating facedirs
			[({[0]=1, 2, 3, 4,
				5, 2, 6, 4,
				6, 2, 5, 4,
				1, 5, 3, 6,
				1, 6, 3, 5,
				1, 4, 3, 2})

				--indexed into by the facedir in question
				[facedir]]
end

local function idle_state(meta)
	meta:set_string("infotext", "Digiline Printer Idle")
	meta:set_string("message", "")
	meta:set_int("busy", 0)
end

local function busy_state(meta, msg)
	meta:set_string("infotext", "Digiline Printer Busy")
	meta:set_string("message", msg)
	meta:set_int("busy", 1)
end

local function is_busy(meta)
	return meta:get_int("busy") == 1
end

local print_paper = function(pos, elapsed)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local channel = meta:get_string("channel")

	local vel = facedir_to_dir(node.param2)
	local front = { x = pos.x - vel.x, y = pos.y - vel.y, z = pos.z - vel.z }
	-- if minetest.get_node(front).name ~= "air" then
	-- 	-- search for the next block
	-- 	vel = { x = vel.x * 2, y = vel.y * 2, z = vel.z * 2 }
	-- 	front = { x = pos.x - vel.x, y = pos.y - vel.y, z = pos.z - vel.z }
	-- end

	if inv:is_empty("paper") then
		digiline:receptor_send(pos, digiline.rules.default, channel, NO_PAPER_MSG)
	elseif minetest.get_node(front).name ~= "air" then
		digiline:receptor_send(pos, digiline.rules.default, channel, NO_SPACE_MSG)
	else
		local paper = inv:get_stack("paper", 1)
		paper:take_item()
		inv:set_stack("paper", 1, paper)

		local msg = meta:get_string("message")

		minetest.add_node(front, {
			name = (msg == "" and "memorandum:letter_empty" or "memorandum:letter_written"),
			param2 = node.param2
		})

		local paperMeta = minetest.get_meta(front)
		paperMeta:set_string("text", msg)
		paperMeta:set_string("signed", "Digiprinter")
		paperMeta:set_string("infotext", 'On this piece of paper is written: "'..msg..'" Printed with Digiprinter') -- xD

		digiline:receptor_send(pos, digiline.rules.default, channel, OK_MSG)
	end
	idle_state(minetest.get_meta(pos))
end

local on_digiline_receive = function(pos, node, channel, msg)
	if type(msg) ~= "string" then
		return
	end
	local meta = minetest.get_meta(pos)
	if channel == meta:get_string("channel") then
		local inv = meta:get_inventory()
		if is_busy(meta) then
			digiline:receptor_send(pos, digiline.rules.default, channel, BUSY_MSG)
		elseif inv:is_empty("paper") then
			digiline:receptor_send(pos, digiline.rules.default, channel, NO_PAPER_MSG)
		else
			busy_state(meta, msg)
			minetest.get_node_timer(pos):start(PRINT_DELAY*math.ceil(#msg / 40))
		end
	end
end

-- taken from computer mod xD
minetest.register_node("digiprinter:printer", {
	description = "Digiline Printer",
	inventory_image = "digiprinter_inv.png",
	tiles = {"digiprinter_t.png","digiprinter_bt.png","digiprinter_l.png",
			"digiprinter_r.png","digiprinter_b.png","digiprinter_f.png"},
	use_texture_alpha = minetest.features.use_texture_alpha_string_modes and "opaque" or nil,
	paramtype = "light",
	paramtype2 = "facedir",
	walkable = true,
	groups = {snappy=3},
	sound = default.node_sound_wood_defaults(),
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.4375, -0.3125, -0.125, 0.4375, -0.0625, 0.375},
			{-0.4375, -0.5, -0.125, 0.4375, -0.4375, 0.375},
			{-0.4375, -0.5, -0.125, -0.25, -0.0625, 0.375},
			{0.25, -0.5, -0.125, 0.4375, -0.0625, 0.375},
			{-0.4375, -0.5, -0.0625, 0.4375, -0.0625, 0.375},
			{-0.375, -0.4375, 0.25, 0.375, -0.0625, 0.4375},
			{-0.25, -0.25, 0.4375, 0.25, 0.0625, 0.5},
			{-0.25, -0.481132, -0.3125, 0.25, -0.4375, 0}
		},
	},
	digiline = {
		receptor = {},
		effector = {
			action = on_digiline_receive
		},
	},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		idle_state(meta)
		meta:set_string("channel", "")
		meta:set_string("formspec", "size[8,10]"..
			((default and default.gui_bg) or "")..
			((default and default.gui_bg_img) or "")..
			((default and default.gui_slots) or "")..
			"label[0,0;Digiline Printer]"..
			"label[3.5,2;Paper]"..
			"list[current_name;paper;3.5,2.5;1,1;]"..
			"field[2,3.5;5,5;channel;Channel;${channel}]"..
			((default and default.get_hotbar_bg) and default.get_hotbar_bg(0,6) or "")..
			"list[current_player;main;0,6;8,4;]")
		local inv = meta:get_inventory()
		inv:set_size("paper", 1)
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		if fields.channel then minetest.get_meta(pos):set_string("channel", fields.channel) end
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		if minetest.is_protected(pos, player:get_player_name()) then return 0 end
		return (stack:get_name() == "default:paper" and stack:get_count() or 0)
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		if is_busy(minetest.get_meta(pos)) then
			return 0
		end
		return stack:get_count() or 0
	end,
	can_dig = function(pos, player)
		return minetest.get_meta(pos):get_inventory():is_empty("paper")
	end,
	on_timer = print_paper
})

-- printer crafting:
-- +-------+
-- | ? P ? |
-- | ? M ? |
-- | ? D ? |
-- +-------+
minetest.register_craft({
	output = "digiprinter:printer",
	recipe = {
		{ "homedecor", "default:paper", "" },
		{ "", "default:mese_crystal", "" },
		{ "", "digilines:wire_std_000000", "" },
	},
})

