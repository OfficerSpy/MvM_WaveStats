#include <sourcemod>
#include <tf2_stocks>
#include <multicolors>

#define STATS_DISPLAY_TIME	15

bool hasWaveBegun;

int robotKills[MAXPLAYERS + 1];
int robotDamage[MAXPLAYERS + 1];
int tankDamage[MAXPLAYERS + 1];
int cashMoney[MAXPLAYERS + 1];
int canteenUse[MAXPLAYERS + 1];
int flagDefend[MAXPLAYERS + 1];
// int bombReset[MAXPLAYERS + 1];
//TODO: track how much healing was done

#include "mvmstats/menu.sp"

public Plugin myinfo =
{
	name = "[TF2] MvM Wave Statistics",
	author = "Officer Spy",
	description = "Reports details about a game after a wave has ended.",
	version = "1.0.3",
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_wavestats", Command_WaveStats, "Brings up the wave statistics menu.");
	
	HookEvent("mvm_begin_wave", Event_BeginWave);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("npc_hurt", Event_NPCHurt);
	HookEvent("mvm_pickup_currency", Event_PickupCurrency);
	HookEvent("player_used_powerup_bottle", Event_PowerupBottle);
	HookEvent("teamplay_flag_event", Event_FlagObjective);
	HookEvent("mvm_wave_complete", Event_WaveComplete);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("teamplay_round_win", Event_RoundWin); //Used for wave losses
	HookEvent("mvm_sniper_headshot_currency", Event_HeadshotCurrency);
}

public Action Command_WaveStats(int client, int args)
{
	if (!hasWaveBegun)
	{
		CReplyToCommand(client, "[{unique}MVMStats{default}] A wave hasn't happened yet.");
		return Plugin_Handled;
	}
	
	DisplayMenu(WaveStatsMenu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	CreateWaveStatsMenu();
	hasWaveBegun = false;
}

public void OnClientDisconnect(int client)
{
	ResetWaveStats(client); //Prevent inaccurate data
}

public void Event_BeginWave(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			ResetWaveStats(i);
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (IsValidClientIndex(attacker) && TF2_GetClientTeam(attacker) == TFTeam_Red)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		
		if (client != attacker && TF2_GetClientTeam(client) == TFTeam_Blue)
		{
			int damage = event.GetInt("damageamount");
			robotDamage[attacker] += damage;
		}
	}
}

public void Event_NPCHurt(Event event, const char[] name, bool dontBroadcast)
{
	int entity = event.GetInt("entindex");
	char classname[10]; GetEntityClassname(entity, classname, sizeof(classname));
	
	if (StrEqual(classname, "tank_boss"))
	{
		int attacker = GetClientOfUserId(event.GetInt("attacker_player"));
		if (IsValidClientIndex(attacker) && TF2_GetClientTeam(attacker) == TFTeam_Red)
		{
			int damage = event.GetInt("damageamount");
			tankDamage[attacker] += damage;
		}
	}
}

public void Event_PickupCurrency(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	
	if (TF2_GetClientTeam(client) == TFTeam_Red)
	{
		int credits = event.GetInt("currency");
		cashMoney[client] += credits;
	}
}

public void Event_PowerupBottle(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	
	if (TF2_GetClientTeam(client) == TFTeam_Red)
		canteenUse[client]++;
}

public void Event_FlagObjective(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	int eventType = event.GetInt("eventtype");
	
	if (eventType == TF_FLAGEVENT_DEFENDED && TF2_GetClientTeam(client) == TFTeam_Red)
		flagDefend[client]++;
}

public void Event_WaveComplete(Event event, const char[] name, bool dontBroadcast)
{
	UpdateWaveStatsMenu();
	hasWaveBegun = true;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			DisplayMenu(WaveStatsMenu, i, STATS_DISPLAY_TIME);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int deathFlags = event.GetInt("death_flags");
	
	if (deathFlags & TF_DEATHFLAG_DEADRINGER)
		return;
	
	if (client == attacker)
		return;
	
	if (IsValidClientIndex(attacker) && TF2_GetClientTeam(attacker) == TFTeam_Red)
	{
		if (TF2_GetClientTeam(client) == TFTeam_Blue)
		{
			robotKills[attacker]++;
		}
	}
}

public void Event_RoundWin(Event event, const char[] name, bool dontBroadcast)
{
	UpdateWaveStatsMenu();
	hasWaveBegun = true;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			DisplayMenu(WaveStatsMenu, i, STATS_DISPLAY_TIME);
}

public void Event_HeadshotCurrency(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TF2_GetClientTeam(client) == TFTeam_Red)
	{
		int credits = event.GetInt("currency");
		cashMoney[client] += credits;
	}
}

void ResetWaveStats(int client)
{
	robotKills[client] = 0;
	robotDamage[client] = 0;
	tankDamage[client] = 0;
	cashMoney[client] = 0;
	canteenUse[client] = 0;
	flagDefend[client] = 0;
	// bombReset[client] = 0;
}

stock bool IsValidClientIndex(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
		return true;
		
	return false;
}

stock char[] NamePlayerClass(int client)
{
	char strClass[9];
	
	switch(TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:	strClass = "Scout";
		case TFClass_Soldier:	strClass = "Soldier";
		case TFClass_Pyro:	strClass = "Pyro";
		case TFClass_DemoMan:	strClass = "Demoman";
		case TFClass_Heavy:	strClass = "Heavy";
		case TFClass_Engineer:	strClass = "Engineer";
		case TFClass_Medic:	strClass = "Medic";
		case TFClass_Sniper:	strClass = "Sniper";
		case TFClass_Spy:	strClass = "Spy";
		case TFClass_Unknown:	strClass = "Unknown";
	}
	
	return strClass;
}

stock char[] GetMissionName()
{
	char missionName[128];
	int objRsrc = FindEntityByClassname(-1, "tf_objective_resource");
	
	if (IsValidEntity(objRsrc))
	{
		GetEntPropString(objRsrc, Prop_Send, "m_iszMvMPopfileName", missionName, sizeof(missionName));
		ReplaceString(missionName, sizeof(missionName), "scripts/population/", "");
		ReplaceString(missionName, sizeof(missionName), ".pop", "");
	}
	else
		LogError("COULD NOT LOCATE ENTITY tf_objective_resource!");
	
	return missionName;
}