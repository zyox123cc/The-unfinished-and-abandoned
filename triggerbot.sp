#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2attributes>
#include <dhooks>

#pragma newdecls required;

//Handle g_hHudInfo;
Handle g_hHudShotCounter;
Handle g_hHudEnemyAim;
Handle g_hHudRadar[MAXPLAYERS + 1];

bool g_bNoSlowDown[MAXPLAYERS + 1];
bool g_bAllCrits[MAXPLAYERS + 1];
bool g_bNoSpread[MAXPLAYERS + 1];
bool g_bAimbot[MAXPLAYERS + 1];
bool g_bAutoShoot[MAXPLAYERS + 1];
bool g_bSilentAim[MAXPLAYERS + 1];
bool g_bTeammates[MAXPLAYERS + 1];
bool g_bShotCounter[MAXPLAYERS + 1];
bool g_bBunnyHop[MAXPLAYERS + 1];
bool g_bSpectators[MAXPLAYERS + 1];
bool g_bHeadshots[MAXPLAYERS + 1];
bool g_bInstantReZoom[MAXPLAYERS + 1];
bool g_bEnemyAimWarning[MAXPLAYERS + 1];
bool g_bRadar[MAXPLAYERS + 1];
bool g_bPlayersOutline[MAXPLAYERS + 1];
bool g_bBuildingOutline[MAXPLAYERS + 1];

int g_iFOV[MAXPLAYERS + 1];
int g_iAimType[MAXPLAYERS + 1];

bool g_bListenForFOV[MAXPLAYERS + 1];
float g_flAimFOV[MAXPLAYERS + 1];

Handle g_hPrimaryAttack;

Handle g_hGetWeaponID;
Handle g_hGetProjectileSpeed;
Handle g_hGetProjectileGravity;

Handle g_hLookupBone;
Handle g_hGetBonePosition;

bool g_bShot[MAXPLAYERS + 1];
int g_iShots[MAXPLAYERS + 1];
int g_iShotsHit[MAXPLAYERS + 1];

#define UMSG_SPAM_DELAY 0.1
float g_flNextTime[MAXPLAYERS + 1];

// Spectator Movement modes
enum {
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_POI,		// PASSTIME point of interest - game objective, big fight, anything interesting; added in the middle of the enum due to tons of hard-coded "<ROAMING" enum compares
	OBS_MODE_ROAMING,	// free roaming

	NUM_OBSERVER_MODES,
};

//Aimbot modes
enum{
	AIM_NEAR = 0,
	AIM_FOV,
	
	NUM_AIM_MODES,
}

//TODO
//Add Wait for charge
//Add Auto Airblast
//Add Auto sticky det
//SendProxy m_iWeaponState = AC_STATE_IDLE;  
//Calculate proper projectile velocity with weapon attributes.
//Simulate projectile path to detect early collisions.
//https://github.com/danielmm8888/TF2Classic/blob/master/src/game/server/player_lagcompensation.cpp#L388
//https://www.unknowncheats.me/forum/1502192-post9.html
//Use "real angles" not "silent aim angles" for aimbot

/*
public Plugin myinfo = 
{
	name = "[TF2] Badmin",
	author = "Pelipoika",
	description = "",
	version = "Propably like 500 by now",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};
*/
public Plugin myinfo = 
{
	name = "Server commands",
	author = "Alliedmodders LLC",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_banner", Command_Trigger);
	
	for (int i = 1; i <= MaxClients; i++)
	{	
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i); 
		}
		
		g_hHudRadar[i] = CreateHudSynchronizer();
	}
	
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

//	g_hHudInfo = CreateHudSynchronizer();
	g_hHudShotCounter = CreateHudSynchronizer();
	g_hHudEnemyAim = CreateHudSynchronizer();

	//CTFWeaponBase::PrimaryAttack()
	g_hPrimaryAttack = DHookCreate(279, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, CTFWeaponBase_PrimaryAttack);
	
	//CTFWeaponBaseGun::GetWeaponID()
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(372);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//Returns WeaponID
	if ((g_hGetWeaponID = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for GetWeaponID offset!");
	
	//CTFWeaponBaseGun::GetProjectileSpeed()
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(473);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);	//Returns SPEED
	if ((g_hGetProjectileSpeed = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for GetProjectileSpeed offset!");
	
	//CTFWeaponBaseGun::GetProjectileGravity()
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(474);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);	//Returns SPEED
	if ((g_hGetProjectileGravity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for GetProjectileGravity offset!");
	
	//bip_spine_2
	//-----------------------------------------------------------------------------
	// Purpose: Returns index number of a given named bone
	// Input  : name of a bone
	// Output :	Bone index number or -1 if bone not found
	//-----------------------------------------------------------------------------
	//int CBaseAnimating::LookupBone( const char *szName )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x56\x8B\xF1\x80\xBE\x41\x03\x00\x00\x00\x75\x2A\x83\xBE\x6C\x04\x00\x00\x00\x75\x2A\xE8\x2A\x2A\x2A\x2A\x85\xC0\x74\x2A\x8B\xCE\xE8\x2A\x2A\x2A\x2A\x8B\x86\x6C\x04\x00\x00\x85\xC0\x74\x2A\x83\x38\x00\x74\x2A\xFF\x75\x08\x50\xE8\x2A\x2A\x2A\x2A\x83\xC4\x08\x5E", 68);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hLookupBone = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::LookupBone signature!");
	
	//void CBaseAnimating::GetBonePosition ( int iBone, Vector &origin, QAngle &angles )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x83\xEC\x30\x56\x8B\xF1\x80\xBE\x41\x03\x00\x00\x00", 16);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if ((g_hGetBonePosition = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::GetBonePosition signature!");
}

int g_iPathLaserModelIndex;

public void OnMapStart()
{
	g_iPathLaserModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public void OnClientPutInServer(int client)
{
	g_bNoSlowDown[client] = false;
	g_bAllCrits[client] = false;
	g_bNoSpread[client] = false;
	g_bInstantReZoom[client] = false;
	g_bEnemyAimWarning[client] = false;
	g_bRadar[client] = false;
	g_bListenForFOV[client] = false;
	
	g_bAimbot[client] = false;
	g_bAutoShoot[client] = false;
	g_bSilentAim[client] = false;
	
	g_bShotCounter[client] = false;
	g_bTeammates[client] = false;
	g_bBunnyHop[client] = false;
	g_bSpectators[client] = false;
	g_bHeadshots[client] = false;
	
	g_bPlayersOutline[client] = false;
	g_bBuildingOutline[client] = false;

	g_iFOV[client] = 0;
	g_iAimType[client] = AIM_NEAR;
	g_flAimFOV[client] = 2.0;
	
	g_bShot[client] = false;
	g_iShots[client] = 0;
	g_iShotsHit[client] = 0;
	
	g_flNextTime[client] = 0.0;
	
	SDKHook(client, SDKHook_TraceAttackPost, TraceAttack);
}

public Action Command_Trigger(int client, int args)
{
	if(!(client > 0 && client <= MaxClients && IsClientInGame(client)))
		return Plugin_Handled;
		
	char auth[68];
	if(!GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth)))
		return Plugin_Handled;
	
	ReplySource replySrc = GetCmdReplySource();
	
	if(CheckCommandAccess(client, "", ADMFLAG_ROOT, true) || StrEqual(auth, "76561198025371616"))
	{
		DisplayHackMenuAtItem(client);
	}
	else if(replySrc == SM_REPLY_TO_CONSOLE)
	{
		PrintToConsole(client, "Unknown command: sm_banner");
		//Unknown command: sm_whois
	}
	
	return Plugin_Handled;
}

stock void DisplayHackMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuLegitnessHandler);
	menu.SetTitle("LMAOBOX");
	menu.AddItem("0", "Aimbot");
	menu.AddItem("1", "Misc");
	menu.AddItem("2", "Visuals");

	menu.ExitButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplayAimbotMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuAimbotHandler);
	menu.SetTitle("Aimbot - Settings");
	
	if(g_bAimbot[client])
		menu.AddItem("0", "Aimbot: On");
	else
		menu.AddItem("0", "Aimbot: Off");
	
	if(g_iAimType[client] == AIM_NEAR)
		menu.AddItem("1", "Aim Type: Closest");
	else if(g_iAimType[client] == AIM_FOV)
		menu.AddItem("1", "Aim Type: FOV");
	
	char FOV[64];
	Format(FOV, sizeof(FOV), "Aim FOV: %.1f", g_flAimFOV[client]);
	menu.AddItem("2", FOV);

	if(g_bAutoShoot[client])
		menu.AddItem("3", "Auto Shoot: On");
	else
		menu.AddItem("3", "Auto Shoot: Off");

	if(g_bNoSpread[client])
		menu.AddItem("3", "No Spread: On");
	else
		menu.AddItem("3", "No Spread: Off");
		
	if(g_bSilentAim[client])
		menu.AddItem("3", "Silent Aim: On");
	else
		menu.AddItem("3", "Silent Aim: Off");
	
	if(g_bTeammates[client])
		menu.AddItem("4", "Aim at teammates: On");
	else
		menu.AddItem("4", "Aim at teammates: Off");
		
	if(g_bHeadshots[client])
		menu.AddItem("0", "Headshots only: On");
	else
		menu.AddItem("0", "Headshots only: Off");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplayMiscMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuMiscHandler);
	menu.SetTitle("Misc - Settings");
	
	if(g_bNoSlowDown[client])
		menu.AddItem("0", "No Slowdown: On");
	else
		menu.AddItem("0", "No Slowdown: Off");
	
	if(g_bAllCrits[client])
		menu.AddItem("1", "Critical Hits: On");
	else
		menu.AddItem("1", "Critical Hits: Off");
	
	if(g_bBunnyHop[client])
		menu.AddItem("2", "Bunny Hop: On");
	else
		menu.AddItem("2", "Bunny Hop: Off");
		
	if(g_bInstantReZoom[client])
		menu.AddItem("3", "Instant ReZoom: On");
	else
		menu.AddItem("3", "Instant ReZoom: Off");
		
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

stock void DisplayVisualsMenuAtItem(int client, int page = 0)
{
	Menu menu = new Menu(MenuVisualsHandler);
	menu.SetTitle("Visuals - Settings");
	
	if(g_bShotCounter[client])
		menu.AddItem("0", "Shot Counter: On");
	else
		menu.AddItem("0", "Shot Counter: Off");
	
	if(g_bSpectators[client])
		menu.AddItem("1", "Spectator List: On");
	else
		menu.AddItem("1", "Spectator List: Off");
		
	if(g_bRadar[client])
		menu.AddItem("2", "Radar: On");
	else
		menu.AddItem("2", "Radar: Off");
		
	if(g_bEnemyAimWarning[client])
		menu.AddItem("3", "Enemy Aim Warning: On");
	else
		menu.AddItem("3", "Enemy Aim Warning: Off");
		
	if(g_bPlayersOutline[client])
		menu.AddItem("4", "Players Outline: On");
	else
		menu.AddItem("4", "Players Outline: Off");
		
	if(g_bBuildingOutline[client])
		menu.AddItem("5", "Buildings Outline: On");
	else
		menu.AddItem("5", "Buildings Outline: Off");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

public int MenuVisualsHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{		
			case 0:
			{
				if(!g_bShotCounter[param1])
				{
					int wep = GetPlayerWeaponSlot(param1, TFWeaponSlot_Primary);
					if(IsValidEntity(wep))
						DHookEntity(g_hPrimaryAttack, false, wep);	//Abuse the fact that you can't have multiple hooks to the same callback on the same entity.
					
					wep = GetPlayerWeaponSlot(param1, TFWeaponSlot_Secondary);
					if(IsValidEntity(wep))
						DHookEntity(g_hPrimaryAttack, false, wep);
					
					g_bShotCounter[param1] = true;
				}
				else
				{
					int wep = GetPlayerWeaponSlot(param1, TFWeaponSlot_Primary);
					if(IsValidEntity(wep))
						DHookRemoveHookID(DHookEntity(g_hPrimaryAttack, false, wep));
					
					wep = GetPlayerWeaponSlot(param1, TFWeaponSlot_Secondary);
					if(IsValidEntity(wep))
						DHookRemoveHookID(DHookEntity(g_hPrimaryAttack, false, wep));
					
					g_bShotCounter[param1] = false;
				}
				
				g_bShot[param1]     = false;
				g_iShots[param1]    = 0;
				g_iShotsHit[param1] = 0;				
			}
			case 1: g_bSpectators[param1]       = !g_bSpectators[param1];
			case 2: g_bRadar[param1]            = !g_bRadar[param1];
			case 3: g_bEnemyAimWarning[param1]  = !g_bEnemyAimWarning[param1];
			case 4: 
			{
				g_bPlayersOutline[param1] = !g_bPlayersOutline[param1];
				
				if(g_bPlayersOutline[param1])
				{
					TF2_CreateGlowToAll("PlayersOutline");	
				}
				else
				{
					//Kill All Client Glow
					TF2_KillAllGlow("PlayersOutline");
					
					//Regerenate all glow
					TF2_CreateGlowToAll("PlayersOutline");				
				}
			}
			case 5: 
			{
				g_bBuildingOutline[param1] = !g_bBuildingOutline[param1];
				
				if(g_bBuildingOutline[param1])
				{
					TF2_CreateGlowToAll("BuildingsOutline");	
				}
				else
				{
					//Kill All Building Glow
					TF2_KillAllGlow("BuildingsOutline");
					
					//Regerenate all glow
					TF2_CreateGlowToAll("BuildingsOutline");				
				}
			}
			
			
		}
		
		DisplayVisualsMenuAtItem(param1, GetMenuSelectionPosition());
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		DisplayHackMenuAtItem(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)		
{		
	if(!g_bListenForFOV[client])		
		return Plugin_Continue;		
	
	float flFov = StringToFloat(sArgs);		
	
	if(flFov > 180.0)		
		flFov = 180.0;		
	
	if(flFov < 0.0)		
		flFov = 0.0;
	
	g_flAimFOV[client] = flFov;		
	
	PrintToChat(client, "Aimbot FOV set to: %.1f", flFov);		
	
	g_bListenForFOV[client] = false;
	
	DisplayAimbotMenuAtItem(client);
	
	//Block sending value to chat.
	return Plugin_Handled;
}

public int MenuAimbotHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{		
			case 0: 
			{
				g_bAimbot[param1]    = !g_bAimbot[param1];
				
				if(g_bAimbot[param1])
				{
					SetEntProp(param1, Prop_Data, "m_bLagCompensation", false);
					SetEntProp(param1, Prop_Data, "m_bPredictWeapons", false);
				}
				else
				{
					SetEntProp(param1, Prop_Data, "m_bLagCompensation", true);
					SetEntProp(param1, Prop_Data, "m_bPredictWeapons", true);
				}
			}
			case 1: 
			{
				if(g_iAimType[param1] == AIM_NEAR)
					g_iAimType[param1] = AIM_FOV;
				else if(g_iAimType[param1] == AIM_FOV)
					g_iAimType[param1] = AIM_NEAR;
			}
			case 2:
			{		
				PrintToChat(param1, "Type your desired aim fov in chat now (1 - 180)"); 		
				g_bListenForFOV[param1] = true;		
			}
			case 3: g_bAutoShoot[param1] = !g_bAutoShoot[param1];
			case 4:
			{
				g_bNoSpread[param1] = !g_bNoSpread[param1];
			
				for (int w = 0; w <= view_as<int>(TFWeaponSlot_Secondary); w++)
				{
					int iEntity = GetPlayerWeaponSlot(param1, w);
				
					if(IsValidEntity(iEntity))
					{
						if(g_bNoSpread[param1])
							TF2Attrib_SetByName(iEntity, "weapon spread bonus", 0.0);
						else
							TF2Attrib_RemoveByName(iEntity, "weapon spread bonus");
					}
				}
			}
			case 5: g_bSilentAim[param1]  = !g_bSilentAim[param1];
			case 6: g_bTeammates[param1]  = !g_bTeammates[param1];
			case 7: g_bHeadshots[param1]  = !g_bHeadshots[param1];
		}
		
		DisplayAimbotMenuAtItem(param1, GetMenuSelectionPosition());
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		DisplayHackMenuAtItem(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public int MenuMiscHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: g_bNoSlowDown[param1]    = !g_bNoSlowDown[param1];
			case 1: g_bAllCrits[param1]      = !g_bAllCrits[param1];
			case 2: g_bBunnyHop[param1]      = !g_bBunnyHop[param1];
			case 3: g_bInstantReZoom[param1] = !g_bInstantReZoom[param1];
		}
		
		DisplayMiscMenuAtItem(param1, GetMenuSelectionPosition());
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		DisplayHackMenuAtItem(param1);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

public int MenuLegitnessHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: DisplayAimbotMenuAtItem(param1);
			case 1: DisplayMiscMenuAtItem(param1);
			case 2: DisplayVisualsMenuAtItem(param1);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
}

//Players Outline	-{
	
void TF2_CreateGlowToAll(char[] strTargetname)	
{
	if(StrEqual(strTargetname, "PlayersOutline"))
	{
		for (int i = 1; i <= MaxClients; i++) 	
		{
			if (IsClientInGame(i))
			{
				//Create Glow on All client
				TF2_CreateGlow(i, strTargetname);
			}
		}
	}
	else if(StrEqual(strTargetname, "BuildingsOutline"))
	{
		int index = -1;
		while ((index = FindEntityByClassname(index, "obj_*")) != -1)
		{
			TF2_CreateGlow(index, strTargetname);
		}
	}
	
}

void TF2_KillAllGlow(char[] strTargetname)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		char strName[64];
		GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
		if(StrEqual(strName, strTargetname))
		{
			AcceptEntityInput(index, "Kill");
		}
	}
}	
	
stock int TF2_CreateGlow(int iEnt, char[] strTargetname)
{
	char strGlowColor[18];
	switch(GetEntProp(iEnt, Prop_Send, "m_iTeamNum"))
	{
		case (2):Format(strGlowColor, sizeof(strGlowColor), "%i %i %i %i", 255, 51, 51, 255);
		case (3):Format(strGlowColor, sizeof(strGlowColor), "%i %i %i %i", 153, 194, 216, 255);
		default: return -1;
	}
	
	char oldEntName[64];
	GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));
	
	char strName[126], strClass[64];
	GetEntityClassname(iEnt, strClass, sizeof(strClass));
	Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
	DispatchKeyValue(iEnt, "targetname", strName);

	int ent = CreateEntityByName("tf_glow");
	if (IsValidEntity(ent))
	{
		SDKHook(ent, SDKHook_SetTransmit, OnSetTransmit);
		DispatchKeyValue(ent, "targetname", strTargetname);
		DispatchKeyValue(ent, "target", strName);
		DispatchKeyValue(ent, "Mode", "0");
		DispatchKeyValue(ent, "GlowColor", strGlowColor);	
		DispatchSpawn(ent);

		AcceptEntityInput(ent, "Enable");
		
		//Change name back to old name because we don't need it anymore.
		SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);
		return ent;
	}
	return -1;
}

public Action OnSetTransmit(int entity, int client) 
{
	SetEdictFlags(entity, GetEdictFlags(entity) & ~FL_EDICT_ALWAYS);
	
	char strName[64];
	GetEntPropString(entity, Prop_Data, "m_iName", strName, sizeof(strName));
	if(StrEqual(strName, "PlayersOutline"))
	{
		if (g_bPlayersOutline[client])
			return Plugin_Continue;
	}
	else if(StrEqual(strName, "BuildingsOutline"))
	{
		if (g_bBuildingOutline[client])
			return Plugin_Continue;
	}
	
	return Plugin_Handled;
}  

stock bool TF2_HasGlow(int iEnt)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt)
		{
			return true;
		}
	}
	return false;
}

public void OnPluginEnd()
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		char strName[64];
		GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
		if(StrEqual(strName, "PlayersOutline") || StrEqual(strName, "BuildingsOutline"))
		{
			AcceptEntityInput(index, "Kill");
		}
	}
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	//Remomve Client Glow
	if(TF2_HasGlow(client))
	{
		int index = -1;
		while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
		{
			char strName[64];
			GetEntPropString(index, Prop_Data, "m_iName", strName, sizeof(strName));
			if(StrEqual(strName, "PlayersOutline"))
			{
				char strTargetName[32];
				GetEntPropString(index, Prop_Data, "m_target", strTargetName, sizeof(strTargetName));
				
				char strTarget[32];
				Format(strTarget, sizeof(strTarget), "player%i", client);
		
				if(StrEqual(strTargetName, strTarget))
				{
					AcceptEntityInput(index, "Kill");
				}
			}
		}
	}
	
	//Create glow for client
	TF2_CreateGlow(client, "PlayersOutline");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "obj_") != -1)
	{
		SDKHook(entity, SDKHook_SpawnPost, Hook_OnObjSpawn);
	}
}

public void Hook_OnObjSpawn(int entity)
{  
	RequestFrame(Frame_CreateGlowOnEntity, EntIndexToEntRef(entity));
} 

public void Frame_CreateGlowOnEntity(int entref)
{
	int entity = EntRefToEntIndex(entref);
	
	if(entity != INVALID_ENT_REFERENCE)
	{
		TF2_CreateGlow(entity, "BuildingsOutline");
	}
}

//		}-


public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{	
	if(g_bAllCrits[client])
	{
		result = true;
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public MRESReturn CTFWeaponBase_PrimaryAttack(int pThis, Handle hReturn, Handle hParams)
{
	int iWeapon = pThis;
	int iShooter = GetEntPropEnt(iWeapon, Prop_Data, "m_hOwnerEntity");
	
//	PrintToChatAll("CTFWeaponBase_PrimaryAttack %N is firing their weapon %i", iShooter, iWeapon);
	
	g_bShot[iShooter] = true;
	g_iShots[iShooter]++;
	
	RequestFrame(DidHit, GetClientUserId(iShooter));
	
	return MRES_Ignored;
}

public void TraceAttack(int victim, int attacker, int inflictor, float damage, int damagetype, int ammotype, int hitbox, int hitgroup)
{
	//PrintToServer("Hitbox %i hitgroup %i", hitbox, hitgroup);

	if(attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
	{
		RequestFrame(TraceAttackDelay, GetClientUserId(attacker));
	}
}

public void TraceAttackDelay(int userid)
{
	int client = GetClientOfUserId(userid);
	if(client > 0)
	{
		if(g_bShot[client])
		{
			g_bShot[client] = false;
		}
	}
}

public void DidHit(int userid)
{
	int client = GetClientOfUserId(userid);
	if(client > 0)
	{
		if(!g_bShot[client])
			g_iShotsHit[client]++;
			
	//	PrintToChatAll("%N DidHit? %s", client, !g_bShot[client] ? "Yes" : "No");
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client) || !IsPlayerAlive(client)) 
		return Plugin_Continue;	
	
//	PrintCenterText(client, "%f %f %f", angles[0], angles[1], angles[2]);
	
	bool bChanged = false;
	
	if(g_bShotCounter[client])
	{
		SetHudTextParams(-1.0, 0.75, 0.1, 255, 0, 255, 0, 0, 0.0, 0.0, 0.0);
		
		int iShots = g_iShots[client];
		int iHits = g_iShotsHit[client];
		float flHitPerc = (float(iHits) / float(iShots)) * 100;
		
		ShowSyncHudText(client, g_hHudShotCounter, "Shots hit %i/%i [%.0f%%]", iHits, iShots, flHitPerc);
	}
	
	if(g_bSpectators[client])
	{
		char strObservers[32 * 64];
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Spectator && !IsFakeClient(i))
			{
				int iObserved = GetEntPropEnt(i, Prop_Data, "m_hObserverTarget");
				int iObsMode = GetEntProp(i, Prop_Data, "m_iObserverMode");
				
				if(iObserved > 0 && iObserved <= MaxClients && IsClientInGame(iObserved) && iObserved == client)
				{
					Format(strObservers, sizeof(strObservers), "%s%N%s\n", strObservers, i, iObsMode == OBS_MODE_IN_EYE ? " - IN EYE" : "");
				}
			}
		}
		
		SetHudTextParams(-1.0, 1.0, 0.1, 255, 255, 255, 0, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_hHudShotCounter, strObservers);
	}

	if(g_bBunnyHop[client] || (!(GetEntityFlags(client) & FL_FAKECLIENT) && buttons & IN_JUMP))
	{
		if((GetEntityFlags(client) & FL_ONGROUND))
		{
			int nOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
			SetEntProp(client, Prop_Data, "m_nOldButtons", (nOldButtons &= ~(IN_JUMP|IN_DUCK)));
		}
	}
	
	if(g_flNextTime[client] <= GetGameTime())
	{
		if(g_bRadar[client])
			Radar(client, angles);
			
		if(g_bEnemyAimWarning[client])
			EnemyIsAimingAtYou(client);
		
		g_flNextTime[client] = GetGameTime() + UMSG_SPAM_DELAY;
	}

	int iAw = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if(!IsValidEntity(iAw))
		return Plugin_Continue;
	
	if(HasEntProp(iAw, Prop_Data, "m_flRezoomTime") && g_bInstantReZoom[client])
	{		
		//Instant zoom
		float m_flRezoomTime = GetEntPropFloat(iAw, Prop_Data, "m_flRezoomTime");
		float m_flUnzoomTime = GetEntPropFloat(iAw, Prop_Data, "m_flUnzoomTime");
		
		if (m_flRezoomTime != -1.0){
			SetEntPropFloat(iAw, Prop_Data, "m_flRezoomTime", GetGameTime());
		}
		
		if (m_flUnzoomTime != -1.0){
			SetEntPropFloat(iAw, Prop_Data, "m_flUnzoomTime", GetGameTime());
		}
		
		//SetEntProp(iAw, Prop_Data, "m_bRezoomAfterShot", true);
	}
	
	//IN_ATTACK Should always bypass all waiting
	
	if(!(buttons & IN_ATTACK) && !g_bAutoShoot[client])
		return Plugin_Continue;

	if(!(buttons & IN_ATTACK) && !IsReadyToFire(iAw))
		return Plugin_Continue;
	
	if(!g_bAimbot[client])
		return Plugin_Continue;
	
	int iTarget = -1;
	float target_point[3]; target_point = SelectBestTargetPos(client, angles, iTarget);		
	if (target_point[2] == 0.0 || iTarget < 0)
		return Plugin_Continue;
	
	if(IsPlayerReloading(client) && !(buttons & IN_ATTACK))
		return Plugin_Continue;
	
	float eye_to_target[3];
	SubtractVectors(VelocityExtrapolate(iTarget, target_point), 
					VelocityExtrapolate(client, GetEyePosition(client)), 
					eye_to_target);
	
	GetVectorAngles(eye_to_target, eye_to_target);
	
	eye_to_target[0] = AngleNormalize(eye_to_target[0]);
	eye_to_target[1] = AngleNormalize(eye_to_target[1]);
	eye_to_target[2] = 0.0;
	
	if(g_bAutoShoot[client])
	{
		buttons |= IN_ATTACK;
	}
	
	if(buttons & IN_ATTACK)
	{
		SetEntPropVector(client, Prop_Send, "m_vecPunchAngle", view_as<float>({0.0, 0.0, 0.0}));
	}
	
	if(!g_bSilentAim[client]) {
		TeleportEntity(client, NULL_VECTOR, eye_to_target, NULL_VECTOR);
	}
	else {
		FixSilentAimMovement(client, vel, angles, eye_to_target);
	}
	
	angles = eye_to_target;
	bChanged = true;
	
	return bChanged ? Plugin_Changed : Plugin_Continue;
}

//Do all predictions so we can catch people coming round corners.
stock float[] SelectBestTargetPos(int client, float playerEyeAngles[3], int &iBestEnemy)
{
	float flBestDistance = 99999.0;
	float best_target_point[3];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(i == client)
			continue;
		
		if(!IsClientInGame(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		if(GetEntProp(i, Prop_Send, "m_iTeamNum") == GetClientTeam(client))
			continue;
		
		if(!TF2_IsKillable(i))
			continue;
		
		float target_point[3];
		
		if(IsProjectileWeapon(GetActiveWeapon(client)))
		{
			int iBone = IsHeadShotWeapon(GetActiveWeapon(client)) ? LookupBone(i, "bip_head") : LookupBone(i, "bip_pelvis");
			if(iBone == -1)
				continue;
			
			float vNothing[3];
			GetBonePosition(i, iBone, target_point, vNothing);
		
			float vecAbs[3]; vecAbs = GetAbsOrigin(i)
			vecAbs[2] += 5.0;
		
			if(GetEntityFlags(i) & FL_ONGROUND 
			&& IsExplosiveProjectileWeapon(GetActiveWeapon(client))
			&& IsPointVisible(client, playerEyeAngles, i, vecAbs))
			{
				//Aim at feet with explosive weapons.
				target_point = vecAbs;
			}
			
			AddVectors(target_point, PredictCorrection(client, GetActiveWeapon(client), i, GetAbsOrigin(client), 1), target_point);
		}
		else
		{
			int iBone = FindBestHitbox(client, playerEyeAngles, i);
			if(iBone == -1)
				continue;
			
			float vNothing[3];
			GetBonePosition(i, iBone, target_point, vNothing);
		}
		
		if(IsPointVisible(client, playerEyeAngles, i, target_point))
		{
			float flDistance = GetVectorDistance(target_point, best_target_point);
			
			if(flDistance < flBestDistance)
			{
				flBestDistance = flDistance;
				best_target_point = target_point;
				
				iBestEnemy = i;
			}
		}
	}

	return best_target_point;
}

stock bool IsHeadShotWeapon(int iWeapon)
{
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
		case TF_WEAPON_COMPOUND_BOW: return true;
	}
	
	return false;
}

stock float[] VectorFromPoints(float p1[3], float p2[3])		
{		
	float v[3];		
	MakeVectorFromPoints(p1, p2, v);		
	return v;		
}

stock float[] PredictCorrection(int iClient, int iWeapon, int iTarget, float vecFrom[3], int iQuality)
{
	if(!IsValidEntity(iWeapon))
		return vecFrom;
		
	float flSpeed = GetProjectileSpeed(iWeapon);
	if(flSpeed <= 0.0)
		return vecFrom;
		
	float sv_gravity = GetConVarFloat(FindConVar("sv_gravity")) * PlayerGravityMod(iTarget);
	
	float flLag = GetPlayerLerp(iClient);
	
	bool bOnGround = ((GetEntityFlags(iTarget) & FL_ONGROUND) != 0);
	
	float vecWorldGravity[3]; vecWorldGravity[2] = -sv_gravity * (bOnGround ? 0.0 : 1.0) * GetTickInterval() * GetTickInterval();
	float vecProjGravity[3];  vecProjGravity[2]  = sv_gravity  * GetProjectileGravity(iWeapon) * GetTickInterval() * GetTickInterval();
	
	float vecVelocity[3];
	GetEntPropVector(iTarget, Prop_Data, "m_vecAbsVelocity", vecVelocity);
//	vecVelocity = view_as<float>( { -0.000010, 239.999984, -160.999984 } );
	
	float vecProjVelocity[3]; vecProjVelocity = vecProjGravity;
	
	// get the current position
	// this is not important - any point inside the collideable will work.
	float vecStepPos[3]
	GetClientAbsOrigin(iTarget, vecStepPos);
	
	float vecMins[3], vecMaxs[3];
	GetClientMins(iTarget, vecMins);
	GetClientMaxs(iTarget, vecMaxs);
	
	// get velocity for a single tick
	ScaleVector(vecVelocity, GetTickInterval());
	ScaleVector(vecProjVelocity, GetTickInterval());
	
	float vecPredictedPos[3]; vecPredictedPos = vecStepPos;
	
	// get the current arival time
	float vecPredictedProjVel[3]; vecPredictedProjVel = vecProjVelocity; // TODO: rename - this is used for gravity
	
	float subtracted[3];
	SubtractVectors(vecFrom, vecPredictedPos, subtracted);
	
	float flArrivalTime = GetVectorLength(subtracted) / (flSpeed) + flLag + GetTickInterval();
	float vecPredictedVel[3]; vecPredictedVel = vecVelocity;
	
	Handle Trace = null;
	
	int iSteps = 0;
	
	if(flArrivalTime >= 3.0)
		return NULL_VECTOR;
	
	for(float flTravelTime = 0.0; flTravelTime < flArrivalTime; flTravelTime += (GetTickInterval() * iQuality))
	{
		// trace the velocity of the target
		float vecPredicted[3];
		AddVectors(vecPredictedPos, vecPredictedVel, vecPredicted);
		
		Trace = TR_TraceHullFilterEx(vecPredictedPos, vecPredicted, vecMins, vecMaxs, MASK_PLAYERSOLID, AimTargetFilter, iTarget);
		
		if(TR_GetFraction(Trace) != 1.0)
		{
			float vecNormal[3];
			TR_GetPlaneNormal(Trace, vecNormal);
			
			PhysicsClipVelocity(vecPredictedVel, vecNormal, vecPredictedVel, 1.0);
		}
		
		float vecTraceEnd[3];
		TR_GetEndPosition(vecTraceEnd, Trace);
		
		vecPredictedPos = vecTraceEnd;
		
		delete Trace;
		vecPredicted = NULL_VECTOR;
		
		// trace the gravity of the target
		AddVectors(vecPredictedPos, vecWorldGravity, vecPredicted);
		
		Trace = TR_TraceHullFilterEx(vecPredictedPos, vecPredicted, vecMins, vecMaxs, MASK_PLAYERSOLID, AimTargetFilter, iTarget);
		
		// this is important - we predict the world as moving up in order to predict for the projectile moving down
		AddVectors(vecPredictedVel, vecPredictedProjVel, vecPredictedVel);
		
		if(TR_GetFraction(Trace) == 1.0)
		{
			bOnGround = false;
			AddVectors(vecPredictedVel, vecWorldGravity, vecPredictedVel);
		}
		else if(!bOnGround)
		{
			float surfaceFriction = 1.0;
		//	gInts->PhysicsSurfaceProps->GetPhysicsProperties(tr.surface.surfaceProps, NULL, NULL, &surfaceFriction, NULL);
			
			if(PhysicsApplyFriction(vecPredictedVel, vecPredictedVel, surfaceFriction, GetTickInterval()))
			{
				break;
			}
		}
		
		delete Trace;
		
		float temp[3];
		SubtractVectors(vecFrom, vecPredictedPos, temp);
		
		flArrivalTime = GetVectorLength(temp) / (flSpeed) + flLag + GetTickInterval();
		
		// if they are moving away too fast then there is no way we can hit them - bail!!
		if(GetVectorLength(vecPredictedVel) > flSpeed)
		{
		//	PrintToChatAll("Target too fast! id = %d", iTarget);
			break;
		}
		
		iSteps++;
	}
	
//	PrintToServer("Simulation ran for %i steps", iSteps);

	//DrawDebugArrow(vecStepPos, vecPredictedPos, view_as<float>({255, 255, 0, 255}), 0.075);

	float flOut[3];
	SubtractVectors(vecPredictedPos, vecStepPos, flOut);
	
	return flOut;
}

//tf_parachute_gravity : 0.2f : , "sv", "rep", "launcher" : Gravity while parachute is deployed
stock float PlayerGravityMod(int client)
{
	if(GetEntityMoveType(client) == MOVETYPE_NOCLIP)
		return 0.0;

	if(TF2_IsPlayerInCondition(client, TFCond_Parachute))
		return 0.2;
		
	return 1.0;
}

stock void DrawDebugArrow(float vecFrom[3], float vecTo[3], float color[4], float life = 0.1)
{
	float subtracted[3];
	SubtractVectors(vecTo, vecFrom, subtracted);
	
	float angRotation[3];
	GetVectorAngles(subtracted, angRotation);
	
	float vecForward[3], vecRight[3], vecUp[3];
	GetAngleVectors(angRotation, vecForward, vecRight, vecUp);
	
	TE_SetupBeamPoints(vecFrom, vecTo, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, life, 2.0, 2.0, 5, 0.0, color, 30);
	TE_SendToAllInRange(vecFrom, RangeType_Visibility);

	float multi[3];
	multi[0] = vecRight[0] * 25;
	multi[1] = vecRight[1] * 25;
	multi[2] = vecRight[2] * 25;

	float subtr[3];
	SubtractVectors(vecFrom, multi, subtr);
	
	TE_SetupBeamPoints(vecFrom, subtr, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, life, 2.0, 5.0, 5, 0.0, view_as<float>({255, 0, 0, 255}), 30);
	TE_SendToAllInRange(vecFrom, RangeType_Visibility);
}

void PhysicsClipVelocity(const float input[3], float normal[3], float out[3], float overbounce)
{
	float backoff = GetVectorDotProduct(input, normal) * overbounce;

	for(int i = 0; i < 3; ++i)
	{
		float change = normal[i] * backoff;
		out[i] = input[i] - change;

		if(out[i] > -0.1 && out[i] < 0.1)
			out[i] = 0.0;
	}

	float adjust = GetVectorDotProduct(out, normal);

	if(adjust < 0.0)
	{
		ScaleVector(normal, adjust);
		
		SubtractVectors(out, normal, out);
	//	out -= (normal * adjust);
	}
}

bool PhysicsApplyFriction(float input[3], float out[3], float flSurfaceFriction, float flTickRate)
{
	float sv_friction = GetConVarFloat(FindConVar("sv_friction"));
	float sv_stopspeed = GetConVarFloat(FindConVar("sv_stopspeed"));

	float speed = GetVectorLength(input) / flTickRate;

	if(speed < 0.1)
		return false;

	float drop = 0.0;

	if(flSurfaceFriction != -1.0)
	{
		float friction = sv_friction * flSurfaceFriction;
		float control = (speed < sv_stopspeed) ? sv_stopspeed : speed;
		drop += control * friction * flTickRate;
	}

	float newspeed = speed - drop;

	if(newspeed < 0.0)
		newspeed = 0.0;

	if(newspeed != speed)
	{
		newspeed /= speed;
		
		out[0] = input[0] * newspeed;
		out[1] = input[1] * newspeed;
		out[2] = input[2] * newspeed;
	}

	out[0] -= input[0] * (1.0 - newspeed);
	out[1] -= input[1] * (1.0 - newspeed);
	out[2] -= input[2] * (1.0 - newspeed);
	
	out[0] *= flTickRate;
	out[1] *= flTickRate;
	out[2] *= flTickRate;
	
	return true;
}

float[] VelocityExtrapolate(int client, float eyepos[3])		
{
	float absVel[3];		
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", absVel);		
	
	float v[3];		
	
	v[0] = eyepos[0] + (absVel[0] * GetTickInterval());		
	v[1] = eyepos[1] + (absVel[1] * GetTickInterval());		
	v[2] = eyepos[2] + (absVel[2] * GetTickInterval());		
	
	return v;		
}

bool IsPlayerReloading(int client)
{
	int PlayerWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	
	if(!IsValidEntity(PlayerWeapon))
		return false;
	
	if(IsProjectileWeapon(PlayerWeapon))
		return false;
	
	if(GetEntProp(client, Prop_Send, "m_bFeignDeathReady"))
		return true;
	
	//Fix for pyro flamethrower aimbot not aiming.	
	if(TF2_GetPlayerClass(client) == TFClass_Pyro && GetPlayerWeaponSlot(client, 0) == PlayerWeapon)
		return false;
	
	//Wrangler doesn't reload
	if(SDKCall(g_hGetWeaponID, PlayerWeapon) == TF_WEAPON_LASER_POINTER)
		return false;
	
	//Melee weapons don't reload
	if (GetPlayerWeaponSlot(client, TFWeaponSlot_Melee) == PlayerWeapon)
	    return false;
	
	//Can't fire with 0 ammo
	int AmmoCur = GetEntProp(PlayerWeapon, Prop_Send, "m_iClip1");
	if(AmmoCur <= 0)
		return true;
	
	//if (GetEntPropFloat(PlayerWeapon, Prop_Send, "m_flLastFireTime") > GetEntPropFloat(PlayerWeapon, Prop_Send, "m_flReloadPriorNextFire"))
	if (GetEntPropFloat(PlayerWeapon, Prop_Send, "m_flNextPrimaryAttack") < GetGameTime())
	    return false;
	
	return true;
}

stock void EnemyIsAimingAtYou(int client)
{
	float flMyPos[3];
	GetClientEyePosition(client, flMyPos);
	
	float flMaxAngle = 999.0;
	float flAimingPercent;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(i == client)
			continue;
		
		if(!IsClientInGame(i))
			continue;
			
		if(!IsPlayerAlive(i))
			continue;
		
		if(GetClientTeam(i) == GetClientTeam(client))
			continue;
		
		float flTheirPos[3];
		GetClientEyePosition(i, flTheirPos);
		
		TR_TraceRayFilter(flMyPos, flTheirPos, MASK_SHOT|CONTENTS_GRATE, RayType_EndPoint, AimTargetFilter, client);
		if(TR_DidHit())
		{
			int entity = TR_GetEntityIndex();
			if(entity == i)
			{
				float vDistance[3];
				SubtractVectors(flMyPos, flTheirPos, vDistance);
				NormalizeVector(vDistance, vDistance);
				
				float flTheirEyeAng[3];
				GetClientEyeAngles(i, flTheirEyeAng);
				
				float vForward[3];
				GetAngleVectors(flTheirEyeAng, vForward, NULL_VECTOR, NULL_VECTOR);
				
				float flAngle = RadToDeg(ArcCosine(GetVectorDotProduct(vForward, vDistance)));
				
				if(flMaxAngle > flAngle && flAngle <= 60)
				{
					flMaxAngle = flAngle;
					flAimingPercent = 100 - (flMaxAngle * (100 / 60));
				}
			}
		}
	}
	
	if(flMaxAngle != 999)
	{
		char cPlayerAim[120];
		
		if(flAimingPercent >= 85.0)
		{
			SetHudTextParams(-1.0, 0.0, UMSG_SPAM_DELAY + 0.5, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
			Format(cPlayerAim, sizeof(cPlayerAim), "Enemy is AIMING at YOU %.0f%%", flAimingPercent);
		}
		else
		{
			SetHudTextParams(-1.0, 0.0, UMSG_SPAM_DELAY + 0.5, 0, 255, 0, 0, 0, 0.0, 0.0, 0.0);
			Format(cPlayerAim, sizeof(cPlayerAim), "Enemy can SEE YOU %.0f%%", flAimingPercent);
		}
		
		ShowSyncHudText(client, g_hHudEnemyAim, cPlayerAim);
	}
}

stock void Radar(int client, float playerAngles[3])
{
	float flMyPos[3];
	GetClientAbsOrigin(client, flMyPos);
	
	float screenx, screeny;
	float vecGrenDelta[3];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(i == client)
			continue;
		
		if(!IsClientInGame(i))
			continue;
		
		if(!IsPlayerAlive(i))
			continue;
		
		if(GetClientTeam(i) == GetClientTeam(client))
			continue;
		
		float flEnemyPos[3];
		GetClientAbsOrigin(i, flEnemyPos);
		
		flEnemyPos[2] = flMyPos[2]; //We only care about 2D
		
		vecGrenDelta = GetDeltaVector(client, i);
		NormalizeVector(vecGrenDelta, vecGrenDelta);
		GetEnemyPosToScreen(client, playerAngles, vecGrenDelta, screenx, screeny, GetVectorDistance(flMyPos, flEnemyPos) * 0.25);
		
		SetHudTextParams(screenx, screeny, UMSG_SPAM_DELAY + 0.5, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_hHudRadar[i], "⬤");
	}
}

stock void GetEnemyPosToScreen(int client, float playerAngles[3], float vecDelta[3], float& xpos, float& ypos, float flRadius)
{
	if(flRadius > 400.0)
		flRadius = 400.0;

	float vecforward[3], right[3], up[3] = { 0.0, 0.0, 1.0 };
	GetAngleVectors(playerAngles, vecforward, NULL_VECTOR, NULL_VECTOR );
	vecforward[2] = 0.0;

	NormalizeVector(vecforward, vecforward);
	GetVectorCrossProduct(up, vecforward, right);

	float front = GetVectorDotProduct(vecDelta, vecforward);
	float side  = GetVectorDotProduct(vecDelta, right);

	xpos = flRadius * -front;
	ypos = flRadius * -side;
	
	float flRotation = (ArcTangent2(xpos, ypos) + FLOAT_PI) * (180.0 / FLOAT_PI);
	
	float yawRadians = -flRotation * FLOAT_PI / 180.0; // Convert back to radians
	
	// Rotate it around the circle
	xpos = (500 + (flRadius * Cosine(yawRadians))) / 1000.0; // divide by 1000 to make it fit with HudTextParams
	ypos = (500 - (flRadius * Sine(yawRadians)))   / 1000.0;
}

stock int GetMaxHealth(int client)
{
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}

stock float[] GetDeltaVector(const int client, const int target)
{
	float vec[3];

	float vecPlayer[3];	
	GetClientAbsOrigin(client, vecPlayer);
	
	float vecPos[3];	
	GetClientAbsOrigin(target, vecPos);
	
	SubtractVectors(vecPlayer, vecPos, vec);
	return vec;
}

stock float Min(float one, float two)
{
	if(one < two)
		return one;
	else if(two < one)
		return two;
		
	return two;
}

stock float Max(float one, float two)
{
	if(one > two)
		return one;
	else if(two > one)
		return two;
		
	return two;
}

stock void FixSilentAimMovement(int client, float vel[3], float angles[3], float aimbotAngles[3])
{
	float vecSilent[3];
	vecSilent = vel;
	
	float flSpeed = SquareRoot(vecSilent[0] * vecSilent[0] + vecSilent[1] * vecSilent[1]);
	float angMove[3];
	GetVectorAngles(vecSilent, angMove);
	
	float flYaw = DegToRad(aimbotAngles[1] - angles[1] + angMove[1]);
	vel[0] = Cosine( flYaw ) * flSpeed;
	vel[1] = Sine( flYaw ) * flSpeed;
}

stock int FindBestHitbox(int client, float playerEyeAngles[3], int target)
{
	int iBestHitBox = g_bHeadshots[client] ? LookupBone(target, "bip_head") : LookupBone(target, "bip_pelvis");
	
	//Not headshots only
	if(!g_bHeadshots[client])
	{
		iBestHitBox = -1;
		
		for (int i = 0; i < 64; i++) //Replace with GetNumBones eventually.
		{
			if(IsBoneVisible(client, playerEyeAngles, target, i))
			{
				iBestHitBox = i;
				break;
			}
		}
	}
	
	if(iBestHitBox < 0 || !IsBoneVisible(client, playerEyeAngles, target, iBestHitBox))
		return -1;
	
	return iBestHitBox;
}

stock int LookupBone(int iEntity, const char[] szName)
{
	return SDKCall(g_hLookupBone, iEntity, szName);
}

stock void GetBonePosition(int iEntity, int iBone, float origin[3], float angles[3])
{
	SDKCall(g_hGetBonePosition, iEntity, iBone, origin, angles);
}

//client = me
//target = them
//vecEyeAng = passthrough value from OnPlayerRunCmd
stock bool IsBoneVisible(int client, float vecEyeAng[3], int target, int bone)
{	
	//Bone origin and angles
	float vBoneAngles[3], vBoneOrigin[3];
	GetBonePosition(target, bone, vBoneOrigin, vBoneAngles);
	
	return IsPointVisible(client, vecEyeAng, target, vBoneOrigin);
}

stock bool IsPointVisible(int client, float vecEyeAng[3], int target, float end[3])
{
	if(g_iAimType[client] == AIM_FOV)
	{
		//Our eye forward vector
		float vForward[3]; GetAngleVectors(vecEyeAng, vForward, NULL_VECTOR, NULL_VECTOR);
		
		//Direction vector from bone position to our eye position
		float vToTargetBone[3];
		SubtractVectors(end, GetEyePosition(client), vToTargetBone);
		
		//Normalize it.
		NormalizeVector(vToTargetBone, vToTargetBone);
		
		//Dot product to bone
		float flDot = GetVectorDotProduct(vForward, vToTargetBone);
		
		//Aimbot FOV max Dot
		float flMaxDot = 1.0 - (g_flAimFOV[client] / 180.0);
		
		bool bCanTarget = flDot >= flMaxDot;
		
	//	PrintToServer("%N | flDot %f / flMaxDot %f valid | %s", target, flDot, flMaxDot, bCanTarget ? "YES" : "NO");
		
		//Out of aimbot FOV
		if(!bCanTarget)
			return false;
	}
	
	//Trace from our eye pos to endpos
	TR_TraceRayFilter(GetEyePosition(client), end, MASK_SHOT|CONTENTS_GRATE, RayType_EndPoint, AimTargetFilter, client);
	if(!TR_DidHit() || TR_GetEntityIndex() == target)
	{
		return true;
	}
	
	return false;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if(!g_bNoSlowDown[client])
		return;

	if(condition == TFCond_Slowed)
		TF2_RemoveCondition(client, TFCond_Slowed);
	
	if(condition == TFCond_Dazed)
		TF2_RemoveCondition(client, TFCond_Dazed);
	
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.0);
}

stock bool TF2_IsKillable(int entity)
{
	bool bResult = true;

	if(entity > 0 && entity <= MaxClients)
	{
		if(TF2_IsPlayerInCondition(entity, TFCond_Ubercharged) 
		|| TF2_IsPlayerInCondition(entity, TFCond_UberchargedHidden) 
		|| TF2_IsPlayerInCondition(entity, TFCond_UberchargedCanteen)
		|| TF2_IsPlayerInCondition(entity, TFCond_Bonked))
		{
			bResult = false;
		}
	}
	
	if(GetEntProp(entity, Prop_Data, "m_takedamage") != 2)
	{
		bResult = false;
	}
	
	return bResult;
}

stock char strTargetEntities[][] =
{
	"player",
	"tank_boss",
	"headless_hatman",
	"eyeball_boss",
	"merasmus",
	"tf_zombie",
	"tf_robot_destruction_robot",
	"obj_sentrygun",
	"obj_dispenser",
	"obj_teleporter"
}

stock int FindHealer(int client)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_weapon_medigun")) != -1)
	{
		int hTarget = GetEntPropEnt(index, Prop_Send, "m_hHealingTarget");
		int hHealer = GetEntPropEnt(index, Prop_Send, "m_hOwnerEntity");
		
		if(client == hTarget)
		{
			return hHealer;
		}
	}
	
	return -1;
}

stock bool IsHitScanWeapon(int iWeapon)
{
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
		case TF_WEAPON_SMG:                   return true;
		case TF_WEAPON_PISTOL:                return true;
		case TF_WEAPON_MINIGUN:               return true;
		case TF_WEAPON_REVOLVER:              return true;
		case TF_WEAPON_SCATTERGUN:            return true;
		case TF_WEAPON_SNIPERRIFLE:           return true;
		case TF_WEAPON_SHOTGUN_HWG:           return true;
		case TF_WEAPON_SODA_POPPER:           return true;
		case TF_WEAPON_SHOTGUN_PYRO:          return true;
		case TF_WEAPON_PISTOL_SCOUT:          return true;
		case TF_WEAPON_SENTRY_BULLET:         return true;
		case TF_WEAPON_SENTRY_ROCKET:         return true;
		case TF_WEAPON_SENTRY_REVENGE:        return true;
		case TF_WEAPON_SHOTGUN_SOLDIER:       return true;
		case TF_WEAPON_SHOTGUN_PRIMARY:       return true;
		case TF_WEAPON_HANDGUN_SCOUT_SEC:     return true;
		case TF_WEAPON_PEP_BRAWLER_BLASTER:   return true;
		case TF_WEAPON_SNIPERRIFLE_CLASSIC:   return true;
		case TF_WEAPON_HANDGUN_SCOUT_PRIMARY: return true;
	}
	
	return false;
}

stock bool IsProjectileWeapon(int iWeapon)
{
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
	//	case TF_WEAPON_BAT_WOOD:                return true;	//Crashes server
		case TF_WEAPON_SYRINGEGUN_MEDIC:        return true;
		case TF_WEAPON_ROCKETLAUNCHER:          return true;
		case TF_WEAPON_GRENADELAUNCHER:         return true;
		case TF_WEAPON_PIPEBOMBLAUNCHER:        return true;
		case TF_WEAPON_FLAMETHROWER:            return true;
		case TF_WEAPON_FLAMETHROWER_ROCKET:     return true;
		case TF_WEAPON_GRENADE_DEMOMAN:         return true;
		case TF_WEAPON_SENTRY_ROCKET:           return true;
		case TF_WEAPON_FLAREGUN:                return true;
		case TF_WEAPON_COMPOUND_BOW:            return true;
		case TF_WEAPON_DIRECTHIT:               return true;
		case TF_WEAPON_CROSSBOW:                return true;
		case TF_WEAPON_STICKBOMB:               return true;
		case TF_WEAPON_PARTICLE_CANNON:         return true;
		case TF_WEAPON_DRG_POMSON:              return true;
		case TF_WEAPON_BAT_GIFTWRAP:            return true;
		case TF_WEAPON_GRENADE_ORNAMENT:        return true;
		case TF_WEAPON_RAYGUN_REVENGE:          return true;
		case TF_WEAPON_CLEAVER:                 return true;
		case TF_WEAPON_GRENADE_CLEAVER:         return true;
		case TF_WEAPON_STICKY_BALL_LAUNCHER:    return true;
		case TF_WEAPON_GRENADE_STICKY_BALL:     return true;
		case TF_WEAPON_SHOTGUN_BUILDING_RESCUE: return true;
		case TF_WEAPON_CANNON:                  return true;
		case TF_WEAPON_THROWABLE:               return true;
		case TF_WEAPON_GRENADE_THROWABLE:       return true;
		case TF_WEAPON_SPELLBOOK:               return true;
		case TF_WEAPON_GRAPPLINGHOOK:           return true;
		case TF_WEAPON_PASSTIME_GUN:            return true;
		case TF_WEAPON_JAR:                     return true;
		case TF_WEAPON_JAR_MILK:                return true;
		case TF_WEAPON_RAYGUN:                  return true;
	}
	
	return false;
}

//Bad name, meant for weapons which you can target teammates with
stock bool IsTeammateWeapon(int iWeapon)
{
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
		case TF_WEAPON_MEDIGUN:  return true;
		case TF_WEAPON_CROSSBOW: return true;
	}
	
	return false;
}

stock bool IsReadyToFire(int iWeapon)
{
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
		case TF_WEAPON_SNIPERRIFLE, TF_WEAPON_SNIPERRIFLE_DECAP:
		{
			float flDamage = GetEntPropFloat(iWeapon, Prop_Send, "m_flChargedDamage");
			if (flDamage < 5.0)
			{
				return false;
			}
		}
		case TF_WEAPON_SNIPERRIFLE_CLASSIC:
		{
			if(GetEntProp(iWeapon, Prop_Send, "m_bCharging"))
			{
				float flDamage = GetEntPropFloat(iWeapon, Prop_Send, "m_flChargedDamage");
				
				if (flDamage >= 150.0)
				{
					return false;
				}
				
				return true;
			}
		}
		case TF_WEAPON_COMPOUND_BOW:
		{		
			float flChargeBeginTime = GetEntPropFloat(iWeapon, Prop_Send, "m_flChargeBeginTime");
			
			float flCharge = flChargeBeginTime == 0.0 ? 0.0 : GetGameTime() - flChargeBeginTime;
			
			if(flCharge > 0.0)
			{
				return false;
			}
		}
		case TF_WEAPON_REVOLVER:
		{
			float flLastFireTime = GetGameTime() - GetEntPropFloat(iWeapon, Prop_Send, "m_flLastFireTime");
			
			if(flLastFireTime < 1.0)
			{
				return false;
			}
		}
	}
	
	return true;
}

stock bool IsExplosiveProjectileWeapon(int iWeapon)
{
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
		case TF_WEAPON_PIPEBOMBLAUNCHER: return true;
		case TF_WEAPON_GRENADELAUNCHER:  return true;
		case TF_WEAPON_PARTICLE_CANNON:  return true;
		case TF_WEAPON_ROCKETLAUNCHER:   return true;
		case TF_WEAPON_DIRECTHIT:        return true;
		case TF_WEAPON_CANNON:           return true;
		case TF_WEAPON_JAR:              return true;
	}
	
	return false;
}

//Always make sure IsProjectileWeapon is true before calling this.
stock float GetProjectileSpeed(int iWeapon)
{	
	float flProjectileSpeed = SDKCall(g_hGetProjectileSpeed, iWeapon);
	if(flProjectileSpeed == 0.0)
	{
		//Some projectiles speeds are hardcoded so we manually return them here.
		switch(SDKCall(g_hGetWeaponID, iWeapon))
		{
			case TF_WEAPON_ROCKETLAUNCHER:   flProjectileSpeed = 1100.0;
			case TF_WEAPON_DIRECTHIT:        flProjectileSpeed = 1980.0;
			case TF_WEAPON_FLAREGUN:         flProjectileSpeed = 2000.0;
			case TF_WEAPON_RAYGUN_REVENGE:   flProjectileSpeed = 2000.0; //Manmelter
			case TF_WEAPON_FLAMETHROWER:     flProjectileSpeed = 1500.0;
			case TF_WEAPON_SYRINGEGUN_MEDIC: flProjectileSpeed = 990.0;
		}
	}
	
	//Rocket Specialist
	Address attrib = TF2Attrib_GetByDefIndex(iWeapon, 488);
	if(attrib != Address_Null)
	{
		//NASA Math
		float flMultiplier = TF2Attrib_GetValue(attrib);		
		flProjectileSpeed += flProjectileSpeed * (1.15 * flMultiplier);
		
		//PrintToServer("Rocket Specialist %f -> %f", flMultiplier, flProjectileSpeed);
	}
	
	//Projectile speed increased
	attrib = TF2Attrib_GetByDefIndex(iWeapon, 103);		
	if(attrib != Address_Null)
	{
		//NASA Math		
		float flMultiplier = TF2Attrib_GetValue(attrib);				
		flProjectileSpeed += flProjectileSpeed * flMultiplier;		
		
		//PrintToServer("Projectile speed increased %f -> %f", flMultiplier, flProjectileSpeed);		
	}
	
	return flProjectileSpeed;
}

stock float GetProjectileGravity(int iWeapon)
{
	float flProjectileGravity = SDKCall(g_hGetProjectileGravity, iWeapon);
	
	//Wrong.
	switch(SDKCall(g_hGetWeaponID, iWeapon))
	{
		case TF_WEAPON_JAR:                     flProjectileGravity = 50.0;
		case TF_WEAPON_CANNON:                  flProjectileGravity = 75.0;
		case TF_WEAPON_FLAREGUN:                flProjectileGravity = 18.5;
		case TF_WEAPON_RAYGUN_REVENGE:          flProjectileGravity = 12.5; //Manmelter
		case TF_WEAPON_CROSSBOW:                flProjectileGravity *= 65.0;
		case TF_WEAPON_COMPOUND_BOW:            flProjectileGravity *= 64.0;
		case TF_WEAPON_GRENADELAUNCHER:         flProjectileGravity = 51.0;
		case TF_WEAPON_PIPEBOMBLAUNCHER:        flProjectileGravity = 60.0;
		case TF_WEAPON_SYRINGEGUN_MEDIC:        flProjectileGravity = 15.0;
		case TF_WEAPON_SHOTGUN_BUILDING_RESCUE: flProjectileGravity *= 70.0;
	}
	
	return flProjectileGravity;
}

public bool AimTargetFilter(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "player"))
	{
		if(GetClientTeam(entity) == GetClientTeam(iExclude) && !g_bTeammates[iExclude])
		{
			return false;
		}
	}
	else if(StrEqual(class, "entity_medigun_shield"))
	{
		if(GetEntProp(entity, Prop_Send, "m_iTeamNum") == GetClientTeam(iExclude))
		{
			return false;
		}
	}
	else if(StrEqual(class, "func_respawnroomvisualizer"))
	{
		return false;
	}
	else if(StrContains(class, "tf_projectile_", false) != -1)
	{
		return false;
	}
	
	return !(entity == iExclude);
}

public bool WorldOnly(int entity, int contentsMask, any iExclude)
{
	char class[64];
	GetEntityClassname(entity, class, sizeof(class));
	
	if(StrEqual(class, "entity_medigun_shield"))
	{
		if(GetEntProp(entity, Prop_Send, "m_iTeamNum") == GetClientTeam(iExclude))
		{
			return false;
		}
	}
	else if(StrEqual(class, "func_respawnroomvisualizer"))
	{
		return false;
	}
	else if(StrContains(class, "tf_projectile_", false) != -1)
	{
		return false;
	}
	
	return !(entity == iExclude);
}

stock float AngleNormalize( float angle )
{
	angle = angle - 360.0 * RoundToFloor(angle / 360.0);
	while (angle > 180.0) angle -= 360.0;
	while (angle < -180.0) angle += 360.0;
	return angle;
}

stock float GetPlayerLerp(int client)
{
	return GetEntPropFloat(client, Prop_Data, "m_fLerpTime");
}

stock void TE_SendBox(float vMins[3], float vMaxs[3], int color[4])
{
	float vPos1[3], vPos2[3], vPos3[3], vPos4[3], vPos5[3], vPos6[3];
	vPos1 = vMaxs;
	vPos1[0] = vMins[0];
	vPos2 = vMaxs;
	vPos2[1] = vMins[1];
	vPos3 = vMaxs;
	vPos3[2] = vMins[2];
	vPos4 = vMins;
	vPos4[0] = vMaxs[0];
	vPos5 = vMins;
	vPos5[1] = vMaxs[1];
	vPos6 = vMins;
	vPos6[2] = vMaxs[2];
//	TE_SendBeam(vMaxs, vPos1, color);
//	TE_SendBeam(vMaxs, vPos2, color);
	TE_SendBeam(vMaxs, vPos3, color);	//Vertical
//	TE_SendBeam(vPos6, vPos1, color);
//	TE_SendBeam(vPos6, vPos2, color);
	TE_SendBeam(vPos6, vMins, color);	//Vertical
//	TE_SendBeam(vPos4, vMins, color);
//	TE_SendBeam(vPos5, vMins, color);
	TE_SendBeam(vPos5, vPos1, color);	//Vertical
//	TE_SendBeam(vPos5, vPos3, color);
//	TE_SendBeam(vPos4, vPos3, color);
	TE_SendBeam(vPos4, vPos2, color);	//Vertical
}

stock void TE_SendBeam(const float vMins[3], const float vMaxs[3], const int color[4])
{
	TE_SetupBeamPoints(vMins, vMaxs, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 0, 0.075, 1.0, 1.0, 1, 0.0, color, 0);
	TE_SendToAll();
}

stock float[] GetAbsVelocity(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", v);
	return v;
}

stock float[] GetAbsOrigin(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", v);
	return v;
}

stock float[] GetEyePosition(int client)
{
	float v[3];
	GetClientEyePosition(client, v);
	return v;
}

stock float[] GetEyeAngles(int client)
{
	float v[3];
	GetClientEyeAngles(client, v);
	return v;
}

stock int GetActiveWeapon(int client)
{
	return GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
}