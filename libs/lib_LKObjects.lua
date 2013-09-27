
-- lib_LKObjects
-- Version: 1.11
--   by: Lemon King
--


--[[
	--FUNCTIONS--
	LKObjects.SetMemoryWarning(MegaBytes)	[INT]
		Changes Max Memory Cap before Warnings are Displayed when using Render Targets

	LKObjects.SetFolder(Directory)	[STRING]
		Sets Folder to load File Definitions

	LKObjects.LoadFile(FileName, SubTable, SourceAnchor)
		Loads a Definition directly from a file in the folder set by SetFolder

	LKObjects.Create(Definition_List, SourceAnchor) [TABLE, ANCHOR]
		Used to Create On Screen Objects from a Definition Table, can be Anchored directly with a Source Anchor
		Returns ObjectPackage [TABLE]

	LKObjects.Destroy(Package)	[TABLE]
		Cleans up and Removes an Object Package Table

	--FORMATTING--
	Global:
	Name - Sets Package Name for Object [String]
	Id - Sets Object Type [Template, Anchor, RenderTarget, TrackingFrame, SceneObject (Called by Id {Plane, Box, etc})]
	Translation - Used to Position Object Releative to its Anchor or the Anchor Itself if not Anchored. [Table]
	Rotation - Alters Rotation (Roll, Pitch, Yaw, Angle [Based on Normal]) [Table]
	Scale - Changes Object Size along with Any Anchored Children Size [INT or TABLE]

	RenderTarget:
	RTGlobal - Toggles RenderTarget to be used across Object Packages on like Objects (Memory Reduction) [BOOL]
	RT - Sets Height & Width for RenderTarget, must be Divisable by 4 {height=256, width=256} [TABLE]
	Widget - Describes what is Displayed in the RenderTarget [XML String]

	SceneObject:
	SortOrder - Alters Scene Sort Ordering (Default 11, 0 - 15) [INT]
	Texture - Texture to be Displayed on SO, if custom must be in Addon XML [STRING]
	Region - Used with Texture to control what part of Texture Art is Displayed [STRING]
	Blur - Edge Blurring on Scene Object (Works only in SINEnvironment) [INT]
	Tint - Scene Object Tinting (Hex: FF33DD, HDR-RGB: {r=1.2, g=2.5, b=0.5}) [HDR-RGB FLOATS, HEX COLOR STRING]
	Alpha - Sets Alpha Level of SO (May act weirdly on some) [FLOAT]
	RT - Sets Height & Width for SO RenderTarget, must be Divisable by 4 {height=256, width=256} [TABLE, STRING]
		or Used in Conjuction with RenderTarget for Sharing a Single RT with Multiple SOs
	Widget - Describes what is Displayed in the SO RenderTarget [XML String]

	TrackingFrame:
	Scene - Controls what Scene TrackingFrame will be Rendered in. (World, Map) [STRING]
	CullAlpha - Sets Alpha Level of Frame when Occluded by World Scene Objects (0.0 - 1.0) [FLOAT]
	Latch - Player Latch Toggle Range {min,max} [TABLE]
	Widget - Describes what is Displayed in the TrackingFrame [XML STRING]

	--EXAMPLE--
	local ExampleObject = {
	{	Name 		= "Body",
		Id			= "Anchor",
		Scale		= 1,
		Translation = {x=0,y=0,z=0},
		Rotation 	= {axis={x=0,y=0,z=1},angle=0},
		LookAt		= "screen",
	},

	{	Name		= "Marker_Circle_189403_Loc",
		Id			= "RenderTarget",
		RTGlobal	= true,
		RT			= {width=256, height=256},
		Widget		= [=[<Group dimensions="dock:fill">
							<Group dimensions="dock:fill">
								<StillArt dimensions="dock:fill" style="texture:InteractArt; region:hold_bg; alpha:1"/>
								<StillArt dimensions="dock:fill" style="texture:InteractArt; region:hold_outer; saturation:0; alpha:1"/>
							</Group>
							<Group name="icon_ids" dimensions="center-x:50%; center-y:50%; height:78%; width:78%">
								<Icon name="ring" dimensions="center-x:50%; center-y:50%; height:120%; width:120%" style="saturation:1"/>
							</Group>
						</Group>]=],
	},
	{	Name		= "Marker_Location_A_Icon",
		Id			= "RenderTarget",
		RTGlobal	= true,
		RT			= {width=256, height=256},
		Widget		= [=[<Group dimensions="dock:fill">
							<Icon name="letter" dimensions="center-x:50%; center-y:50%; height:95%; width:95%" style="alpha:0.7; exposure:0.4;"/>
						</Group>]=],
	},
	
	{	Name		= "Circle",
		Id			= "plane",
		Scale		= 2,
		Translation = {x=0,y=0.05,z=0},
		Rotation 	= {axis={x=0,y=0,z=1},angle=0},
		SortOrder	= 5,
		Tint		= Component.LookupColor("sinvironment_ui"),
		RT			= "Marker_Circle_189403_Loc",
		Anchor		= "Body",
	},
	{	Name		= "Icon",
		Id			= "plane",
		Scale		= 1.2,
		Translation = {x=0,y=0,z=0},
		Rotation 	= {axis={x=0,y=0,z=1},angle=0},
		SortOrder	= 5,
		Tint		= Component.LookupColor("team"),
		RT			= "Marker_Location_A_Icon",
		Anchor		= "Body",
	},}

	local PackagedObject = LKObjects.Create(ExampleObject)
--]]

if LKObjects then return nil end

require "string"
require "table"
require "lib/lib_table"

local _, COMPONENT_NAME = Component.GetInfo()

local VIDEO_MEMORY_USE = "WARNING! %.2f MB USED!"
local VIDEO_MEMORY_WARNING = "WARNING! - %s is using too much Video Memory."
local VIDEO_MEMORY_WARNING_SET = "%s has set Memory Warning to %s MB"

local TYPE_ANCHOR = "Anchor"
local TYPE_MODEL = "Model"
local TYPE_RENDERTARGET = "RenderTarget"
local TYPE_TRACKING = "TrackingFrame"

local RT_STRING = "%s_%s_RenderTarget_%s"

local RT_Counter = -1
local RT_Global = {}	-- Shared RTs across Objects, great for reducing Memory Usage. If RTs need to be manipulated, use seperate RTs per Object.

local MemoryUse = 0
local MemoryWarn = 96	-- 96 MB
local MemoryRTIndex = {}
local MemoryDisplayWarning = false

local Directory

LKObjects = {}
local PRIVATE = {}

function PRIVATE.AddMemory(RT,w,h)
	MemoryRTIndex[RT] = PRIVATE.GetSize(w, h)
	local MB_Size = MemoryRTIndex[RT]
	local CurrentMemory = MemoryUse
	
	MemoryUse = MemoryUse + MB_Size
	if MemoryUse > MemoryWarn and CurrentMemory < MemoryWarn then
		MemoryDisplayWarning = true
		
		local Warning_Text = string.format(VIDEO_MEMORY_WARNING, COMPONENT_NAME)
		log(Warning_Text)
		Component.GenerateEvent("MY_CHAT_MESSAGE", {channel="system", text=Warning_Text})
	elseif MemoryUse > MemoryWarn then
		log(string.format(VIDEO_MEMORY_USE, MemoryUse))
	end
end

function PRIVATE.RemoveMemory(index)
	local MB_Size = MemoryRTIndex[index]
	local CurrentMemory = MemoryUse
	
	MemoryUse = MemoryUse - MB_Size
	if MemoryUse < MemoryWarn and CurrentMemory > MemoryWarn then
		MemoryDisplayWarning = false
	end
	MemoryRTIndex[index] = nil
end

function PRIVATE.GetSize(w,h)
	return ( w * h * 4 ) / 1048576
end

function LKObjects.SetMemoryWarning(MB)
	MemoryWarn = MB
	log(string.format(VIDEO_MEMORY_WARNING_SET, COMPONENT_NAME, MB))
end

function LKObjects.SetFolder(dir)
	Directory = dir
end

function LKObjects.LoadFile(file, sub, SourceAnchor)
	if not Directory then log("LKObjects - No Folder Set!") return nil end

	require(Directory.."/"..file)
	if not Object then log("LKObjects - File "..file.." has no Object Variable!") return nil
	elseif sub and Object and not Object[sub] then log("LKObjects - File "..file.." Data Not Found!") return nil end
	LKObjects.Create(Object[sub] or Object, SourceAnchor)
end

function LKObjects.Create(Definition_List, SourceAnchor)
	-- Converts Model tables into a Package for use during gameplay
	
	-- Copy Definition List
	local Definition_Copy = _table.copy(Definition_List)
	
	local Templates = {}
	local Positions = {}
	for Index, Def in ipairs(Definition_Copy) do
		if Def.Template == true then
			Templates[Def.Name] = _table.copy(Def)
			Templates[Def.Name].Name = nil
			Templates[Def.Name].Template = nil
			
			-- Capture Position
			table.insert(Positions, Index)
		end
	end
	
	-- Remove Templates from Definition Copy
	for i=#Positions,1,-1 do
		table.remove(Definition_Copy, Positions[i])
	end
	
	return PRIVATE.PackageObjects(Definition_Copy, SourceAnchor, Templates)
end

function LKObjects.Destroy(Package)
	for Name, Object in pairs(Package) do
		if type(Object) == "table" then
			if Object.Type == TYPE_ANCHOR then
				Component.RemoveAnchor(Object.Anchor)
			elseif Object.Type == TYPE_MODEL then
				Component.RemoveSceneObject(Object.Model)
				if Object.RT then
					Component.RemoveFrame(Object.FRAME)
					Component.RemoveRenderTarget(Object.RT)
					PRIVATE.RemoveMemory(Object.RT)
				end
			elseif Object.Type == TYPE_RENDERTARGET then
				if Object.RT then
					local GlobalRender = RT_Global[Object.RT]
					if Object.Global and GlobalRender.Active > 1 then
						GlobalRender.Active = GlobalRender.Active - 1
					elseif Object.Global and GlobalRender.Active == 1 then
						Component.RemoveWidget(GlobalRender.WIDGET)
						Component.RemoveFrame(GlobalRender.FRAME)
						Component.RemoveRenderTarget(Object.RT)
						PRIVATE.RemoveMemory(Object.RT)
						RT_Global[Object.RT] = nil
					elseif not Object.Global then
						if Object.WIDGET then
							Component.RemoveWidget(Object.WIDGET)
						end
						Component.RemoveFrame(Object.FRAME)
						Component.RemoveRenderTarget(Object.RT)
						PRIVATE.RemoveMemory(Object.RT)
					end
				end
			elseif Object.Type == TYPE_TRACKING then
				if Object.WIDGET then
					Component.RemoveWidget(Object.WIDGET)
				end
				Component.RemoveFrame(Object.TrackingFrame)
			end
		end
	end
	Package = nil
end

function PRIVATE.PackageObjects(Definition_List, SourceAnchor, Templates)
	local Packed = {}
	for index, Def in ipairs(Definition_List) do
		if Def.Template then
			local Template = Templates[Def.Template]
			Def = PRIVATE.CombineTemplate(Def, Template)
		end
		if Def.Id then
			local ObjectType = PRIVATE.GetType(Def.Id)
			local Name = PRIVATE.GetName(Def.Name, index, ObjectType)
		
			Packed[Name] = PRIVATE.CreateObject(ObjectType, Def.Id)
			local Object = Packed[Name]
			Object.Name = Name
			Object.Origin = {Translation=Def.Translation,Rotation=Def.Rotation,Scale=Def.Scale}

			Object:SetAnchor(Def, Packed, SourceAnchor)
			
			PRIVATE.SetObjectParams(Object, Def, Packed)
		end
	end
	
	return Packed
end

function PRIVATE.CreateObject(Type, visual_index)
	local Object = {Type=Type, State="Default"}
	
	if Type == TYPE_ANCHOR then
		Object.Anchor = Component.CreateAnchor()
	
		Object.SetConnecting = function(self, ...) self[Type]:SetConnecting(...) end
	elseif Type == TYPE_MODEL then
		Object.Model = Component.CreateSceneObject(visual_index)
		Object.Anchor = Object.Model:GetAnchor()
	
		Object.SetTexture = function(self, ...) self[Type]:SetTexture(...) end
		Object.SetRegion = function(self, ...) self[Type]:SetRegion(...) end
		Object.SetTint = function(self, ...) self[Type]:SetParam("tint", ...) end
		Object.SetTextureFrame = function(self, ...) self[Type]:SetTextureFrame(...) end
		
		Object.SetSortOrder = function(self, ...) self[Type]:SetSortOrder(...) end
	elseif Type == TYPE_TRACKING then
		Object.TrackingFrame = Component.CreateFrame("TrackingFrame")
		Object.TrackingFrame:SetScene("world")
		--Object.TrackingFrame:Show()
		
		Object.Anchor = Object.TrackingFrame:GetAnchor()
		
		Object.SetScene = function(self, ...) self[Type]:SetScene(...) end
		
		Object.SetBounds = function(self, ...) self[Type]:SetBounds(...) end
		
			
		Object.BindEvent = function(self, ...) self[Type]:BindEvent(...) end
		Object.SetDistanceLatch = function(self, ...) self[Type]:SetDistanceLatch(...) end
	elseif Type == TYPE_RENDERTARGET then
		Object.Global = false
	end
	Object.SetAnchor = PRIVATE.SetAnchor
	Object.GetAnchor = function(self) return self[Type]:GetAnchor() end
	Object.SetParent = function(self, ...) self[Type]:SetParent(...) end
	Object.GetParent = function(self) return self[Type]:GetParent() end
	
	Object.SetParam = function(self, ...) self[Type]:SetParam(...) end
	Object.ParamTo = function(self, ...) self[Type]:ParamTo(...) end
	Object.QueueParam = function(self, ...) self[Type]:QueueParam(...) end
	Object.FinishParam = function(self, ...) self[Type]:FinishParam(...) end
	Object.GetParam = function(self, param_name) return self[Type]:GetParam(param_name) end
	
	Object.LookAt = function(self, ...) self.Anchor:LookAt(...) end
	
	Object.BindTo = PRIVATE.BindTo	
	Object.BindToPlayer = function(self, hardpoint) self:BindTo("Player", hardpoint) end
	Object.BindToEntity = function(self, ...) self[Type]:BindToEntity(...) end
	Object.BindToWorld = function(self) self[Type]:BindToWorld() end
	
	--[[ TODO?
	Object.SetState = function(self, ...) end
	Object.StateTo = function(self, ...) end
	Object.QueueState = function(self, ...) end
	Object.FinishState = function(self, ...) end
	Object.GetState = function(self) return self.State end
	--]]
	
	return Object
end

function PRIVATE.SetObjectParams(Object, Object_Def, PackagedObjects)
	if Object.Type == TYPE_MODEL then
		if Object_Def.Texture and not Object_Def.RT then
			Object:SetTexture(Object_Def.Texture, Object_Def.Region)
		end
		if Object_Def.Blur then
			Object:SetParam("blur", Object_Def.Blur)
		end
		if Object_Def.Tint then
			Object:SetParam("tint", Object_Def.Tint)
		end
		if Object_Def.Alpha then
			Object:SetParam("alpha", Object_Def.Alpha)
		end
		
		if type(Object_Def.RT) == "table" and Object_Def.RT.width and Object_Def.RT.height then
			local RT = string.format(RT_STRING, Component.GetInfo(), Object.Name, PRIVATE.GetRT_ID())
			Component.CreateRenderTarget(RT, Object_Def.RT.width, Object_Def.RT.height)
			Object.RT = RT
			Object.FRAME = Component.CreateFrame("TextureFrame")
			Object.FRAME:SetTexture(Object.RT)
			Object:SetTexture(Object.RT)
			Object:SetTextureFrame(Object.FRAME)
			if Object_Def.Widget then
				Object.WIDGET = Component.CreateWidget(Object_Def.Widget, Object.FRAME)
				Object.GetChild = function(self, ...) return self.WIDGET:GetChild(...) end
			end
			PRIVATE.AddMemory(RT, Object_Def.RT.width, Object_Def.RT.height)
		elseif type(Object_Def.RT) == "string" then
			local Source = PackagedObjects[Object_Def.RT]
			Object:SetTexture(Source.RT)
			Object:SetTextureFrame(Source.FRAME)
		elseif Object_Def.Frame and Object_Def.Texture and not Object_Def.RT then
			Object:SetTextureFrame(Object_Def.Frame)
		end
		if Object_Def.SortOrder then
			Object:SetSortOrder(Object_Def.SortOrder)
		end
	elseif Object.Type == TYPE_RENDERTARGET then
		local RT = PRIVATE.CreateRenderTarget(Object.Name, Object_Def.RT.width, Object_Def.RT.height, Object_Def.RTGlobal)
		Object.RT = RT
		if Object_Def.RTGlobal then
			Object.Global = true
			Object.FRAME = RT_Global[RT].FRAME
			if not RT_Global[RT].WIDGET then
				RT_Global[RT].WIDGET = Component.CreateWidget(Object_Def.Widget, RT_Global[RT].FRAME)
			end
			Object.WIDGET = RT_Global[RT].WIDGET
			Object.GetChild = function(self, ...) return self.WIDGET:GetChild(...) end
		else
			Object.FRAME = Component.CreateFrame("TextureFrame")
			Object.FRAME:SetTexture(Object.RT)
			if Object_Def.Widget then
				Object.WIDGET = Component.CreateWidget(Object_Def.Widget, Object.FRAME)
				Object.GetChild = function(self, ...) return self.WIDGET:GetChild(...) end
			end
		end
	end
	if Object.Type == TYPE_TRACKING then
		if Object_Def.Scene then
			Object:SetScene(Object_Def.Scene)
		end
		if Object_Def.CullAlpha then
			Object:SetParam("cullalpha", Object_Def.CullAlpha)
		end
		if Object_Def.Latch then
			Object:SetDistanceLatch(Object_Def.Latch.min, Object_Def.Latch.max)
		end
		if Object_Def.Widget then
			Object.WIDGET = Component.CreateWidget(Object_Def.Widget, Object.TrackingFrame)
			Object.GetChild = function(self, ...) return self.WIDGET:GetChild(...) end
			Object.WIDGET:Show()
		end
	end


	if Object_Def.BindTo then
		Object:BindTo(Object_Def.BindTo, Object_Def.Hardpoint)
	end
	if Object_Def.LookAt then
		local Anchor, Offset
		if type(Object_Def.LookAt) == "table" then
			Anchor = Object_Def.LookAt.anchor
			Offset = Object_Def.LookAt.offset
		else
			Anchor = Object_Def.LookAt
		end
		local AnchorName = Object_Def.LookAt
		if PackagedObjects[AnchorName] then
			local pack = { PackagedObjects[AnchorName].Anchor, Offset }
			Object:LookAt(unpack(pack))
		elseif Object_Def.LookAt then
			--local-x, local-y, local-z, camera, screen, sky
			local pack = { Anchor, Offset }
			Object:LookAt(unpack(pack))
		else
			log("Anchor Not Found! ("..(Anchor)..") or invalid Mode [local-x, local-y, local-z, camera, screen, sky]")
		end
	end
	if Object_Def.Connecting then
		Object:SetConnecting(Object_Def.Connecting)
	end
	if Object_Def.Scale then
		local Scale = Object_Def.Scale
		if type(Scale) == "number" then
			Scale = {x=Scale,y=Scale,z=Scale}		
		end
		Object:SetParam("scale", Scale)
	end
	if Object_Def.Translation then
		Object:SetParam("translation", Object_Def.Translation)
	end
	if Object_Def.Rotation then
		Object:SetParam("rotation", Object_Def.Rotation)
	end
end

function PRIVATE.CreateRenderTarget(Name, w, h, global)
	local RT = string.format(RT_STRING, COMPONENT_NAME, Name, PRIVATE.GetRT_ID(global))
	if not global then
		Component.CreateRenderTarget(RT, w, h)
		PRIVATE.AddMemory(RT, w, h)
	elseif ( global and not RT_Global[RT] ) then
		RT_Global[RT] = {Active = 1}
		Component.CreateRenderTarget(RT, w, h)
		PRIVATE.AddMemory(RT, w, h)
		RT_Global[RT].FRAME = Component.CreateFrame("TextureFrame")
		RT_Global[RT].FRAME:SetTexture(RT)
	elseif global and RT_Global[RT] then
		RT_Global[RT].Active = RT_Global[RT].Active + 1
	end
	return RT
end

function PRIVATE.BindTo(self, Binding, ...)
	local Type = self.Type
	if Binding then
		Binding = string.lower(Binding)
	end
	
	if Binding == "entity" then
		local entityId, hardpoint = ...
		
		self.Anchor:BindToEntity(entityId, hardpoint)
	elseif Binding == "player" then
		local hardpoint = ...
		local PlayerId = Player.GetTargetId()
		
		self.Anchor:BindToEntity(PlayerId, hardpoint)
	elseif Binding == "world" then
		self.Anchor:BindToWorld()
	end
end

function PRIVATE.SetAnchor(self, Object_Def, PackagedObjects, SourceAnchor)
	if Object_Def.Anchor then
		if Object_Def.Anchor == "{source}" and SourceAnchor then
			self.Anchor:SetParent(SourceAnchor)		
		else
			if PackagedObjects[Object_Def.Anchor] then
				local Anchor = PackagedObjects[Object_Def.Anchor].Anchor
				self.Anchor:SetParent(Anchor)
			else
				log("Missing Anchor! ("..(Object_Def.Anchor)..")")	
			end
		end
	elseif not Object_Def.Anchor and not Object_Def.BindTo then
		--log(self.Name.." has no Anchor/Binding!")
	end
end

function PRIVATE.GetName(Name, index, Object_Type)
	return Name or Object_Type.."_"..index
end

function PRIVATE.GetType(id)
	if type(id) == "string" then
		if string.lower(id) == "anchor" then
			return TYPE_ANCHOR
		elseif string.lower(id) == "rendertarget" then
			return TYPE_RENDERTARGET
		elseif string.lower(id) == "trackingframe" then
			return TYPE_TRACKING
		end
	end
	return TYPE_MODEL
end

function PRIVATE.CombineTemplate(Base, Template)
	local Combined = _table.copy(Template)
	for index, data in pairs(Base) do
		Combined[index] = data
	end
	return Combined
end

function PRIVATE.GetRT_ID(global)
	if global then return "GLOBAL" end
	RT_Counter = RT_Counter + 1
	return RT_Counter
end
