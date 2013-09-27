--==============================================================================================
-- Arkii
-- A simple localisation tool
--==============================================================================================

--[[
	API:
		Lokii.AddLang(ID, langPath); [string] [string]
			Add a new localy stored language, id is a string ID used to refrance this language pack.
			langPath should be a string poining to the lua file for that language
	
		Lokii.SetBaseLang(ID); [string]
			The base language is used incase the selected language doesn't have a replacement string.
			The ID should be one of the ids that you provided to Lokii.AddLang.
				
		Lokii.SetLang(ID); [string]
			Sets what language should be used.
				
		Lokii.GetString(ID); [string]
			Gets the string for that id from the currently set language.
				
		Lokii.Lang[ID]; 
			Another way to acess the localised strings.
			
		Lokii.GetLangList();
			Returns a list of all the registered language packs.
			
		Lokii.SetToLocale()
			An easy way to set Lokii to use the players default language.
			
		Lokii.LoadWebPack(URL); [string]
			If set then Lokii Will check for a "index.json" file at that url and will use it to load extra or updates strings
			
		Lokii.RegisterCallback(callback); [function]
			Set a function to be called when the webpack is downloaded.
			Only called if a pack is downloaded so if the packs are up to date then it won't be called
			
	Lang file example:
		LANG = jsontotable(
		{
			STRING_ID : "string :D",
		}
		);
		
		or
		
		LANG =
		{
			STRING_ID = "string :D",
		};
		
		The first is preferable as you can just copy the json to a file on a webserver for use with Lokii.LoadWebPack.
	
	Usage example:
		Lokii.AddLang("en", "./lang/EN");
		Lokii.AddLang("jp", "./lang/JP");
		Lokii.SetBaseLang("en");
		Lokii.SetLang("jp");
		Lokii.LoadWebPack("localhost/firefall/lang"); -- optional
		Lokii.RegisterCallback(OnLokiiLoad); -- optional
		
		Component.GenerateEvent('MY_SYSTEM_MESSAGE', {text=Lokii.Lang["STRING_ID"]});
		
	Webserver setup:
		Create a directory on the server to hold your lang files.
		Create a file in there called "index.json"
		Copy the text below as an example:
			{
				"Version" : 7,
				"en" : "EN.json",
				"jp" : "JP.json",
				"fr" : "FR.json",
			}
		The version number is used to check if Lokii should update, increase it evertime you changes the files on the server.
		After that is an entry for each lang pack you want added to Lokii. ID then the url reltive to the current directory.
		
		Then create a file for each lang pack at the place you specified in the index.json
		make sure your web server will server these files as "applaction/json" or FireFall will reject them.
		Thats it ^^
		
		Oh and for refrance the lang codes for firefall are:
			English = en
			German = de
			French = fr
		who would have guessed :p
]]

if (Lokii) then
	return;
end

require "lib/lib_Callback2";
require "lib/lib_Debug";

Lokii = {};
Lokii.Lang = {};

local PRIVATE = {};
PRIVATE.Langs = {};
PRIVATE.BaseLang = "";
PRIVATE.ActiveLang = "";
PRIVATE.VERSION_ID = "Lokii_Lang_Ver";
PRIVATE.CACHED_PREFIX = "Lokii_Lang_";
PRIVATE.CACHED_LANG_LIST = "Lokii_Lang_List";
PRIVATE.HTTP_MAX_RETRIES = 3;

-- Register a new lang pack
function Lokii.AddLang(id, langPath)
	require(langPath);
	PRIVATE.Langs[id] = LANG;
	LANG = nil;
end

-- This sets the base lang, if a replacment lang doesn't have all the strings defined
-- then the string in the base will be used instead
function Lokii.SetBaseLang(id)
	-- Check if we have any new lang data cached
	local langList = Component.GetSetting(PRIVATE.CACHED_LANG_LIST);
	if (langList ~= nil) then
		for i = 1, #langList, 1 do
			PRIVATE.Langs[langList[i]] = Component.GetSetting(PRIVATE.CACHED_PREFIX..langList[i]);
		end
	end
	
	PRIVATE.BaseLang = id;
	Lokii.Lang = {};
	
	Lokii.Lang = PRIVATE.SimpleCopy(PRIVATE.Langs[PRIVATE.BaseLang]);
end

function Lokii.SetLang(id)
	PRIVATE.ActiveLang = id;

	-- Copy the base, but don't drop it! We ain't no Skrillex :p (base, bass, close enough)
	Lokii.Lang = PRIVATE.SimpleCopy(PRIVATE.Langs[PRIVATE.BaseLang]);
	
	-- Now overide those strings with there replacements
	if (PRIVATE.Langs[id] == nil) then
		Debug.Warn("That lang pack doesn't exist :/", "["..id.."]");
	else
		for i, d in next, PRIVATE.Langs[id], nil do
			Lokii.Lang[i] = d;
		end
	end
end

function Lokii.SetToLocale()
	Lokii.SetLang(System.GetLocale());
end

function Lokii.GetString(id)
	return Lokii.Lang[id];
end

function Lokii.GetLangList()
	local langs = {};
	for i, v in next, PRIVATE.Langs, nil do
		table.insert(langs, i);
	end
	
	return langs;
end

function Lokii.RegisterCallback(cb)
	PRIVATE.cb_Loaded = cb;
end

function Lokii.LoadWebPack(HOST)
	local CurrentVersion = Component.GetSetting(PRIVATE.VERSION_ID);
	PRIVATE.WebRequest({url = HOST .. "/index.json", cb =
	function(args)
		if (CurrentVersion == nil or args.Version > CurrentVersion) then
			CurrentVersion = args.Version;
			args.Version = nil;
			local requestsLeft = PRIVATE.HashCount(args);
			for i, v in next, args, nil do
				PRIVATE.WebRequest({url= HOST .. "/" .. v, cb = 
				function(args2)
					Debug.Log("Loaded language", i);
					PRIVATE.Langs[i] = args2; -- Add the lang
					requestsLeft = requestsLeft - 1;
					
					if (requestsLeft == 0) then
						Debug.Log("All languages loaded from the web pack :D");
						Lokii.SetLang(PRIVATE.ActiveLang);
						
						-- Update or make a cache of these
						Component.SaveSetting(PRIVATE.VERSION_ID, CurrentVersion);
						Component.SaveSetting(PRIVATE.CACHED_LANG_LIST, Lokii.GetLangList());
						for i2, v2 in next, PRIVATE.Langs, nil do
							Component.SaveSetting(PRIVATE.CACHED_PREFIX..i2, v2);
						end
						
						if (PRIVATE.cb_Loaded) then
							PRIVATE.cb_Loaded();
						end
					end
				end});
			end
		end
	end});
end

function PRIVATE.SimpleCopy(orig)
	local copy = {};
	for i, v in next, orig, nil do
		copy[i] = v;
	end
	
	return copy;
end

function PRIVATE.HashCount(tbl)
	local count = 0;
	for i, v in next, tbl, nil do
		count = count + 1;
	end
	
	return count;
end

function PRIVATE.WebRequest(prams)
	if (HTTP.IsRequestPending()) then
		local delay = math.random(2, 8);
		if (not prams.tries) then prams.tries = 0; end
		if (prams.tries > PRIVATE.HTTP_MAX_RETRIES) then
			Debug.Warn("A HTTP Request is pending retrying in", delay, "seconds", "Retry numer", prams.tries);
			prams.tries = prams.tries + 1;
			Callback2.FireAndForget(PRIVATE.WebRequest, prams, delay);
		else
			Debug.Warn("The HTTP request failed", prams.tries, "time. Sorry but i'm call 404 on that guy :<");
		end
	else
		HTTP.IssueRequest(prams.url, "GET", nil,
		function(args, err)
			if args then
				prams.cb(args);
			else
				Debug.Error("Error trying to get", prams.url, "Error message:", tostring(err), "Retring.");
			end 
		end);
	end
end