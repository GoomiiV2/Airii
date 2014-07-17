--==============================================================================================
-- Arkii
-- Airii, in world flight timetables :D
--==============================================================================================

require "string";
require "math";
require "table";
require "lib/lib_Debug";
require "lib/lib_Vector";
require 'lib/lib_Slash';
require "lib/lib_TextFormat";
require "lib/lib_InterfaceOptions"
require "lib/lib_MapMarker"
require "./libs/lib_LKObjects";
require "./libs/Lokii";
require "./libs/Uii";
require "./objs/panel";
require "./positions";
require "./Printer_Positions";
require "./Dropship";

--=====================
--		Constants    --
--=====================
local ADDONNAME = "Airii";
local PANEL_OPEN_RANGE_MAX = 100;
UPDATE_INTERVAL = 1; -- In seconds
local PANEL_ANIM_DURR = 0.3;
local OPEN_SOUND = "Play_UI_Login_Confirm";
local CLOSE_SOUND = "Play_UI_Ticker_LoudSecondTick";
local SHORT_NAMES =
{
	["Arclight Fragment Base"] = "Arclight Base",
	["Nautilus Science Facility"] = "Nautilus Facility",
	["Shanty Town"] = "Shanty",
	["Sigu's Sanctuary"] = "Sigu's",
	["Copacabana"] = "Copa",
};
MAX_DESTINATIONS = 10;
HAS_LANDED_RANGE = 10;
AVG_DROPSHIP_SPEED = 45; -- If not useing a calculated speed, Sligly faster than the top speed to allow for the flight paths
PANEL_SCALE_MAX = 10;
PANEL_HALF_WIDTH = 0.10;

--=====================
--		Varables     --
--=====================
local panels = {};
local RenderTarget = {};
local DropShips = {};
local CB_Update = {};
local IsPlayerNearPanel = false;
CalculateSpeed = false;
local EnableDebuging = false;
local EnableScanlines = true;
local EnableAnimatedScanlines = true;
local EnableMapMarkers = true;
FREINDLY_COLOR = "00e43b";
HOSTILE_COLOR = "de2a2a";
SEPARATOR_COLOR = "e6e6e6";
local PanelOpenRange = 5;
local PanelScale = 1;
local PanelPositions = {};
local MapMarkers = {};
local EnablePrinterPanels = true;
local IsInZone = true;
local NotInRangeMsgs = 
{
    Arrivals = nil,
    Departures = nil
}
local isInSinEnviro = false; -- Hack to hide stuff so we don't block the inputs, because sort order does nothing :/

--=====================
--		Events       --
--=====================
function OnComponentLoad()
	InterfaceOptions.SetCallbackFunc(UIHELPER.CheckCallbacks, ADDONNAME);
	
	Lokii.AddLang("en", "./lang/EN");
	Lokii.AddLang("de", "./lang/DE");
	Lokii.SetBaseLang("en");
	Lokii.SetToLocale();
		
	-- In game Objects
	LKObjects.SetMemoryWarning(5);
	BuildPositionTable();
	CreatePanels();
	ClosePanel();
	
	CreateInterfaceOptions();
	
	LIB_SLASH.BindCallback({slash_list='apos', description='/', func=PrintAimPos});
end

function OnEntityCheck(args)	
	if (args.type == "vehicle") then
		local id = args.entityId;
		DropShips[id] = DropShip.Create(id, RenderTarget:GetChild("content"):GetChild("Arrivals"));
		Debug.Log("OnEntityCheck: Found Dropship, tracing,", id);
	end
end

function OnEntityLost(args)
	if (args.type == "vehicle") then
		local id = args.entityId;
		Debug.Log("OnEntityLost: Dropship left range,", id, "removing.");
		DropShips[id] = nil;
	end
end

function OnEnterZone(args)
	IsInZone = true;
end

function OnExitZone(args)
	IsInZone = false;
end

function OnPlayerReady(args)
	CB_Update = Callback2.CreateCycle(UpdateDropships, nil);
	CB_Update:Run(UPDATE_INTERVAL);
end

function OnSinEnviroToggled(args)
	-- Ok so this is hacky and I do sorta kind feel bad buuuut, I jsut want to have this fixed fast soooooo, don't judge pleaseeee, 'kay?
	isInSinEnviro = not isInSinEnviro;
	
	if (isInSinEnviro == true) then
		RemovePanels();
		log("Panels Removed");
	else
		CreatePanels();
		ClosePanel();
		log("Panels Added");
	end
end

--=====================
--		Callacks     --
--=====================
function PrintAimPos()
	local AimPos = Player.GetAimPosition();
	local PlyPos = Player.GetPosition();
	local pos = Game.WorldToChunkCoord(AimPos.x, AimPos.y, AimPos.z);
	Debug.Log("POI: "..GetPoiName());
	Debug.Log("{"..pos.chunkX..", "..pos.chunkY..", "..pos.x..", "..pos.y..", "..pos.z.."}");
	local dx = PlyPos.x - AimPos.x;
	local dy = PlyPos.y - AimPos.y;
	local angle = 180 + math.deg(math.atan2(dx, dy));
	Debug.Log("Angle: " .. angle);
end

--=====================
--		Functions    --
--=====================

function CreatePanels()
	local index = 1;
	for i, v in pairs(PanelPositions) do
		panels[index] = {};
		panels[index].POI = tostring(i);

		-- Set the panels scale, There has to be a nicer way to update these :/
		PANEL[3].Scale = 3 + PanelScale;

		-- Messy but it's cold and late ;^;
		local pos = Game.ChunkCoordToWorld(unpack(v.Translation));
		if (PanelScale > 1) then
			pos.z = pos.z + (PANEL_HALF_WIDTH * PanelScale);
		end

		panels[index].Panel = LKObjects.Create(PANEL);
		panels[index].Panel.pos:SetParam("Translation", pos);
		panels[index].Panel.pos:SetParam("Rotation", v.Rotation);
		index = index + 1;
	end
	RenderTarget = panels[1].Panel.panel_rt;
	RenderTarget:GetChild("mesh"):SetTexture("PanelTex");
	RenderTarget:GetChild("mesh"):SetPercent(1);
	RenderTarget:GetChild("AiriiMesh"):Play(0, 1, 5, true, "linear");
	
	if (EnableAnimatedScanlines) then
		RenderTarget:GetChild("PanelScanlinesOpen"):Play(0, 1, 20, true, "linear");
		RenderTarget:GetChild("PanelScanlinesClosed"):Play(0, 1, 20, true, "linear");
	end
	
	RenderTarget:GetChild("content"):GetChild("ArriveRouteHeader"):GetChild("route"):SetText(Lokii.GetString("ROUTE"));
	RenderTarget:GetChild("content"):GetChild("ArriveRouteHeader"):GetChild("eta"):SetText(Lokii.GetString("ETA"));
	RenderTarget:GetChild("content"):GetChild("DepartRouteHeader"):GetChild("route"):SetText(Lokii.GetString("ROUTE"));
	RenderTarget:GetChild("content"):GetChild("DepartRouteHeader"):GetChild("eta"):SetText(Lokii.GetString("ETA"));
	SetArriveDepartHeaders("");
    
    NotInRangeMsgs.Arrivals = RenderTarget:GetChild("content"):GetChild("ArrivalsNoShip"):GetChild("grp");
    NotInRangeMsgs.Departures = RenderTarget:GetChild("content"):GetChild("DeparturesNoShip"):GetChild("grp");
    
    NotInRangeMsgs.Arrivals:GetChild("text"):SetText(Lokii.GetString("NO_DROPSHIPS"));
    NotInRangeMsgs.Departures:GetChild("text"):SetText(Lokii.GetString("NO_DROPSHIPS"));
end

function RemovePanels()
	for i, v in pairs(panels) do
		if (v.Panel ~= nil) then
			Component.RemoveAnchor(v.Panel.pos.Anchor);
			Component.RemoveSceneObject(v.Panel.worldPlane.Model);
			v.Panel = nil;
		end
	end
end

-- Update all known dropships
function UpdateDropships()
	if (not IsInZone) then -- We arn't in a zone so a call to Game.ChunkCoordToWorld would fail, so we won't update just yet :<
		return;
	end
	
	local arr = {};
	local deprt = {};
	local PoiName = GetPoiName();
	local ArriveHeight = 0;
	local DepartHeight = 0;
	for i, v in pairs(DropShips) do
		if (DropShips[i]:Update()) then
			Component.RemoveWidget(DropShips[i].UiEntry);
			DropShips[i] = nil;
		else
			if (DropShips[i].SinCard) then
				if (DropShips[i].Dest == PoiName) then -- An arriving dropship
					if (DropShips[i].UiEntry:GetTag() ~= "Arrivals") then
						Component.FosterWidget(DropShips[i].UiEntry, RenderTarget:GetChild("content"):GetChild("Arrivals"));
						DropShips[i].UiEntry:SetTag("Arrivals");
						DropShips[i].UiEntry:Show(true);
					end
					DropShips[i].UiEntry:SetDims("top:".. ArriveHeight .."; left0; width:100%; height:24;");
					ArriveHeight = ArriveHeight + 26;
				elseif (DropShips[i].LastDest == PoiName) then -- departing
					if (DropShips[i].UiEntry:GetTag() ~= "Departures") then
						Component.FosterWidget(DropShips[i].UiEntry, RenderTarget:GetChild("content"):GetChild("Departures"));
						DropShips[i].UiEntry:SetTag("Departures");
						DropShips[i].UiEntry:Show(true);
					end
					DropShips[i].UiEntry:SetDims("top:".. DepartHeight .."; left0; width:100%; height:24;");
					DepartHeight = DepartHeight + 26;
				else -- I don't know where thi thing should go so i'll just ostrich and hide it
					DropShips[i].UiEntry:Show(false);
					DropShips[i].UiEntry:SetTag("Doushio~~");
				end
			end
		end
	end
    
    -- Hacky or smart?
    NotInRangeMsgs.Arrivals:Show(ArriveHeight == 0);
    NotInRangeMsgs.Departures:Show(DepartHeight == 0);
	
	SetArriveDepartHeaders(PoiName);
	
	-- Check if the player is close to a panel
	if (PanelOpenRange < PANEL_OPEN_RANGE_MAX) then
		PanelOpenCheck();
	end
end

function PanelOpenCheck()
	local PlyPos = Player.GetPosition();
	local playerPos = Vec3.New(PlyPos.x, PlyPos.y, PlyPos.z);
	--local pos = POSITIONS[GetPoiName()];
	local pos = GetNearestPanelPos();
	if (pos ~= nil) then
		local panelPos = Game.ChunkCoordToWorld(unpack(pos.Translation));
		local dist = Vec3.Length(Vec3.Sub(playerPos, panelPos));
		if (dist < PanelOpenRange) then
			if (not IsPlayerNearPanel) then -- open
				OpenPanel();
			end
		else
			if (IsPlayerNearPanel) then -- Close
				ClosePanel();
			end
		end
	end
end

function OpenPanel()
	RenderTarget:GetChild("mesh"):Play(0.99, 0, PANEL_ANIM_DURR, false, "linear");
	RenderTarget:GetChild("Airii"):Show(false);
	RenderTarget:GetChild("AiriiMesh"):Show(false);
	RenderTarget:GetChild("PanelScanlinesClosed"):Show(false);
	Callback2.FireAndForget(function()
		RenderTarget:GetChild("content"):Show(true);
		if (EnableScanlines) then
			RenderTarget:GetChild("PanelScanlinesOpen"):Show(true);
		end
	end, nil, PANEL_ANIM_DURR);
	System.PlaySound(OPEN_SOUND);
	IsPlayerNearPanel = true;
end

function ClosePanel()
		RenderTarget:GetChild("mesh"):Play(0, 0.99, PANEL_ANIM_DURR, false, "linear");
		RenderTarget:GetChild("content"):Show(false);
		RenderTarget:GetChild("PanelScanlinesOpen"):Show(false);
		Callback2.FireAndForget(function()
			RenderTarget:GetChild("Airii"):Show(true);
			RenderTarget:GetChild("AiriiMesh"):Show(true);
			if (EnableScanlines) then
				RenderTarget:GetChild("PanelScanlinesClosed"):Show(true);
			end
		end, nil, PANEL_ANIM_DURR);
		IsPlayerNearPanel = false;
		System.PlaySound(CLOSE_SOUND);
end

function GetPoiName()
	local playerPos = Player.GetPosition();
	if (playerPos) then
		local name = Game.GetSubzoneNameAt(playerPos.x, playerPos.y);
		if (name) then
			return name;
		end
	end
	
	return "Not Kansas";
end


function GetEntityPos(id)
	local bounds = Game.GetTargetBounds(id);
	if (bounds) then
		return Vec3.New(bounds.x, bounds.y, bounds.z);
	else
		return nil;
	end
end

function RemoveDropship(id)
	Dropships[id] = nil;
end

function SetArriveDepartHeaders(poi)
	RenderTarget:GetChild("content"):GetChild("ArriveHeader"):GetChild("text"):SetText(Lokii.GetString("ARRIVING_AT") .. poi);
	RenderTarget:GetChild("content"):GetChild("DepartHeader"):GetChild("text"):SetText(Lokii.GetString("DEPARTING_FROM") .. poi);
end

function FormatTime(seconds)
	if (seconds >= 60) then
		local mins = math.floor(seconds / 60);
		local secs = math.floor(seconds - (mins * 60));
		return mins .. "m ".. secs .. " s";
	end
	
	return seconds .. " s";
end

function GetShortPoiName(name)
	if (SHORT_NAMES[name]) then
		return SHORT_NAMES[name];
	end
	
	return name;
end

function GetNearestPanelPos()
	local NearPanel = {};
	local closest = 9999999999999999;
	local PlyPos = Player.GetPosition();
	local playerPos = Vec3.New(PlyPos.x, PlyPos.y, PlyPos.z);
	for i, v in pairs(PanelPositions) do
		local panelPos = Game.ChunkCoordToWorld(unpack(v.Translation));
		local dist = Vec3.Length(Vec3.Sub(playerPos, panelPos));
		if (dist < closest) then
			NearPanel = v;
			closest = dist;
		end
	end
	return NearPanel;
end

function BuildPositionTable()
	PanelPositions = {};
	
	-- Landing Pads
	for k,v in pairs(POSITIONS) do
		PanelPositions[k] = v;
	end
	
	-- Printers
	if (EnablePrinterPanels) then
		for k,v in pairs(PRINTER_POSITIONS) do
			PanelPositions[k] = v;
		end
	end
	
	PlaceMapMarkers();
end

function ScalePanels()
	RemovePanels();
	CreatePanels();
end

function PlaceMapMarkers()
	for k,v in pairs(MapMarkers) do		
		MapMarkers[k]:Destroy();
		MapMarkers[k] = nil;
	end
		
	if (EnableMapMarkers) then
		for k,v in pairs(PanelPositions) do		
			local MARKER = MapMarker.Create();
			MARKER:SetTitle(ADDONNAME);
			MARKER:SetSubtitle(Lokii.GetString("DROPSHIP_TIMETABLE"));
			MARKER:ShowOnWorldMap(true, MapMarker.ZOOM_TACTICAL_MIN, MapMarker.ZOOM_TACTICAL_MAX);
			MARKER:SetTags({MapMarker.TAG_POI, MapMarker.TAG_PERSONAL});
			MARKER:BindToPosition(Game.ChunkCoordToWorld(unpack(v.Translation)));
			MARKER:GetIcon():SetTexture("MapMarker");
			MapMarkers[k] = MARKER;
		end
	end
end

function CreateInterfaceOptions()
	InterfaceOptions.AddMultiArt({id="LOGO", texture="optsLogo", width=327, height=75, y_offset="5", OnClickUrl="http://forums.firefallthegame.com/community/threads/addon-airii-an-in-world-dropship-timetable.1012341/"})
	
	InterfaceOptions.StartGroup({label=Lokii.GetString("GENERAL_SETTINGS"), checkbox=false, id="GENRAL_SETTINGS"});
	
	InterfaceOptions.AddCheckBox({id="CALC_SPEED", label=Lokii.GetString("CALC_SPEED_LBL"), tooltip=Lokii.GetString("CALC_SPEED_TT"), default=CalculateSpeed});
	UIHELPER.AddUICallback("CALC_SPEED", function(args) CalculateSpeed = args; end);
	
	InterfaceOptions.AddCheckBox({id="ENABLE_DEBUG", label=Lokii.GetString("ENABLE_DEBUG_LBL"), tooltip=Lokii.GetString("ENABLE_DEBUG_TT"), default=EnableDebuging});
	UIHELPER.AddUICallback("ENABLE_DEBUG", function(args) EnableDebuging = args;	Debug.EnableLogging(EnableDebuging); end);
	
	InterfaceOptions.AddSlider({id="OPEN_RANGE", label=Lokii.GetString("OPEN_RANGE_LBL"), tooltip=Lokii.GetString("OPEN_RANGE_TT"), default=PanelOpenRange, min=1, max=PANEL_OPEN_RANGE_MAX, inc=1, suffix=" M"});
	UIHELPER.AddUICallback("OPEN_RANGE", function(args)
			PanelOpenRange = args;
			if (PanelOpenRange == PANEL_OPEN_RANGE_MAX) then
				OpenPanel();
				RenderTarget:GetChild("AiriiMesh"):Show(false);
				RenderTarget:GetChild("PanelScanlinesClosed"):Show(false);
			end
		end);
		
	InterfaceOptions.AddCheckBox({id="PRINTER_PANELS", label=Lokii.GetString("PRINTER_PANELS_LBL"), tooltip=Lokii.GetString("PRINTER_PANELS_TT"), default=EnablePrinterPanels});
	UIHELPER.AddUICallback("PRINTER_PANELS", function(args)
		EnablePrinterPanels = args;
		RemovePanels();
		BuildPositionTable();
		CreatePanels();
	end);
	
	InterfaceOptions.AddCheckBox({id="DROPSHIP_MAP_MARKERS", label=Lokii.GetString("DROPSHIP_MAP_MARKERS"), tooltip=Lokii.GetString("DROPSHIP_MAP_MARKERS_TT"), default=EnableMapMarkers});
	UIHELPER.AddUICallback("DROPSHIP_MAP_MARKERS", function(args)
		EnableMapMarkers = args;
		PlaceMapMarkers();
	end);

	InterfaceOptions.AddSlider({id="PANELSCALE", label=Lokii.GetString("PANELSCALE_LBL"), tooltip=Lokii.GetString("PANELSCALE_TT"), default=PanelScale, min=1, max=PANEL_SCALE_MAX, inc=0.25});
	UIHELPER.AddUICallback("PANELSCALE", function(args)
		PanelScale = args;
		ScalePanels();
	end);
	
	InterfaceOptions.StopGroup();
	
	-- Style
	InterfaceOptions.StartGroup({label=Lokii.GetString("STYLE"), checkbox=false, id="Style"});
	
	-- Shading
	InterfaceOptions.AddCheckBox({id="SHADING", label=Lokii.GetString("SHADING_LBL"), tooltip=Lokii.GetString("SHADING_TT")});
	UIHELPER.AddUICallback("SHADING", function(args)
		if (args) then
			RenderTarget:GetChild("mesh"):SetTexture("PanelTex");
		else
			RenderTarget:GetChild("mesh"):SetTexture("colors", "white");
		end
	end);
	
	-- Scanlines
	InterfaceOptions.AddCheckBox({id="SCANLINES", label=Lokii.GetString("SCANLINES_LBL"), tooltip=Lokii.GetString("SCANLINES_TT"), default=EnableScanlines});
	UIHELPER.AddUICallback("SCANLINES", function(args)
		EnableScanlines = args;
		if (args and not PanelOpenRange == PANEL_OPEN_RANGE_MAX) then
			RenderTarget:GetChild("PanelScanlinesClosed"):Show(true);
			RenderTarget:GetChild("PanelScanlinesOpen"):Show(true);
		else
			RenderTarget:GetChild("PanelScanlinesClosed"):Show(false);
			RenderTarget:GetChild("PanelScanlinesOpen"):Show(false);
		end
	end);
	
	InterfaceOptions.AddCheckBox({id="SCANLINES_ANNI_LBL", label=Lokii.GetString("SCANLINES_ANNI_LBL"), default=EnableAnimatedScanlines});
	UIHELPER.AddUICallback("SCANLINES_ANNI_LBL", function(args)
		EnableAnimatedScanlines = args;
		if (EnableAnimatedScanlines) then
			RenderTarget:GetChild("PanelScanlinesOpen"):Play(0, 1, 20, true, "linear");
			RenderTarget:GetChild("PanelScanlinesClosed"):Play(0, 1, 20, true, "linear");
		else
			RenderTarget:GetChild("PanelScanlinesOpen"):Play(1, 1, 20, true, "linear");
			RenderTarget:GetChild("PanelScanlinesClosed"):Play(1, 1, 20, true, "linear");
		end
	end);
	
	-- Destination Colors
	InterfaceOptions.AddColorPicker({id="FREINDLY_COLOR", label=Lokii.GetString("FREINDLY_COLOR_LBL"), default={alpha=1, tint=FREINDLY_COLOR}});
	UIHELPER.AddUICallback("FREINDLY_COLOR", function(args) FREINDLY_COLOR = args.tint; end);
	
	InterfaceOptions.AddColorPicker({id="HOSTILE_COLOR", label=Lokii.GetString("HOSTILE_COLOR_LBL"), default={alpha=1, tint=HOSTILE_COLOR}});
	UIHELPER.AddUICallback("HOSTILE_COLOR", function(args) HOSTILE_COLOR = args.tint; end);
	
	InterfaceOptions.AddColorPicker({id="SEPARATOR_COLOR", label=Lokii.GetString("SEPARATOR_COLOR_LBL"), default={alpha=1, tint=SEPARATOR_COLOR}});
	UIHELPER.AddUICallback("SEPARATOR_COLOR", function(args) SEPARATOR_COLOR = args.tint; end);
	
	InterfaceOptions.AddColorPicker({id="BG_COLOR", label=Lokii.GetString("BG_COLOR_LBL"), default={alpha=0.8, tint="0AB5CF"}});
	UIHELPER.AddUICallback("BG_COLOR", function(args) 
		RenderTarget:GetChild("mesh"):SetParam("tint", args.tint);
		RenderTarget:GetChild("mesh"):SetParam("alpha", args.alpha);
	end);
	
	InterfaceOptions.AddColorPicker({id="LOGO_COLOR", label=Lokii.GetString("LOGO_COLOR_LBL"), default={alpha=0.8, tint="FF4F00"}});
	UIHELPER.AddUICallback("LOGO_COLOR", function(args) 
		RenderTarget:GetChild("Airii"):SetParam("tint", args.tint);
		RenderTarget:GetChild("Airii"):SetParam("alpha", args.alpha);
	end);
	
	InterfaceOptions.AddColorPicker({id="HEADER_TXT_COLOR", label=Lokii.GetString("HEADER_TXT_COLOR_LBL"), default={alpha=1, tint="FFFFFF"}});
	UIHELPER.AddUICallback("HEADER_TXT_COLOR", function(args) 
		RenderTarget:GetChild("content"):GetChild("ArriveHeader"):GetChild("text"):SetTextColor(args.tint);
		RenderTarget:GetChild("content"):GetChild("ArriveRouteHeader"):GetChild("route"):SetTextColor(args.tint);
		RenderTarget:GetChild("content"):GetChild("ArriveRouteHeader"):GetChild("eta"):SetTextColor(args.tint);
		
		RenderTarget:GetChild("content"):GetChild("DepartHeader"):GetChild("text"):SetTextColor(args.tint);
		RenderTarget:GetChild("content"):GetChild("DepartRouteHeader"):GetChild("route"):SetTextColor(args.tint);
		RenderTarget:GetChild("content"):GetChild("DepartRouteHeader"):GetChild("eta"):SetTextColor(args.tint);
	end);
		
	InterfaceOptions.StopGroup();
end