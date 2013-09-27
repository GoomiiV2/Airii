-- Dropship class
DropShip = {};
DropShip.__index = DropShip;

function DropShip.Create(id, parent)
	local ship = {};
	setmetatable(ship, DropShip);
	ship.id = id;
	ship.Speed = 1;
	ship.Dest = "";
	ship.LastDest = "";
	ship.DestDist = 1;
	ship.Position = Vec3.New(0, 0, 0);
	ship.DestPos = Vec3.New(0, 0, 0);
	ship.ETA = 0;
	ship.IsLanding = false;
	
	-- Ui Entry
	ship.UiEntry = Component.CreateWidget("Entry", parent);
	ship.UiEntry:SetTag(parent:GetName());
	ship.UiEntry:Show(false);
	ship.TF_Route = TextFormat.Create();
	return ship;
end

function DropShip:Update()
	--Debug.Log("Updating Dropship: ", self.id);
	
	self.SinCard = Game.GetSinCardFields(self.id);
	self.LastPos = self.Position;
	
	if (self.SinCard) then
		if (self.Dest ~= self.SinCard.destination1) then
			self.LastDest = self.Dest;
			self.IsLanding = true;
		end
		
		if (self.IsLanding) then
			if (HAS_LANDED_RANGE >= Vec3.Length(Vec3.Sub(self.Position, self.DestPos))) then
				self.IsLanding = false;
				self.Dest = self.SinCard.destination1;
			end
		end
		
		-- Work out ETA based on the current speed
		if (POSITIONS[self.Dest]) then
			self.DestPos = Game.ChunkCoordToWorld(unpack(POSITIONS[self.Dest].LandingPosition));
			self.DestDist = Vec3.Length(Vec3.Sub(self.Position, self.DestPos));
			local eta = self.DestDist / self.Speed;
			if (type(eta) == 'number' and eta ~= nil and -math.huge ~= eta and math.huge ~= eta and math.nan ~= eta) then
				self.ETA = math.floor(eta);
			else
				self.ETA = 0;
			end
		end
	end
	
	local pos = GetEntityPos(self.id);
	if (pos) then
		self.Position = GetEntityPos(self.id);
	else -- If pos is nill then the ship went out of range so remove it
		Debug.Log("Removing Dropship: ", self.id);
		return true;
	end
	
	-- How far has the ship moved since we last checked
	if (self.LastPos) then
		self.Vel = Vec3.Sub(self.Position, self.LastPos);
		
		if (CalculateSpeed) then
			self.Speed = math.floor(Vec3.Length(self.Vel));
		else
			self.Speed = AVG_DROPSHIP_SPEED;
		end
	end
	
	self.UiEntry:GetChild("eta"):SetText(FormatTime(self.ETA));
	self.UiEntry:GetChild("eta"):SetTextColor(SEPARATOR_COLOR);
	
	self:SetRoute();
end

function DropShip:SetRoute()
	if (self.SinCard == nil) then
		return;
	end
	
	TextFormat.Clear(self.UiEntry:GetChild("route"));
	self.TF_Route = TextFormat.Create();
	
	 for index = 1, MAX_DESTINATIONS, 1 do
		local dest = self.SinCard["destination"..index];
		if (dest ~= "" and dest ~= nil) then
			if (index ~= 1) then
				self.TF_Route:AppendColor(SEPARATOR_COLOR);
				self.TF_Route:AppendText(" > ");
			end
			
			if (self.SinCard["friendly"..index]) then
				self.TF_Route:AppendColor(FREINDLY_COLOR);
			else
				self.TF_Route:AppendColor(HOSTILE_COLOR);
			end
			
			self.TF_Route:AppendText(GetShortPoiName(tostring(self.SinCard["destination"..index])));
		end
	end
	
	self.TF_Route:ApplyTo(self.UiEntry:GetChild("route"));
end