require("mod-gui")
require("util")

-- script.on_event("tas-logger-print", 
    -- function(event)
        -- global.print = not global.print
    -- end
-- )

function glob_init()
	global.dir = {"North","Northeast","East","Southeast","South","Southwest","West","Northwest"}
	global.gshow = false
	global.ptdir = -1
	global.walk = false
	global.file = "log.txt"
	global.position = {x = 0 ,y = 0}
	global.print = false
	global.write = false
	global.mine = false
	global.craft_count = 0
	global.lasttick = 0
	global.linenum = 1	
	global.seg = 1
	global.inv = 0 
	-- global.cstack = {name = "name",count = 0}
	-- global.lstack =  {name = "name",count = 0}
end

function gui_init(player)
    local flow = mod_gui.get_button_flow(player)
    if not flow["tas-logger-button"] then
      local button = flow.add
      {
        type = "sprite-button",
        name = "tas-logger-button",
        style = mod_gui.button_style,
        sprite = "addicon",
        tooltip = {"tas-logger-button-tooltip"}
      }
      button.style.visible = true
    end
end

function gui_open_frame(player)
    local flow = mod_gui.get_frame_flow(player)
    local frame = flow["tas-logger-frame"]
	
	global.gshow = true
	if frame then
		global.gshow = false
        frame.destroy()
        return
    end
    -- Now we can build the GUI.
	local entity = player.selected
	local pos = {x = 0,y = 0}
	local lname = "localised"
	local pname = "name"
	local typ = "type"
	local dir = 0
	if entity then
		pos = entity.position
		pname = entity.name
		lname = entity.localised_name
		typ = entity.type
		dir = entity.direction
	end
    gui = mod_gui.get_frame_flow(player)
    frame = gui.add{
        type = "frame",
        caption ={"", {"name"}, ""},
        name = "tas-logger-frame",
        direction = "vertical"
    }
	local table = frame.add{type="table", name="table", colspan=2}
	table.add{type="label", caption={"", {"entity"}, ":"}, style="caption_label_style"}
	table.add{type="label", caption=""}
	table.add{type="label", caption={"", {"pname"}, ":"}}
	table.add{type="label", captionn=pname, name="pname"}
	table.add{type="label", caption={"", {"lname"}, ":"}}
	table.add{type="label", caption=lname, name="lname"}
	table.add{type="label", caption={"", {"typ"}, ":"}}
	table.add{type="label", caption=typ, name="typ"}
	table.add{type="label", caption={"", {"pos"}, ":"}}
	table.add{type="label", caption=""}
	table.add{type="label", caption="X"}
	table.add{type="label", caption=util.format_number(pos.x), name="posx"}
	table.add{type="label", caption="Y"}
	table.add{type="label", caption=util.format_number(pos.y), name="posy"}
	table.add{type="label", caption={"", {"dir"}, ":"}}
	table.add{type="label", caption= game.direction_to_string(dir), name="dir"}
	table.add{type="label", caption={"", {"cprint"}, ":"}}
	table.add{type="checkbox", name="cprint", state = global.print}
	table.add{type="label", caption={"", {"cwrite"}, ":"}}
	table.add{type="checkbox", name="cwrite", state = global.write}
end

function position_update_gui(player)
  local flow = mod_gui.get_frame_flow(player)
  local frame = flow["tas-logger-frame"]
  local table = frame.table
  local entity = player.selected
  if entity then
	  table.pname.caption = entity.name 
	  table.lname.caption = entity.localised_name
	  table.typ.caption = entity.type
	  table.posx.caption = entity.position.x
	  table.posy.caption = entity.position.y
	  table.dir.caption = game.direction_to_string(entity.direction)
  end
end

function b_to_s(bool)
	if bool then return "true"
	else return "false" end
end

function write_to_file(tick,msg)
	local dif = tick - global.lasttick
	local msg = "commandqueue["..global.linenum.."][".. dif .. "]=" .. msg .."\n" 
	if global.print then game.players[1].print(msg) end
	if global.write then game.write_file(global.file,msg, true) end
	global.linenum = global.linenum+1
	global.lasttick = tick
end

script.on_init(function()
	glob_init()
    for _, player in pairs(game.players) do
        gui_init(player)
    end
	game.write_file(global.file,"New Run:", true)
end)

script.on_configuration_changed(function()
	glob_init()
    for _, player in pairs(game.players) do
        gui_init(player)
    end
end)

script.on_event(defines.events.on_player_created, function(event)
	gui_init(game.players[event.player_index])
end)

script.on_event(defines.events.on_gui_click, function(event) 

    local element = event.element
    local player = game.players[event.player_index]
    
    if element.name == "tas-logger-button" then
        gui_open_frame(player)
    elseif element.name == "cprint" then
		global.print = not global.print
	elseif element.name == "cwrite" then
		global.write = not global.write
		if global.write then 
			game.write_file(global.file,"Segment "..global.seg, true)
			global.seg = global.seg +1
		end		
	end

end)

script.on_event(defines.events.on_tick, function(event)
	if global.print or global.write then
		local walk = game.players[1].walking_state
		local mine = game.players[1].mining_state
		if (not walk.walking and global.walk) or (walk.walking and not global.walk) or not(walk.direction == global.ptdir) then
			global.walk = walk.walking 
			global.ptdir = walk.direction 
			write_to_file(event.tick ,"{{\"move\","..b_to_s(global.walk).."," .. global.ptdir .. "}}")
		end
		if (not mine.mining and global.mine) or (mine.mining and not global.mine)  then
			global.mine = mine.mining 
			write_to_file(event.tick ,"{{\"mine\","..b_to_s(global.mine)..",{" .. string.format("%.1f",global.position.x).. "," .. string.format("%.1f",global.position.y) .. "}}}")
		end
		if game.players[1].crafting_queue then
			local c = global.craft_count
			local cq = game.players[1].crafting_queue
			if c <  #cq then
				write_to_file(event.tick ,"{{\"craft\",\"" .. cq[#cq].recipe .. "\","..cq[#cq].count.."}}")
			end
			if c ~= #cq then 
				global.craft_count = #cq
			end
		elseif global.craft_count ~= 0 then global.craft_count = 0 end
	end
end)

script.on_event(defines.events.on_selected_entity_changed, function(event) 
	local player = game.players[event.player_index]
	if player.selected then global.position = player.selected.position end
	if global.gshow then position_update_gui(player) end
end)

script.on_event(defines.events.on_player_rotated_entity, function(event) 
	if global.gshow then
		local player = game.players[event.player_index]
		position_update_gui(player)
    end
end)

script.on_event(defines.events.on_built_entity, function(event) 
	if global.print or global.write then 
		write_to_file(event.tick,"{{\"built\",\"" .. event.created_entity.name .. "\","..event.created_entity.direction..",{" .. event.created_entity.position.x .. "," .. event.created_entity.position.y .. "},"..global.inv.."}}") 
	end
end)

script.on_event(defines.events.on_research_started, function(event) 
	if global.print or global.write then 
		write_to_file(event.tick,"{{\"tech\",\"".. event.research.name .. "\"}}")
	end
end)

-- script.on_event(defines.events.on_picked_up_item, function(event) 
	-- write_to_file(event.tick, "pickup " .. event.item_stack.name) end
-- end)


--tests for tracking items put in entitys (doesn't function):

-- script.on_event(defines.events.on_player_main_inventory_changed, function(event) 
	-- if global.print or global.write then 
		-- global.inv = defines.inventory.player_main
	-- end
-- end)

-- script.on_event(defines.events.on_player_quickbar_inventory_changed, function(event) 
	-- if global.print or global.write then 
		-- global.inv = defines.inventory.player_quickbar
	-- end
-- end)

-- script.on_event(defines.events.on_player_cursor_stack_changed, function(event) 
	-- write_to_file(event.tick ,"{{\"put\"}}")
	-- local player = game.players[event.player_index]
	-- global.lstack.name = global.cstack.name
	-- global.lstack.count = global.cstack.count
	-- if player.cursor_stack.valid_for_read then
		-- global.cstack.name = player.cursor_stack.name
		-- global.cstack.count = player.cursor_stack.count
	-- end
	-- if player.selected then
		-- local count = global.lstack.count - global.cstack.count
		-- write_to_file(event.tick ,"{{\"put,{" .. global.position.x .. "," .. global.position.y .. "},"..global.lstack.name..","..count..","..global.inv..",\"}}")
	-- end
-- end)