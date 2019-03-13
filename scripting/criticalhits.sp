//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define PLUGIN_DESCRIPTION "Critical hits similar to Team Fortress 2 for other Source games."
#define PLUGIN_VERSION "1.0.0"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>
#include <criticalhits>

//Forwards
Handle g_Forward_OnWeaponCritical;
Handle g_Forward_OnWeaponCriticalPost;

//ConVars
ConVar convar_Status;
ConVar convar_Always;
ConVar convar_Multiplier_Min;
ConVar convar_Multiplier_Max;
ConVar convar_Chance_Min;
ConVar convar_Chance_Max;
ConVar convar_Chance_Level;
ConVar convar_Sound;

//Globals
bool g_Late;
bool g_DisableCrits[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[Any] Critical Hits", 
	author = "Keith Warren (Drixevel)", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://github.com/drixevel"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("criticalhits");

	CreateNative("CriticalHits_ToggleCrits", Native_ToggleCrits);

	g_Forward_OnWeaponCritical = CreateGlobalForward("OnWeaponCritical", ET_Event, Param_Cell, Param_Cell, Param_String, Param_CellByRef);
	g_Forward_OnWeaponCriticalPost = CreateGlobalForward("OnWeaponCriticalPost", ET_Ignore, Param_Cell, Param_Cell, Param_String);

	g_Late = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	CreateConVar("sm_criticalhits_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	convar_Status = CreateConVar("sm_criticalhits_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Always = CreateConVar("sm_criticalhits_always", "0", "Enable or disable criticals to always occur.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Multiplier_Min = CreateConVar("sm_criticalhits_multiplier_min", "0.70", "Minimum multiplier if a hit is a crit.", FCVAR_NOTIFY, true, 0.0);
	convar_Multiplier_Max = CreateConVar("sm_criticalhits_multiplier_max", "0.90", "Maximum multiplier if a hit is a crit.", FCVAR_NOTIFY, true, 0.0);
	convar_Chance_Min = CreateConVar("sm_criticalhits_chance_min", "0.0", "Minimum chance to measure with the level.", FCVAR_NOTIFY, true, 0.0);
	convar_Chance_Max = CreateConVar("sm_criticalhits_chance_max", "100.0", "Maximum chance to measure with the level.", FCVAR_NOTIFY, true, 0.0);
	convar_Chance_Level = CreateConVar("sm_criticalhits_chance_level", "20.0", "Level of chance to grant based on min/max.", FCVAR_NOTIFY, true, 0.0);
	
	char sSound[PLATFORM_MAX_PATH];
	switch (GetEngineVersion())
	{
		case Engine_CSGO: sSound = "training/timer_bell.wav";
		case Engine_CSS: sSound = "player/bhit_helmet-1.wav";
		case Engine_Left4Dead2: sSound = "ui/littlereward.wav";
	}
	
	convar_Sound = CreateConVar("sm_criticalhits_sound", sSound, "Sound to play when a crit lands.", FCVAR_NOTIFY, true);
	
	AutoExecConfig();

	RegAdminCmd("sm_togglecrits", Command_ToggleCrits, ADMFLAG_SLAY, "Toggle crits on certain players.");
}

public void OnMapStart()
{
	char sSound[PLATFORM_MAX_PATH];
	convar_Sound.GetString(sSound, sizeof(sSound));
	
	if (strlen(sSound) > 0)
	{
		PrecacheSound(sSound);
		
		if (StrContains(sSound, "sound/", false) != 0)
			Format(sSound, sizeof(sSound), "sound/%s", sSound);
		
		AddFileToDownloadsTable(sSound);
	}
}

public void OnConfigsExecuted()
{
	if (g_Late)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
				OnClientPutInServer(i);
		}

		g_Late = false;
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if (!convar_Status.BoolValue || attacker == 0 || attacker > MaxClients || (damagetype & DMG_BULLET) != DMG_BULLET)
		return Plugin_Continue;
	
	if (convar_Always.BoolValue || !g_DisableCrits[attacker] && GetRandomFloat(convar_Chance_Min.FloatValue, convar_Chance_Max.FloatValue) <= convar_Chance_Level.FloatValue)
	{
		bool status = true;
		int active = GetActiveWeapon(attacker);

		char sActive[32];
		GetEntityClassname(active, sActive, sizeof(sActive));

		Call_StartForward(g_Forward_OnWeaponCritical);
		Call_PushCell(attacker);
		Call_PushCell(active);
		Call_PushString(sActive);
		Call_PushCellRef(status);
		
		Action results = Plugin_Continue;
		if (Call_Finish(results) != SP_ERROR_NONE || results == Plugin_Handled || results == Plugin_Stop)
			return Plugin_Continue;
		
		if (results == Plugin_Changed && !status)
			return Plugin_Continue;

		damage = FloatMultiplier(damage, GetRandomFloat(convar_Multiplier_Min.FloatValue, convar_Multiplier_Max.FloatValue));

		char sSound[PLATFORM_MAX_PATH];
		convar_Sound.GetString(sSound, sizeof(sSound));
		
		if (strlen(sSound) > 0 && IsSoundPrecached(sSound))
			EmitSoundToClient(attacker, sSound);
		
		Call_StartForward(g_Forward_OnWeaponCriticalPost);
		Call_PushCell(attacker);
		Call_PushCell(active);
		Call_PushString(sActive);
		Call_Finish();

		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action Command_ToggleCrits(int client, int args)
{
	if (args < 1)
	{
		char sCommand[32];
		GetCommandName(sCommand, sizeof(sCommand));
		ReplyToCommand(client, "[SM] Usage: %s <#userid|name> <0/1>", sCommand);
		return Plugin_Handled;
	}
	
	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	bool status = GetCmdArgBool(2);

	int iTargets[MAXPLAYERS];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;
	
	int count;
	if ((count = ProcessTargetString(sTarget, client, iTargets, sizeof(iTargets), 0, sTargetName, sizeof(sTargetName), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, count);
		return Plugin_Handled;
	}

	for (int i = 0; i < count; i++)
		g_DisableCrits[iTargets[i]] = !status;

	if (tn_is_ml)
		ShowActivity2(client, "[SM] ", "Toggled crits for %t to %s!", sTargetName, status ? "ON" : "OFF");
	else
		ShowActivity2(client, "[SM] ", "Toggled crits for %s to %s!", sTargetName, status ? "ON" : "OFF");

	return Plugin_Handled;
}

public int Native_ToggleCrits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	g_DisableCrits[client] = GetNativeCell(2);
}