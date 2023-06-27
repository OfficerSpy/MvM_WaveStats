#include <sourcemod>
#include <tf2_stocks>
#include <multicolors>

#define PLUGIN_PREFIX	"{unique}[MvMStats]"
#define STATS_DISPLAY_TIME	15
#define MVM_MAX_WAVE_NUMBERS	64

bool hasWaveBegun;

//Time stats
float wave_times[MVM_MAX_WAVE_NUMBERS];
bool wave_passed[MVM_MAX_WAVE_NUMBERS];
float wave_start_time = 0.0;
float waves_total_time = 0.0;
int last_wave_number = 0;
int fail_counter_tick = 0;
Handle wave_time_timer = null;

int robotKills[MAXPLAYERS + 1];
int robotDamage[MAXPLAYERS + 1];
int tankDamage[MAXPLAYERS + 1];
int cashMoney[MAXPLAYERS + 1];
int canteenUse[MAXPLAYERS + 1];
int flagDefend[MAXPLAYERS + 1];
// int bombReset[MAXPLAYERS + 1];
//TODO: track how much healing was done

ConVar write_wave_time_enabled;

#include "mvmstats/menu.sp"

public Plugin myinfo =
{
	name = "[TF2] MvM Wave Statistics",
	author = "Officer Spy",
	description = "Reports details about a game after a wave has ended.",
	version = "1.0.5",
	url = ""
};

public void OnPluginStart()
{
	write_wave_time_enabled = CreateConVar("sm_write_wave_time", "1", "write wave time in client chat");
	
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

public Action Command_WaveTime(int client, int args)
{
	DisplayWaveTimesTotal(client);
	return Plugin_Handled;
}

public void OnMapStart()
{
	CreateWaveStatsMenu();
	hasWaveBegun = false;
	ResetTimeStats();
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

public void Event_BeginWave_Time(Event event, const char[] name, bool dontBroadcast)
{
	int resource = FindEntityByClassname(-1, "tf_objective_resource");
	last_wave_number = GetEntProp(resource, Prop_Send, "m_nMannVsMachineWaveCount");
	wave_start_time = GetGameTime();

	if (write_wave_time_enabled.BoolValue)
		wave_time_timer = CreateTimer(60.0, Timer_UpdateMissionProgressTime, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_WaveComplete_Time(Event event, const char[] name, bool dontBroadcast)
{
	wave_passed[last_wave_number] = true;
	wave_times[last_wave_number] = GetGameTime() - wave_start_time;
	waves_total_time += GetGameTime() - wave_start_time;
	last_wave_number = 0;

	if (write_wave_time_enabled.BoolValue)
		DisplayWaveTimes();
		
	if (wave_time_timer != null)
	{
		CloseHandle(wave_time_timer);
		wave_time_timer = null;
	}
}


public void Event_WaveFail_Time(Event event, const char[] name, bool dontBroadcast)
{
	fail_counter_tick++;
	if (fail_counter_tick > 3)
		MissionRestarted();

	CreateTimer(0.00, Timer_ResetFailCounter, 0);

	if (last_wave_number != 0)
	{
		wave_times[last_wave_number] = GetGameTime() - wave_start_time;
		waves_total_time += GetGameTime() - wave_start_time;

		if (write_wave_time_enabled.BoolValue)
			DisplayWaveTimes();
	}
	
	last_wave_number = 0;
	if (wave_time_timer != null)
	{
		delete wave_time_timer;
		wave_time_timer = null;
	}
}

public void Event_MissionComplete_Time(Event event, const char[] name, bool dontBroadcast)
{
	// PrintToServer("Mission complete");
	// PrintToChatAll("Mission complete");

	if (write_wave_time_enabled.BoolValue)
		DisplayWaveTimesTotal(0);

	ResetTimeStats();
}

public void Event_RestartRound_Time(Event event, const char[] name, bool dontBroadcast)
{
	if (wave_time_timer != null)
	{
		CloseHandle(wave_time_timer);
		wave_time_timer = null;
	}
}

public Action Timer_ResetFailCounter(Handle timer, any value)
{
	fail_counter_tick = 0;
	return Plugin_Stop;
}

public Action Timer_UpdateMissionProgressTime(Handle timer, any value)
{
	DisplayCurrentWaveTime();
	return Plugin_Continue;
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

void ResetTimeStats()
{
	for (int i = 0; i < MVM_MAX_WAVE_NUMBERS; i++)
	{
		wave_times[i] = 0.0;
		wave_passed[i] = false;
	}
	
	wave_start_time = 0.0;
	waves_total_time = 0.0;
	last_wave_number = 0;
}

void DisplayCurrentWaveTime()
{
	if (last_wave_number == 0)
		return;
	
	char timestr[64];
	WriteTime(GetGameTime() - wave_start_time, timestr, 64);
	CPrintToChatAll("{aqua}Time spent on Wave %d:\x07FFD800 %s", last_wave_number, timestr);
}

float GetWaveSuccessTime()
{
	float success_time = 0.0;

	for (int i = 0; i < sizeof(wave_passed); i++)
	{
		if (wave_passed[i])
			success_time += wave_times[i];
	}
	
	return success_time;
}

int last_wave_display_tick;
void DisplayWaveTimes()
{
	if (last_wave_display_tick == GetGameTickCount())
		return;

	char timestr[64];
	if (last_wave_number != 0)
	{
		WriteTime(wave_times[last_wave_number], timestr, 64);
		CPrintToChatAll("{aqua}Time spent on Wave %d:\x07FFD800 %s", last_wave_number, timestr);
	}

	WriteTime(GetWaveSuccessTime(), timestr, 64);
	CPrintToChatAll("{aqua}Total success time spent:\x07FFD800 %s", timestr);
	WriteTime(waves_total_time, timestr, 64);
	CPrintToChatAll("{aqua}Total time spent:\x07FFD800 %s", timestr);
	last_wave_display_tick = GetGameTickCount();
}

void DisplayWaveTimesTotal(int client)
{
	int resource = FindEntityByClassname(-1,"tf_objective_resource");
	int max_wave = GetEntProp(resource, Prop_Send,"m_nMannVsMachineMaxWaveCount");

	char timestr[64];
	char strprint[256];
	
	for (int i = 1; i <= max_wave; i++)
	{
		WriteTime(wave_times[i], timestr, 64);
		Format(strprint,256,"{aqua}[Wave %d] Time spent:\x07FFD800 %s", i, timestr);
		
		if (wave_passed[i])
			Format(strprint,256,"%s %s", strprint, "\x077FFF8E(Success)");
		else if(wave_times[i] > 0)
			Format(strprint,256,"%s %s", strprint, "\x07FF5661(Fail)");
		else
			Format(strprint, 256, "%s %s", strprint, "\x07FFF47F(Not played)");
		
		if (client == 0)
			CPrintToChatAll(strprint);
		else
			CPrintToChat(client, strprint);
	}

	WriteTime(wave_times[last_wave_number], timestr, 64);
	CPrintToChatAll("{aqua}Time spent on Wave %d:\x07FFD800 %s", last_wave_number, timestr);
	WriteTime(GetWaveSuccessTime(), timestr, 64);
	CPrintToChatAll("{aqua}Total success time spent:\x07FFD800 %s", timestr);
	WriteTime(waves_total_time, timestr, 64);
	CPrintToChatAll("{aqua}Total time spent:\x07FFD800 %s", timestr);
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
		GetEntPropString(objRsrc, Prop_Send, "m_iszMvMPopfileName", missionName, sizeof(missionName));
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