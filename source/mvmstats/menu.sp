Handle g_hWaveStatsMenu;
Handle g_hWaveStatsMenu_RobotKills;
Handle g_hWaveStatsMenu_Damage;
Handle g_hWaveStatsMenu_DamageTank;
Handle g_hWaveStatsMenu_Credits;
Handle g_hWaveStatsMenu_Canteens;
Handle g_hWaveStatsMenu_FlagDefend;
// Handle WaveStatsMenu_BombReset;

void CreateWaveStatsMenu()
{
	delete g_hWaveStatsMenu;
	
	g_hWaveStatsMenu = CreateMenu(Handler_WaveStatsMenu);
	// SetMenuTitle(g_hWaveStatsMenu, "[MvM Wave Statistics]");
	AddMenuItem(g_hWaveStatsMenu, "0", "Robots Killed");
	AddMenuItem(g_hWaveStatsMenu, "1", "Robot Damage");
	AddMenuItem(g_hWaveStatsMenu, "2", "Tank Damage");
	AddMenuItem(g_hWaveStatsMenu, "3", "Money Collected");
	AddMenuItem(g_hWaveStatsMenu, "4", "Canteens Used");
	AddMenuItem(g_hWaveStatsMenu, "5", "Bombs Defended");
	// AddMenuItem(g_hWaveStatsMenu, "5", "Bombs Reset");
}

void UpdateWaveStatsMenu()
{
	int rsrc = FindEntityByClassname(-1, "tf_objective_resource");
	
	if (rsrc != -1)
	{
		int currentWave = TF2_GetMannVsMachineWaveCount(rsrc);
		char missionName[PLATFORM_MAX_PATH]; TF2_GetMvMPopfileName(rsrc, missionName, sizeof(missionName));
		
		//Trim the extras
		ReplaceString(missionName, sizeof(missionName), "scripts/population/", "");
		ReplaceString(missionName, sizeof(missionName), ".pop", "");
		
		//Update title with current wave number
		SetMenuTitle(g_hWaveStatsMenu, "[MvM Wave Statistics]\n%s\nWave %d", missionName, currentWave);
	}
	
	delete g_hWaveStatsMenu_RobotKills;
	delete g_hWaveStatsMenu_Damage;
	delete g_hWaveStatsMenu_DamageTank;
	delete g_hWaveStatsMenu_Credits;
	delete g_hWaveStatsMenu_Canteens;
	delete g_hWaveStatsMenu_FlagDefend;
	
	g_hWaveStatsMenu_RobotKills = CreateMenu(Handler_WaveStatsMenu_ALL);
	g_hWaveStatsMenu_Damage = CreateMenu(Handler_WaveStatsMenu_ALL);
	g_hWaveStatsMenu_DamageTank = CreateMenu(Handler_WaveStatsMenu_ALL);
	g_hWaveStatsMenu_Credits = CreateMenu(Handler_WaveStatsMenu_ALL);
	g_hWaveStatsMenu_Canteens = CreateMenu(Handler_WaveStatsMenu_ALL);
	g_hWaveStatsMenu_FlagDefend = CreateMenu(Handler_WaveStatsMenu_ALL);
	
	SetMenuTitle(g_hWaveStatsMenu_RobotKills, "Robots Killed");
	SetMenuTitle(g_hWaveStatsMenu_Damage, "Damage");
	SetMenuTitle(g_hWaveStatsMenu_DamageTank, "Tank Damage");
	SetMenuTitle(g_hWaveStatsMenu_Credits, "Money Collected");
	SetMenuTitle(g_hWaveStatsMenu_Canteens, "Canteens Used");
	SetMenuTitle(g_hWaveStatsMenu_FlagDefend, "Bombs Defended");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Red && !TF2_IsPlayerInCondition(i, TFCond_Reprogrammed))
		{
			char displayBuffer[256];
			
			Format(displayBuffer, sizeof(displayBuffer), "%N (%s): %d", i, NamePlayerClass(i), g_iRobotKills[i]);
			AddMenuItem(g_hWaveStatsMenu_RobotKills, "0", displayBuffer, ITEMDRAW_DISABLED);
			
			Format(displayBuffer, sizeof(displayBuffer), "%N (%s): %d", i, NamePlayerClass(i), g_iRobotDamage[i]);
			AddMenuItem(g_hWaveStatsMenu_Damage, "0", displayBuffer, ITEMDRAW_DISABLED);
			
			Format(displayBuffer, sizeof(displayBuffer), "%N (%s): %d", i, NamePlayerClass(i), g_iTankDamage[i]);
			AddMenuItem(g_hWaveStatsMenu_DamageTank, "0", displayBuffer, ITEMDRAW_DISABLED);
			
			Format(displayBuffer, sizeof(displayBuffer), "%N (%s): %d", i, NamePlayerClass(i), g_iCashMoney[i]);
			AddMenuItem(g_hWaveStatsMenu_Credits, "0", displayBuffer, ITEMDRAW_DISABLED);
			
			Format(displayBuffer, sizeof(displayBuffer), "%N (%s): %d", i, NamePlayerClass(i), g_iCanteenUse[i]);
			AddMenuItem(g_hWaveStatsMenu_Canteens, "0", displayBuffer, ITEMDRAW_DISABLED);
			
			Format(displayBuffer, sizeof(displayBuffer), "%N (%s): %d", i, NamePlayerClass(i), g_iFlagDefend[i]);
			AddMenuItem(g_hWaveStatsMenu_FlagDefend, "0", displayBuffer, ITEMDRAW_DISABLED);
		}
	}
}

public int Handler_WaveStatsMenu(Handle menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_Select)
	{
		switch(slot)
		{
			case 0: DisplayMenu(g_hWaveStatsMenu_RobotKills, client, MENU_TIME_FOREVER);
			case 1: DisplayMenu(g_hWaveStatsMenu_Damage, client, MENU_TIME_FOREVER);
			case 2: DisplayMenu(g_hWaveStatsMenu_DamageTank, client, MENU_TIME_FOREVER);
			case 3: DisplayMenu(g_hWaveStatsMenu_Credits, client, MENU_TIME_FOREVER);
			case 4: DisplayMenu(g_hWaveStatsMenu_Canteens, client, MENU_TIME_FOREVER);
			case 5: DisplayMenu(g_hWaveStatsMenu_FlagDefend, client, MENU_TIME_FOREVER);
			// case 5: DisplayMenu(WaveStatsMenu_BombReset, client, MENU_TIME_FOREVER);
		}
	}
	else if (action == MenuAction_Cancel && IsClientInGame(client))
	{
		CPrintToChat(client, "%s {default}Type {unique}!wavestats{default} to bring up this menu again.", PLUGIN_PREFIX);
	}
	
	return 0;
}

//Used for each stat-specific menu to just go back to the main
public int Handler_WaveStatsMenu_ALL(Handle menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_Cancel)
		DisplayMenu(g_hWaveStatsMenu, client, MENU_TIME_FOREVER);
	
	return 0;
}