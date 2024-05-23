#include <sourcemod>
#include <tf2_stocks>
#include <multicolors>

#define PLUGIN_PREFIX	"{unique}[MvMStats]"
#define STATS_DISPLAY_TIME	10
#define MVM_MAX_WAVE_NUMBERS	64

#include <stocklib_officerspy/tf/tf_objective_resource>

bool g_bHasWaveBegun;

//Time stats
float g_flWaveTimes[MVM_MAX_WAVE_NUMBERS];
bool g_bWavePassed[MVM_MAX_WAVE_NUMBERS];
float g_flWaveStartTime = 0.0;
float g_flWavesTotalTime = 0.0;
int g_iLastWaveNumber = 0;
int g_iFailCounterTick = 0;
Handle g_hWaveTimeTimer = null;

int g_iRobotKills[MAXPLAYERS + 1];
int g_iRobotDamage[MAXPLAYERS + 1];
int g_iTankDamage[MAXPLAYERS + 1];
int g_iCashMoney[MAXPLAYERS + 1];
int g_iCanteenUse[MAXPLAYERS + 1];
int g_iFlagDefend[MAXPLAYERS + 1];
// int bombReset[MAXPLAYERS + 1];
//TODO: track how much healing was done

ConVar mvmwavestats_write_wave_time;
ConVar mvmwavestats_wavetime_text_color1;
ConVar mvmwavestats_wavetime_text_color2;


char g_sWaveTimeTextColor1[PLATFORM_MAX_PATH];
char g_sWaveTimeTextColor2[PLATFORM_MAX_PATH];

#include "mvmstats/menu.sp"

public Plugin myinfo =
{
	name = "[TF2] MvM Wave Statistics",
	author = "Officer Spy",
	description = "Reports details about a game after a wave has ended.",
	version = "1.0.6",
	url = ""
};

public void OnPluginStart()
{
	mvmwavestats_write_wave_time = CreateConVar("sm_mvmwavestats_write_wave_time", "1", "write wave time in client chat");
	mvmwavestats_wavetime_text_color1 = CreateConVar("sm_mvmwavestats_wavetime_text_color1", "00FFFF", "Text color for wave time sentence", FCVAR_NONE);
	mvmwavestats_wavetime_text_color2 = CreateConVar("sm_mvmwavestats_wavetime_text_color2", "FFD800", "Text color for wave time time", FCVAR_NONE);
	
	HookConVarChange(mvmwavestats_wavetime_text_color1, ConVarChanged_WaveTimeTextColor);
	HookConVarChange(mvmwavestats_wavetime_text_color2, ConVarChanged_WaveTimeTextColor);
	
	RegConsoleCmd("sm_wavestats", Command_WaveStats, "Brings up the wave statistics menu.");
	RegConsoleCmd("sm_wave_time", Command_WaveTime, "Shows times for all waves in the mission");
	RegConsoleCmd("sm_wave_summary", Command_WaveTime, "Shows times for all waves in the mission");
	
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
	HookEvent("mvm_begin_wave", Event_BeginWave_Time);
	HookEvent("mvm_wave_complete", Event_WaveComplete_Time);
	HookEvent("mvm_wave_failed", Event_WaveFail_Time);
	HookEvent("mvm_mission_complete", Event_MissionComplete_Time);
	HookEvent("teamplay_round_start", Event_RestartRound_Time);
	
	mvmwavestats_wavetime_text_color1.GetString(g_sWaveTimeTextColor1, sizeof(g_sWaveTimeTextColor1));
	mvmwavestats_wavetime_text_color2.GetString(g_sWaveTimeTextColor2, sizeof(g_sWaveTimeTextColor2));
}

public void ConVarChanged_WaveTimeTextColor(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == mvmwavestats_wavetime_text_color1)
		strcopy(g_sWaveTimeTextColor1, sizeof(g_sWaveTimeTextColor1), newValue);
	else if (convar == mvmwavestats_wavetime_text_color2)
		strcopy(g_sWaveTimeTextColor2, sizeof(g_sWaveTimeTextColor2), newValue);
}

public Action Command_WaveStats(int client, int args)
{
	if (!g_bHasWaveBegun)
	{
		CReplyToCommand(client, "[{unique}MVMStats{default}] A wave hasn't happened yet.");
		return Plugin_Handled;
	}
	
	DisplayMenu(g_hWaveStatsMenu, client, 30);
	
	return Plugin_Handled;
}

public Action Command_WaveTime(int client, int args)
{
	DisplayWaveTimesTotal(client);
	return Plugin_Handled;
}

public void OnMapStart()
{
	CreateWaveStatsMenu();
	g_bHasWaveBegun = false;
	ResetTimeStats();
	
	//TIMER_FLAG_NO_MAPCHANGE kills this timer on map change, so it's not valid when a new map has loaded
	if (g_hWaveTimeTimer)
		g_hWaveTimeTimer = null;
}

public void OnClientDisconnect(int client)
{
	//Prevent inaccurate data
	ResetWaveStats(client);
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
			g_iRobotDamage[attacker] += damage;
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
			g_iTankDamage[attacker] += damage;
		}
	}
}

public void Event_PickupCurrency(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	
	if (TF2_GetClientTeam(client) == TFTeam_Red)
	{
		int credits = event.GetInt("currency");
		g_iCashMoney[client] += credits;
	}
}

public void Event_PowerupBottle(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	
	if (TF2_GetClientTeam(client) == TFTeam_Red)
		g_iCanteenUse[client]++;
}

public void Event_FlagObjective(Event event, const char[] name, bool dontBroadcast)
{
	int client = event.GetInt("player");
	int eventType = event.GetInt("eventtype");
	
	if (eventType == TF_FLAGEVENT_DEFENDED && TF2_GetClientTeam(client) == TFTeam_Red)
		g_iFlagDefend[client]++;
}

public void Event_WaveComplete(Event event, const char[] name, bool dontBroadcast)
{
	UpdateWaveStatsMenu();
	g_bHasWaveBegun = true;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			DisplayMenu(g_hWaveStatsMenu, i, STATS_DISPLAY_TIME);
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
			g_iRobotKills[attacker]++;
		}
	}
}

public void Event_RoundWin(Event event, const char[] name, bool dontBroadcast)
{
	UpdateWaveStatsMenu();
	g_bHasWaveBegun = true;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			DisplayMenu(g_hWaveStatsMenu, i, STATS_DISPLAY_TIME);
}

public void Event_HeadshotCurrency(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (TF2_GetClientTeam(client) == TFTeam_Red)
	{
		int credits = event.GetInt("currency");
		g_iCashMoney[client] += credits;
	}
}

public void Event_BeginWave_Time(Event event, const char[] name, bool dontBroadcast)
{
	int resource = FindEntityByClassname(-1, "tf_objective_resource");
	g_iLastWaveNumber = TF2_GetMannVsMachineWaveCount(resource);
	g_flWaveStartTime = GetGameTime();

	if (mvmwavestats_write_wave_time.BoolValue)
		g_hWaveTimeTimer = CreateTimer(60.0, Timer_UpdateMissionProgressTime, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_WaveComplete_Time(Event event, const char[] name, bool dontBroadcast)
{
	g_bWavePassed[g_iLastWaveNumber] = true;
	g_flWaveTimes[g_iLastWaveNumber] = GetGameTime() - g_flWaveStartTime;
	g_flWavesTotalTime += GetGameTime() - g_flWaveStartTime;
	g_iLastWaveNumber = 0;

	if (mvmwavestats_write_wave_time.BoolValue)
		DisplayWaveTimes();
		
	if (g_hWaveTimeTimer != null)
	{
		CloseHandle(g_hWaveTimeTimer);
		g_hWaveTimeTimer = null;
	}
}


public void Event_WaveFail_Time(Event event, const char[] name, bool dontBroadcast)
{
	g_iFailCounterTick++;
	if (g_iFailCounterTick > 3)
		MissionRestarted();

	CreateTimer(0.00, Timer_ResetFailCounter, 0);

	if (g_iLastWaveNumber != 0)
	{
		g_flWaveTimes[g_iLastWaveNumber] = GetGameTime() - g_flWaveStartTime;
		g_flWavesTotalTime += GetGameTime() - g_flWaveStartTime;

		if (mvmwavestats_write_wave_time.BoolValue)
			DisplayWaveTimes();
	}
	
	g_iLastWaveNumber = 0;
	
	if (g_hWaveTimeTimer != null)
	{
		delete g_hWaveTimeTimer;
		g_hWaveTimeTimer = null;
	}
}

public void Event_MissionComplete_Time(Event event, const char[] name, bool dontBroadcast)
{
	// PrintToServer("Mission complete");
	// PrintToChatAll("Mission complete");

	if (mvmwavestats_write_wave_time.BoolValue)
		DisplayWaveTimesTotal();

	ResetTimeStats();
}

public void Event_RestartRound_Time(Event event, const char[] name, bool dontBroadcast)
{
	if (g_hWaveTimeTimer != null)
	{
		CloseHandle(g_hWaveTimeTimer);
		g_hWaveTimeTimer = null;
	}
}

public Action Timer_ResetFailCounter(Handle timer, any value)
{
	g_iFailCounterTick = 0;
	return Plugin_Stop;
}

public Action Timer_UpdateMissionProgressTime(Handle timer, any value)
{
	DisplayCurrentWaveTime();
	return Plugin_Continue;
}

void ResetWaveStats(int client)
{
	g_iRobotKills[client] = 0;
	g_iRobotDamage[client] = 0;
	g_iTankDamage[client] = 0;
	g_iCashMoney[client] = 0;
	g_iCanteenUse[client] = 0;
	g_iFlagDefend[client] = 0;
	// bombReset[client] = 0;
}

void ResetTimeStats()
{
	for (int i = 0; i < MVM_MAX_WAVE_NUMBERS; i++)
	{
		g_flWaveTimes[i] = 0.0;
		g_bWavePassed[i] = false;
	}
	
	g_flWaveStartTime = 0.0;
	g_flWavesTotalTime = 0.0;
	g_iLastWaveNumber = 0;
}

void DisplayCurrentWaveTime()
{
	if (g_iLastWaveNumber == 0)
		return;
	
	char timestr[64];
	WriteTime(GetGameTime() - g_flWaveStartTime, timestr, 64);
	CPrintToChatAll("\x07%sTime spent on Wave %d:\x07%s %s", g_sWaveTimeTextColor1, g_iLastWaveNumber, g_sWaveTimeTextColor2, timestr);
}

float GetWaveSuccessTime()
{
	float success_time = 0.0;

	for (int i = 0; i < sizeof(g_bWavePassed); i++)
	{
		if (g_bWavePassed[i])
			success_time += g_flWaveTimes[i];
	}
	
	return success_time;
}

static int m_iLastWaveDisplayTick;
void DisplayWaveTimes()
{
	if (m_iLastWaveDisplayTick == GetGameTickCount())
		return;

	char timestr[64];
	
	if (g_iLastWaveNumber != 0)
	{
		WriteTime(g_flWaveTimes[g_iLastWaveNumber], timestr, 64);
		CPrintToChatAll("\x07%sTime spent on Wave %d:\x07%s %s", g_sWaveTimeTextColor1, g_iLastWaveNumber, g_sWaveTimeTextColor2, timestr);
	}

	WriteTime(GetWaveSuccessTime(), timestr, 64);
	CPrintToChatAll("\x07%sTotal success time spent:\x07%s %s", g_sWaveTimeTextColor1, g_sWaveTimeTextColor2, timestr);
	WriteTime(g_flWavesTotalTime, timestr, 64);
	CPrintToChatAll("\x07%sTotal time spent:\x07%s %s", g_sWaveTimeTextColor1, g_sWaveTimeTextColor2, timestr);
	m_iLastWaveDisplayTick = GetGameTickCount();
}

void DisplayWaveTimesTotal(int client = 0)
{
	int resource = FindEntityByClassname(-1,"tf_objective_resource");
	int max_wave = TF2_GetMannVsMachineMaxWaveCount(resource);

	char timestr[64];
	char strprint[256];
	
	for (int i = 1; i <= max_wave; i++)
	{
		WriteTime(g_flWaveTimes[i], timestr, 64);
		Format(strprint, 256, "\x07%s[Wave %d] Time spent:\x07%s %s", g_sWaveTimeTextColor1, i, g_sWaveTimeTextColor2, timestr);
		
		if (g_bWavePassed[i])
			Format(strprint, 256, "%s %s", strprint, "\x077FFF8E(Success)");
		else if (g_flWaveTimes[i] > 0)
			Format(strprint, 256,"%s %s", strprint, "\x07FF5661(Fail)");
		else
			Format(strprint, 256, "%s %s", strprint, "\x07FFF47F(Not played)");
		
		if (client == 0)
			CPrintToChatAll(strprint);
		else
			CPrintToChat(client, strprint);
	}

	WriteTime(g_flWaveTimes[g_iLastWaveNumber], timestr, 64);
	CPrintToChatAll("\x07%sTime spent on Wave %d:\x07%s %s", g_sWaveTimeTextColor1, g_iLastWaveNumber, g_sWaveTimeTextColor2, timestr);
	WriteTime(GetWaveSuccessTime(), timestr, 64);
	CPrintToChatAll("\x07%sTotal success time spent:\x07%s %s", g_sWaveTimeTextColor1, g_sWaveTimeTextColor2, timestr);
	WriteTime(g_flWavesTotalTime, timestr, 64);
	CPrintToChatAll("\x07%sTotal time spent:\x07%s %s", g_sWaveTimeTextColor1, g_sWaveTimeTextColor2, timestr);
}

void MissionRestarted()
{
	ResetTimeStats();
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
		TF2_GetMvMPopfileName(objRsrc, missionName, sizeof(missionName));
		ReplaceString(missionName, sizeof(missionName), "scripts/population/", "");
		ReplaceString(missionName, sizeof(missionName), ".pop", "");
	}
	else
		LogError("COULD NOT LOCATE ENTITY tf_objective_resource!");
	
	return missionName;
}

//Thanks rafradek
stock void WriteTime(float time, char[] str, int maxlen)
{
	int timeint = RoundToFloor(time);
	
	if (timeint / 3600 > 0)
		Format(str, maxlen, "%d h %d min %d sec", timeint / 3600, (timeint / 60) % 60, (timeint) % 60);
	else if (timeint / 60 > 0)
		Format(str, maxlen, "%d min %d sec", (timeint / 60) % 60, (timeint) % 60);
	else
		Format(str, maxlen, "%d sec", (timeint) % 60);
}