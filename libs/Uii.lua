UIHELPER = {};

-- Creates a list box from an array
function UIHELPER.ListboxFromArray(LB_ID, LB_label, LB_array, NiceNames)
	if (NiceNames == true) then
		InterfaceOptions.AddChoiceMenu({id=LB_ID, default=LB_array[1][1],  label=LB_label});
	else
		InterfaceOptions.AddChoiceMenu({id=LB_ID, default=LB_array[1],  label=LB_label});
	end
	
	local NiceLabel;
	local NiceValue;
	
	for i,v in ipairs(LB_array) do
		NiceLabel = v;
		NiceValue = v;
		
		if (NiceNames == true) then
			NiceLabel = v[1];
			NiceValue = v[2];
		end
		
		InterfaceOptions.AddChoiceEntry({menuId=LB_ID, val=NiceValue, label=NiceLabel});
	end
end

-- ====================================
-- UI Callbacks                      --
-- ====================================

-- Call the given function when the UI option is changed
UIHELPER.UI_Callbacks = {};

-- Register the function
function UIHELPER.AddUICallback(ID, func)
	UIHELPER.UI_Callbacks[ID] = func;
end

-- Check if the function should be called
function UIHELPER.CheckCallbacks(id, val)
	local func = UIHELPER.UI_Callbacks[id];
	if (func) then
		func(val);
	end
end

-- ====================================
--             Buttons Manger        --
-- ====================================
UIHELPER.BTT_RolloverTag = "_ro";
UIHELPER.UI_Buttons = {}; -- Keep track of all out butions, cute likle buttons :)

-- Image based button, no text
function UIHELPER.AddButton(buttonID, region, mouseDown, mouseEnter, mouseLeave)
	local BUTTON = {};
	
	-- Get our stuffff together
	BUTTON.ID = buttonID;
	BUTTON.ART = Component.GetWidget(buttonID);
	BUTTON.REGIONNAME = region;
	
	-- Get the focus box
	for i = 1, BUTTON.ART:GetChildCount() do
		if (tostring(BUTTON.ART:GetChild(i)) == "FocusBox") then
			BUTTON.FOCUSBOX = BUTTON.ART:GetChild(i);
		end
	end
	
	-- Set our stuff
	BUTTON.ART:SetRegion(region);
	BUTTON.FOCUSBOX:BindEvent("OnMouseEnter", 
	function()
		UIHELPER.BTT_MouseEnter(BUTTON.ID);
		if (mouseEnter) then 
			mouseEnter(); 
		end 
	end);
	
	BUTTON.FOCUSBOX:BindEvent("OnMouseLeave", function() UIHELPER.BTT_MouseLeave(BUTTON.ID); if (mouseEnter) then mouseEnter(); end end);
	BUTTON.FOCUSBOX:BindEvent("OnMouseDown", mouseDown);
	
	-- Add it to the list
	UIHELPER.UI_Buttons[BUTTON.ID] = BUTTON;
end

-- When your mouse enters a button
function UIHELPER.BTT_MouseEnter(id)
	UIHELPER.UI_Buttons[id].ART:SetRegion(UIHELPER.UI_Buttons[id].REGIONNAME .. UIHELPER.BTT_RolloverTag);
end

function UIHELPER.BTT_MouseLeave(id)
	UIHELPER.UI_Buttons[id].ART:SetRegion(UIHELPER.UI_Buttons[id].REGIONNAME);
end

-- Simple text based button
-- buttonID		:	Unique ID of the button
-- text 		: 	What to show on the button
-- onPressed 	: 	What function to call when it is pressed
function UIHELPER.AddSimpleButton(buttonID, text, onPressed)
	local BUTTON = Component.GetWidget(buttonID);
	local FOCUSBOX = BUTTON:GetChild("focus");
	local BG = BUTTON:GetChild("bg");
	
	-- make sure they are visable
	
	BUTTON:GetChild('txt'):SetText(text);
	BUTTON:Show(true);
	
	FOCUSBOX:BindEvent("OnMouseEnter", function() BG:ParamTo( "alpha" , 1.0, 0.1 ); end);
	FOCUSBOX:BindEvent("OnMouseLeave", function() BG:ParamTo( "alpha" , 0.5, 0.1 ); end);
	FOCUSBOX:BindEvent("OnMouseUp", onPressed);
end

function UIHELPER.AddDialog(parent, content, title, desc, onYes, OnNo, oldPopUp)
	local popUp = nil;
	if (oldPopUp) then
		popUp = oldPopUp;
		popUp:Open();
	else
		popUp = PopupWindow.Create(parent);
		popUp:SetTitle(title);
		popUp.BODY.GROUP:SetClipChildren(true);
		Component.FosterWidget(content, popUp:GetBody(), "full");
	end
	
	content:GetChild('txt'):SetText(desc);
	
	UIHELPER.AddSimpleButton("PopUpYush", "Yes", function() popUp:Close(); onYes(); end);
	UIHELPER.AddSimpleButton("PopUpNay", "No", function()  popUp:Close(); OnNo(); end);
	
	return popUp;
end