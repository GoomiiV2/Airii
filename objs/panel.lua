PANEL = 
{
	{	Name 		= "pos",
		Id			= "Anchor",
		Scale		= 1,
		Translation	= {x=0,y=0,z=0},
		Rotation 	= {axis={x=0,y=0,z=1},angle=90},
		BindTo		= "World",
	},
	
	{
		Name		= "panel_rt",
		Id			= "RenderTarget",
		RTGlobal	= true,
		RT			= {width=1024, height=1024},
		Widget		= 	[[<Group dimensions="dock:fill;" style="alpha:1.0">
							<!--<Stillart id="Face" dimensions="dock:fill" style="texture:colors; region:white"/>-->
							<Animation name="mesh" dimensions="dock:fill" mesh="PanelMesh" style="texture:colors; region:white; tint:0AB5CF; alpha:0.8;" />
							<Animation name="PanelScanlinesOpen" dimensions="dock:fill;" mesh="PanelScanlinesOpen" style="texture:PanelTex; region:ScanLines; tint:000000; alpha:0.3;" />
							<Group name="content" dimensions="center-x:50%; center-y:50%; width:92%; height:42%;">
								<Group name="ArriveHeader" blueprint="ArriveDepartHeader" dimensions="top:0; center-x:50%; width:100%; height:32;"> </Group>
								<Group name="ArriveRouteHeader" blueprint="Header" dimensions="top:32; center-x:50%; width:100%; height:24;"> </Group>
								<Group name="Arrivals" dimensions="top:56; center-x:50%; width:100%; height:50%-56;" style="clip-children:true;">
								
								</Group>
								
								<Group name="DepartHeader" blueprint="ArriveDepartHeader" dimensions="top:50%; center-x:50%; width:100%; height:32;"> </Group>
								<Group name="DepartRouteHeader" blueprint="Header" dimensions="top:50%+32; center-x:50%; width:100%; height:24;"> </Group>
								<Group name="Departures" dimensions="top:50%+56; center-x:50%; width:100%; height:50%-56;" style="clip-children:true;">
								
								</Group>
							</Group>
							
							<Animation name="AiriiMesh" dimensions="dock:fill;" mesh="PanelAirii" style="texture:PanelTex; region:AiriiSlants; tint:000000; alpha:0.4;" />
							<Animation name="PanelScanlinesClosed" dimensions="dock:fill;" mesh="PanelScanlinesClosed" style="texture:PanelTex; region:ScanLines; tint:000000; alpha:0.2;" />
							<Stillart name="Airii" dimensions="center-x:50%; center-y:50%; width:92%; height:12%;" style="texture:PanelTex; region:Airii; tint:FF4F00;"/>
						</Group>]],
	},
	
	{
		Name		= "worldPlane",
		Id			= "plane",
		Scale 		= 3,
		CullAlpha	= 0,
		Anchor		= "pos",
		RT			= "panel_rt",
	},
};