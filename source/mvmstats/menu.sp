Handle WaveStatsMenu;
Handle WaveStatsMenu_RobotKills;
Handle WaveStatsMenu_Damage;
Handle WaveStatsMenu_DamageTank;
Handle WaveStatsMenu_Credits;
Handle WaveStatsMenu_Canteens;
Handle WaveStatsMenu_FlagDefend;
// Handle WaveStatsMenu_BombReset;

void CreateWaveStatsMenu()
{
	WaveStatsMenu = CreateMenu(Handler_WaveStatsMenu);
	// SetMenuTitle(WaveStatsMenu, "[MvM Wave Statistics]");
	AddMenuItem(WaveStatsMenu, "0", "Robots Killed");
	AddMenuItem(WaveStatsMenu, "1", "Robot Damage");
	AddMenuItem(WaveStatsMenu, "2", "Tank Damage");
	AddMenuItem(WaveStatsMenu, "3", "Money Collected");
	AddMenuItem(WaveStatsMenu, "4", "Canteens Used");
	AddMenuItem(WaveStatsMenu, "5", "Bombs Defended");
	// AddMenuItem(WaveStatsMenu, "5", "Bombs Reset");
}

void UpdateWaveStatsMenu()
{
	SetMenuTitle(WaveStatsMenu, "[MvM Wave Statistics]\n%s\nWave %d", GetMissionName(), currentWave); //update wave index
	
	delete WaveStatsMenu_RobotKills;
	delete WaveStatsMenu_Damage;
	delete WaveStatsMenu_DamageTank;
	delete WaveStatsMenu_Credits;
	delete WaveStatsMenu_Canteens;
	delete WaveStatsMenu_FlagDefend;
	
	WaveStatsMenu_RobotKills = CreateMenu(Handler_WaveStatsMenu_ALL);
	WaveStatsMenu_Damage = CreateMenu(Handler_WaveStatsMenu_ALL);
	WaveStatsMenu_DamageTank = CreateMenu(Handler_WaveStatsMenu_ALL);
	WaveStatsMenu_Credits = CreateMenu(Handler_WaveStatsMenu_ALL);
	WaveStatsMenu_Canteens = CreateMenu(Handler_WaveStatsMenu_ALL);
	WaveStatsMenu_FlagDefend = CreateMenu(Handler_WaveStatsMenu_ALL);
	
	SetMenuTitle(WaveStatsMenu_RobotKills, "Robots Killed");
	SetMenuTitle(WaveStatsMenu_Damage, "Damage");
	SetMenuTitle(WaveStatsMenu_DamageTank, "Tank Damage");
	SetMenuTitle(WaveStatsMenu_Credits, "Money Collected");
	SetMenuTitle(WaveStatsMenu_Canteens, "Canteens Used");
	SetMenuTitle(WaveStatsMenu_FlagDefend, "Bombs Defended");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Red)
		{
			char displayBuffer[256];
			
			Format(displayBuffer, sizeof(displayBuffer), "%N (%s): %d", i, NamePlayerClass(i), robotKills[i]);
			AddMenuItem(WaveStatsMenu_RobotKills, "0", displayBuffer, ITEMDRAW_DISABLED);
			
			Format(displayBuffer, sizeof(displayBuffer), "%N (%s): %d", i, NamePlayerClass(i), robotDamage[i]);
			AddMenuItem(WaveStatsMenu_Damage, "0", displayBuffer, ITEMDRAW_DISABLED);
			
			Format(displayBuffer, sizeof(displayBuffer), "%N (%s): %d", i, NamePlayerClass(i), tankDamage[i]);
			AddMenuItem(WaveStatsMenu_DamageTank, "0", displayBuffer, ITEMDRAW_DISABLED);
			
			Format(displayBuffer, sizeof(displayBuffer), "%N (%s): %d", i, NamePlayerClass(i), cashMoney[i]);
			AddMenuItem(WaveStatsMenu_Credits, "0", displayBuffer, ITEMDRAW_DISABLED);
			
			Format(displayBuffer, sizeof(displayBuffer), "%N (%s): %d", i, NamePlayerClass(i), canteenUse[i]);
			AddMenuItem(WaveStatsMenu_Canteens, "0", displayBuffer, ITEMDRAW_DISABLED);
			
			Format(displayBuffer, sizeof(displayBuffer), "%N (%s): %d", i, NamePlayerClass(i), flagDefend[i]);
			AddMenuItem(WaveStatsMenu_FlagDefend, "0", displayBuffer, ITEMDRAW_DISABLED);
		}
	}
}

public int Handler_WaveStatsMenu(Handle menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_Select)
	{
		switch(slot)
		{
			case 0: DisplayMenu(WaveStatsMenu_RobotKills, client, MENU_TIME_FOREVER);
			case 1: DisplayMenu(WaveStatsMenu_Damage, client, MENU_TIME_FOREVER);
			case 2: DisplayMenu(WaveStatsMenu_DamageTank, client, MENU_TIME_FOREVER);
			case 3: DisplayMenu(WaveStatsMenu_Credits, client, MENU_TIME_FOREVER);
			case 4: DisplayMenu(WaveStatsMenu_Canteens, client, MENU_TIME_FOREVER);
			case 5: DisplayMenu(WaveStatsMenu_FlagDefend, client, MENU_TIME_FOREVER);
			// case 5: DisplayMenu(WaveStatsMenu_BombReset, client, MENU_TIME_FOREVER);
		}
	}
	else if (action == MenuAction_Cancel && IsClientInGame(client))
		CPrintToChat(client, "[{unique}MvMStats{default}] Type {unique}!wavestats{default} to bring up this menu again.");
}

public int Handler_WaveStatsMenu_ALL(Handle menu, MenuAction action, int client, int slot)
{
	if (action == MenuAction_Cancel)
		DisplayMenu(WaveStatsMenu, client, MENU_TIME_FOREVER);
}