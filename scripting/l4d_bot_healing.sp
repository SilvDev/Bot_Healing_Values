/*
*	Bot Healing Values
*	Copyright (C) 2022 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION 		"1.0"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Bot Healing Values
*	Author	:	SilverShot
*	Descrp	:	Set the health value bots require before using First Aid, Pain Pills or Adrenaline.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=338889
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.0 (01-Aug-2022)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d_bot_healing"


bool g_bLeft4Dead2;
ConVar g_hCvarFirst, g_hCvarPills;
float g_fCvarFirst, g_fCvarPills;
float g_fFirst, g_fPills;
Address g_iAddressFirst, g_iAddressPills;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Bot Healing Values",
	author = "SilverShot",
	description = "Set the health value bots require before using First Aid, Pain Pills or Adrenaline.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=338889"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	// GameData
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	// First Aid
	g_iAddressFirst = hGameData.GetAddress("BotHealing_FirstAid");
	if( g_iAddressFirst == Address_Null ) SetFailState("Error finding the 'FirstAid' address (%d).", g_iAddressFirst);

	// Pills
	g_iAddressPills = hGameData.GetAddress("BotHealing_Pills");
	if( g_iAddressPills == Address_Null ) SetFailState("Error finding the 'Pills' address (%d).", g_iAddressPills);

	// Default values
	g_fFirst = view_as<float>(LoadFromAddress(g_iAddressFirst, NumberType_Int32));
	g_fPills = view_as<float>(LoadFromAddress(g_iAddressPills, NumberType_Int32));

	// Detour
	DynamicDetour hDetour = DynamicDetour.FromConf(hGameData, "SurvivorBot::UseHealingItems");
	if( !hDetour ) SetFailState("Failed to find \"SurvivorBot::UseHealingItems\" signature.");
	if( !hDetour.Enable(Hook_Pre, DetourUseHealingPre) ) SetFailState("Failed to detour: \"SurvivorBot::UseHealingItems\" pre.");
	if( !hDetour.Enable(Hook_Post, DetourUseHealingPost) ) SetFailState("Failed to detour: \"SurvivorBot::UseHealingItems\" post.");

	delete hDetour;
	delete hGameData;

	// ConVars
	g_hCvarFirst = CreateConVar("l4d_bot_healing_first", g_bLeft4Dead2 ? "30.0" : "40.0", "Allow bots to use First Aid when their health is below this value.", CVAR_FLAGS);
	g_hCvarPills = CreateConVar("l4d_bot_healing_pills", g_bLeft4Dead2 ? "50.0" : "60.0", "Allow bots to use Pills or Adrenaline when their health is below this value.", CVAR_FLAGS);
	CreateConVar("l4d_bot_healing_version", PLUGIN_VERSION, "Bot Healing Values plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true, "l4d_bot_healing");

	g_hCvarFirst.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarPills.AddChangeHook(ConVarChanged_Cvars);

	// L4D2:
	// PrintToServer("BotHealing: 30.0 == %f", 0x41F00000); // 30.0 // First Aid
	// PrintToServer("BotHealing: 50.0 == %f", 0x42480000); // 50.0 // Pills
}

public void OnConfigsExecuted()
{
	GetCvars();
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fCvarFirst = g_hCvarFirst.FloatValue;
	g_fCvarPills = g_hCvarPills.FloatValue;
}

MRESReturn DetourUseHealingPre(int pThis, Handle hReturn, Handle hParams)
{
	StoreToAddress(g_iAddressFirst, view_as<int>(g_fCvarFirst), NumberType_Int32, false);
	StoreToAddress(g_iAddressPills, view_as<int>(g_fCvarPills), NumberType_Int32, false);

	return MRES_Ignored;
}

MRESReturn DetourUseHealingPost(Handle hReturn, Handle hParams)
{
	StoreToAddress(g_iAddressFirst, view_as<int>(g_fFirst), NumberType_Int32, false);
	StoreToAddress(g_iAddressPills, view_as<int>(g_fPills), NumberType_Int32, false);

	return MRES_Ignored;
}