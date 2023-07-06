/*====================================================
1.0
	- Initial release
======================================================*/
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>
#include <IA>
#include <IA_l4d2/stock>
#include <IA_l4d2/weapon>

#define LINUX	0
#define WIN		1

DynamicHook hHook_SelectWeightedSequence, hHook_SendWeaponAnim, hWeaponHolster, hHook_PrimaryAttack
KeyValues hWeaponData, hActivityList
Handle hGetWeaponInfoByID
int iOS, EntStore[2049], onbutton[33]
bool bZoom[33], ads_holding_key
float ads_recoil_modifier, ads_spread_modifier, ads_pellet_scatter_modifier

public Plugin myinfo=
{
	name = "Weapon System",
	author = "IA/NanaNana",
	description = "Make the mp_restartgame and restart scenario from vote no longer change map to first map of scenario",
	version = "1.1",
	url = "https://github.com/IA-NanaNana/l4d2-aim-down-sight"
}

public void OnPluginStart()
{
	GameData a = new GameData("l4d2_weapon_system")
	
	if(!a)
		SetFailState( "Can't load gamedata \"l4d2_weapon_system.txt\" or not found" )
	
	iOS = a.GetOffset("Os")
	
	hHook_SelectWeightedSequence = DHookCreate(208-iOS, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity)
	hHook_SelectWeightedSequence.AddParam(HookParamType_Int);
	
	hHook_SendWeaponAnim = DHookCreate(252-iOS, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity)
	hHook_SendWeaponAnim.AddParam(HookParamType_Int);
	
	hWeaponHolster = DHookCreate(266-iOS, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity)
	DHookAddParam(hWeaponHolster, HookParamType_CBaseEntity);
	
	hHook_PrimaryAttack = DHookCreate(283-iOS, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity)
	/*DynamicDetour z = new DynamicDetour(Address_Null, CallConv_THISCALL, ReturnType_Int, ThisPointer_CBaseEntity)
	if(!DHookSetFromConf(z, a, SDKConf_Signature, "SelectHeaviestSequence"))
		SetFailState( "[IA] Detour SelectHeaviestSequence invalid." )
	z.AddParam(HookParamType_Int);
	z.Enable(Hook_Pre, DH_SelectHeaviestSequence)*/
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(a, SDKConf_Signature, "GetWeaponInfo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if(!(hGetWeaponInfoByID = EndPrepSDKCall()))
		SetFailState( "Can't find signature \"GetWeaponInfo\"." )
	
	RegServerCmd("ws_reload", IA_ServerCmd);
	IA_ServerCmd(0)
	
	HookEvent("weapon_zoom", weapon_zoom);
	HookEvent("weapon_drop", weapon_drop);
	HookEvent("weapon_fire", weapon_fire);
	
	a.Close()
	
	hActivityList = new KeyValues("")
	char s[128]
	BuildPath(Path_SM, s, sizeof s, "data/left4dhooks.l4d2.cfg")
	hActivityList.ImportFromFile(s)
	
	CreateConVarEx("ads_holding_key", "0", LoadConVar, "Enable in ads by holding the zoom key.");
	CreateConVarEx("ads_recoil_modifier", "0.5", LoadConVar, "Recoil modifier while in ads.");
	CreateConVarEx("ads_spread_modifier", "0.1", LoadConVar, "Spread modifier while in ads.");
	CreateConVarEx("ads_pellet_scatter_modifier", "0.5", LoadConVar, "Pellet scatter modifier while in ads.");
	LoadConVar(null, "", "")
	AutoExecConfig(true, "l4d2_aim_down_sight")
}

LoadConVar(Handle:cvar, const String:o[], const String:n[])
{
	ads_recoil_modifier = GetConVarFloat(FindConVar("ads_recoil_modifier"))
	ads_spread_modifier = GetConVarFloat(FindConVar("ads_spread_modifier"))
	ads_pellet_scatter_modifier = GetConVarFloat(FindConVar("ads_pellet_scatter_modifier"))
	ads_holding_key = GetConVarBool(FindConVar("ads_holding_key"))
}

Action IA_ServerCmd(args)
{
	if(hWeaponData) hWeaponData.Close()
	hWeaponData = new KeyValues("")
	char s[128]
	BuildPath(Path_SM, s, sizeof s, "data/weapon_system.txt")
	hWeaponData.ImportFromFile(s)
	return Plugin_Handled
}

public OnEntityCreated(a, const String:n[])
{
	if(n[0] && !StrContains(n, "weapon_") && StrContains(n, "spawn") == -1)
	{
		hHook_SelectWeightedSequence.HookEntity(Hook_Pre, a, DH_OnSelectWeightedSequence)
		// hHook_SendWeaponAnim.HookEntity(Hook_Pre, a, DH_OnSendWeaponAnim)
		// hHook_SendWeaponAnim.HookEntity(Hook_Post, a, DH_OnSendWeaponAnimPost)
		SDKHook(a, SDKHook_Reload, OnCustomWeaponReload);
		hWeaponHolster.HookEntity(Hook_Post, a, DH_OnGunHolsterPost)
		hHook_PrimaryAttack.HookEntity(Hook_Post, a, DH_PrimaryAttackPost)
		EntStore[a] = 0
	}
}
public MRESReturn DH_OnGunHolsterPost(int b, Handle hParams)
{
	bZoom[GetWeaponOwner(b)] = false
	return MRES_Ignored
}

public OnPlayerRunCmdPost(a, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if(!IsClientInGame(a) || GetClientTeam(a) != 2 || IsFakeClient(a)) return
	if(buttons &IN_ZOOM)
	{
		if(!(onbutton[a]&IN_ZOOM))
		{
			onbutton[a] |= IN_ZOOM
			int w = GetPlayerWeapon(a)
			if(w != -1 && !CanZoom(w)) SetupZoom(a, w, !bZoom[a])
		}
	}
	else if(onbutton[a]&IN_ZOOM)
	{
		onbutton[a] &=~IN_ZOOM
		if(ads_holding_key && bZoom[a]) SetupZoom(a, GetPlayerWeapon(a), false)
	}
}
stock bool CanZoom(w)
{
	char s[40]
	GetEntityClassname(w, s, 40)
	return !StrContains(s[7], "sniper") || !StrContains(s[7], "hunting") || !StrContains(s[13], "sg552") 
}

SetupZoom(a, w, bool b)
{
	int i = SelectWeightedSequence(w, b ? ACT_PRIMARY_VM_IDLE : ACT_VM_IDLE)
	if(i == -1) return
	bZoom[a] = b
	if(GetGameTime() > GS_WeaponNextAttackTime(w)) SendWeaponAnim(w, b?ACT_PRIMARY_VM_IDLE_TO_LOWERED:ACT_PRIMARY_VM_LOWERED_TO_IDLE)
	SetEntProp(GetEntPropEnt(a, Prop_Send, "m_hViewModel"), Prop_Data, "m_nSequence", i)
	SetWeaponHelpingHandState(w, b?6:0)
}

/*SetViewModelIdleAnim(a, w)
{
	if((w = SelectWeightedSequence(w, bZoom[a] ? ACT_PRIMARY_VM_IDLE : ACT_VM_IDLE)) != -1) SetEntProp(GetEntPropEnt(a, Prop_Send, "m_hViewModel"), Prop_Data, "m_nSequence", w)
}*/

Action OnCustomWeaponReload(b)
{
	if(GetWeaponClip(b) >= GetWeaponGunClipSize(b))
	{
		switch(GetEntProp(b, Prop_Data, "m_IdealActivity", 2))
		{
			case ACT_VM_FIDGET: return Plugin_Handled
			case ACT_VM_IDLE:
			{
				int a = GetWeaponOwner(b)
				if(!bZoom[a] && SendWeaponAnim(b, ACT_VM_FIDGET))
				{
					return Plugin_Handled
				}
			}
		}
	}
	return Plugin_Continue
}

int GetWeaponGunClipSize(a)
{
	static Handle hGetMaxClip1
	if(!hGetMaxClip1)
	{
		StartPrepSDKCall(SDKCall_Entity)
		PrepSDKCall_SetVirtual(324-iOS)
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain)
		hGetMaxClip1 = EndPrepSDKCall()
	}
	return SDKCall(hGetMaxClip1, a)
}
// MRESReturn DH_OnSendWeaponAnim(int b, Handle hReturn, Handle hParam)
// {
	// if(DHookGetParam(hParam, 1) == 191)
	// {
		// PrintToChatAll("Block")
		// DHookSetReturn(hReturn, false)
		// return MRES_Supercede
	// }
	// int i = DHookGetParam(hParam, 1), l = i
	// switch(l)
	// {
		// case 183:
		// {
			// if(bZoom[GetWeaponOwner(b)]) l = ACT_PRIMARY_VM_IDLE
		// }
		// case 193, 1403:
		// {
			// if(!GetWeaponClip(b)) l = 180
		// }
		// case 191:
		// {
			// if(bZoom[GetWeaponOwner(b)]) l = ACT_PRIMARY_VM_PRIMARYATTACK
		// }
		// case 179:
		// {
			// if(!EntStore[b] && GetWeaponClip(b)) l = ACT_VM_DRAW, EntStore[b] = 1
		// }
		// // case 1419:
		// // {
			// // if(bIA_real_reload && !bReloadFromEmty[GetWeaponOwner(b)] && GetWeaponAttributeEx(b, IWEA_Loading))
			// // {
				// // i = ACT_VM_RELOAD_END_NOEMPTY
				// // /*int i = 1
				// // if(IsCustomWeapon(b)) i = hCustomWeapon.GetNum("ShotgunRealReloadEndAnim", 1)
				// // SetLayerSequence(GetEntPropEnt(a, Prop_Send, "m_hViewModel"), i)*/
				// // // SetEntPropFloat(b, Prop_Send, "m_flTimeWeaponIdle", 1.0)
				// // // InitHandle(hSoundData[a])//SetEntPropFloat(GetEntPropEnt(a, Prop_Send, "m_hViewModel"), Prop_Send, "m_flLayerStartTime", 0.0)
				// // //DHookSetParam(hParams, 1, 183)
				// // //return MRES_ChangedHandled
			// // }
		// // }
	// }
	// if(l != i && (l = SelectWeightedSequence(b, l)) != -1)
	// {
		// DHookSetParam(hParam, 1, l)
		// return MRES_ChangedHandled
	// }
	// return MRES_Ignored
// }
// MRESReturn DH_OnSendWeaponAnimPost(int b, Handle hReturn, Handle hParam)
// {
	// /*if(DHookGetParam(hParam, 1) == 191)
	// {
		// PrintToChatAll("Block")
		// DHookSetReturn(hReturn, false)
		// return MRES_Supercede
	// }*/
	// int a = GetWeaponOwner(b), j = GetEntPropEnt(a, Prop_Send, "m_hViewModel")
	// SetEntPropFloat(j, Prop_Send, "m_flLayerStartTime", 1.0)
	// SetEntProp(j, Prop_Send, "m_nLayerSequence", 0)
	// PrintToChatAll("%i %i", GetEntProp(j, Prop_Data, "m_nSequence"), GetEntProp(j, Prop_Send, "m_nLayerSequence")) 
// }
bool bPass
MRESReturn DH_OnSelectWeightedSequence(int b, Handle hReturn, Handle hParam)
{
	if(bPass) return MRES_Ignored
	int i = DHookGetParam(hParam, 1), l = i, d
	switch(l)
	{
		case 193, 1264, 1403:
		{
			int a = GetWeaponOwner(b)
			if(!GetWeaponClip(b)) l = 1269
			if(bZoom[a]) SetWeaponHelpingHandState(b, 6), l = ACT_PRIMARY_VM_RELOAD
			// bZoom[a] = false
			// SetViewModelIdleAnim(a, b)
		}
		case 1252:
		{
			int a = GetWeaponOwner(b)
			// l = bZoom[GetWeaponOwner(b)] ? ACT_PRIMARY_VM_PRIMARYATTACK : ACT_VM_PRIMARYATTACK
			if(!GetWeaponClip(b)) l = bZoom[a] ? ACT_PRIMARY_VM_DRYFIRE : ACT_VM_DRYFIRE
			else if(bZoom[a]) l = ACT_PRIMARY_VM_PRIMARYATTACK, SetWeaponHelpingHandState(b, 6)
			// SetViewModelIdleAnim(a, b)
		}
		case 1276:
		{
			if(!EntStore[b] && GetWeaponClip(b)) l = ACT_VM_DRAW, EntStore[b] = 1
			bZoom[GetWeaponOwner(b)] = false
		}
		case 1250,1254:
		{
			if(bZoom[GetWeaponOwner(b)]) SetWeaponHelpingHandState(b, 6), l = ACT_PRIMARY_VM_SECONDARYATTACK
		}
	}
	if((d = GetCustomWeaponAnim(b, l)) != -1)
	{
		DHookSetReturn(hReturn, d)
		return MRES_Supercede
	}
	// PrintToChatAll("%i %i %i", l, d, GetEntProp(GetEntPropEnt(GetWeaponOwner(b), Prop_Send, "m_hViewModel"), Prop_Data, "m_nSequence"))
	if(l != i)
	{
		bPass = true
		d = SelectWeightedSequence(b, l)
		bPass = false
		// if(l == 1875) PrintToChatAll("%i %i", l, d)
		if(d != -1)
		{
			DHookSetReturn(hReturn, d)
			return MRES_Supercede
		}
	}
	return MRES_Ignored
}
/*public MRESReturn DH_SelectHeaviestSequence(int b, Handle hReturn, Handle hParam)
{
	int w = GetEntPropEnt(b, Prop_Send, "m_hWeapon"), l = DHookGetParam(hParam, 1), i = GetCustomWeaponAnim(w, l == 183 && bZoom[GetWeaponOwner(w)] && !IsActivityReloadAnim(GetEntData(w, m_IdealActivity)) ? ACT_PRIMARY_VM_IDLE : l)
	PrintToChatAll("%i %i", l, i)
	if(i != -1)
	{
		DHookSetReturn(hReturn, i)
		return MRES_Supercede
	}
	return MRES_Ignored
}*/
bool IsActivityReloadAnim(i)
{
	switch(i)
	{
		case ACT_VM_RELOAD_LIST: return true
	}
	return false
}
GetCustomWeaponAnim(int w, int l)
{
	char s[40]
	GetEntityClassname(w, s, sizeof s)
	hWeaponData.Rewind()
	if(hWeaponData.JumpToKey(s) && hWeaponData.JumpToKey("Animation"))
	{
		s[0] = 0
		if(hActivityList.GotoFirstSubKey(false))
		{
			do
			{
				if(hActivityList.GetNum(NULL_STRING) == l)
				{
					hActivityList.GetSectionName(s, sizeof s)
					break
				}
			}
			while(hActivityList.GotoNextKey(false))
			hActivityList.GoBack()
		}
		
		if(s[0] && hWeaponData.JumpToKey(s))
		{
			int i = hWeaponData.GetNum(NULL_STRING, -1)
			if(i >= 0) return i
			if(hWeaponData.GotoFirstSubKey(false))
			{
				ArrayList list = new ArrayList()
				do
				{
					list.Push(hWeaponData.GetNum(NULL_STRING))
				}while(hWeaponData.GotoNextKey(false))
				i = list.Get(GetRandomInt(0, list.Length-1))
				list.Close()
				return i
			}
		}
	}
	return -1
	// return l == ACT_VM_RELOAD_END_NOEMPTY ? 1 : -1
}

weapon_zoom(Handle:e, const String:n[], bool:d)
{
	int a = GetClientOfUserId(GetEventInt(e, "userid"))
	bool b = GetEntProp(a, Prop_Send, "m_iFOV") != 0
	if(bZoom[a] != b)
	{
		int w = GetPlayerWeapon(a)
		if(w != -1) SetupZoom(a, w, b)
	}
}
weapon_drop(Handle:e, const String:n[], bool:d)
{
	EntStore[GetEventInt(e, "propid")] = 0
}
KeyValues hRestoreWeaponAttr
weapon_fire(Handle:e, const String:name[], bool:d)
{
	int i = GetEventInt(e, "weaponid")
	switch(i)
	{
		case 54,CHAINSAW,MELEE: return
	}
	int a = GetClientOfUserId(GetEventInt(e, "userid"))
	if(GetClientTeam(a) != 2) return
	int b = GetPlayerWeapon(a)
	if(b == -1) return
	static m_iPrimaryAmmoType = -1
	if(m_iPrimaryAmmoType == -1) m_iPrimaryAmmoType = FindDataMapInfo(b, "m_iPrimaryAmmoType")
	switch(GetEntData(b, m_iPrimaryAmmoType))
	{
		case AMMO_PISTOL,AMMO_PISTOL_MAGNUM,AMMO_ASSAULTRIFLE,AMMO_SMG,AMMO_M60,AMMO_SHOTGUN,AMMO_AUTOSHOTGUN,AMMO_HUNTINGRIFLE,AMMO_SNIPERRIFLE,AMMO_GRENADELAUNCHER:
		{
			if(bZoom[a])
			{
				int weaponinfo = SDKCall(hGetWeaponInfoByID, i)
				char s[12]
				FormatEx(s, 12, "%i", weaponinfo)
				hRestoreWeaponAttr = new KeyValues(s)
				
				
				SetToRestoreWeaponAttrFloat(weaponinfo, FWA_VerticalPunch, ads_recoil_modifier)
				SetToRestoreWeaponAttrFloat(weaponinfo, FWA_HorizontalPunch, ads_recoil_modifier)
				
				SetToRestoreWeaponAttrFloat(weaponinfo, FWA_MaxSpread, ads_spread_modifier)
				SetToRestoreWeaponAttrFloat(weaponinfo, FWA_SpreadPerShot, ads_spread_modifier)
				SetToRestoreWeaponAttrFloat(weaponinfo, FWA_MinDuckingSpread, ads_spread_modifier)
				SetToRestoreWeaponAttrFloat(weaponinfo, FWA_MinStandingSpread, ads_spread_modifier)
				SetToRestoreWeaponAttrFloat(weaponinfo, FWA_MinInAirSpread, ads_spread_modifier)
				SetToRestoreWeaponAttrFloat(weaponinfo, FWA_MaxMovementSpread, ads_spread_modifier)
				
				SetToRestoreWeaponAttrFloat(weaponinfo, FWA_PelletScatterPitch, ads_pellet_scatter_modifier)
				SetToRestoreWeaponAttrFloat(weaponinfo, FWA_PelletScatterYaw, ads_pellet_scatter_modifier)
				
				
				/*SetToRestoreWeaponAttrFloat(weaponinfo, "Range", FWA_Range)
				SetToRestoreWeaponAttrFloat(weaponinfo, "RangeModifier", FWA_RangeModifier)
				SetToRestoreWeaponAttrFloat(weaponinfo, "GainRange", FWA_GainRange)*/
			}
		}
	}
}

SetToRestoreWeaponAttrFloat(weaponinfo, type, float m=1.0)
{
	weaponinfo+=type
	char s[12]
	FormatEx(s, 12, "%i", type)
	float f = LoadFromAddress(view_as<Address>(weaponinfo), NumberType_Int32)
	hRestoreWeaponAttr.SetFloat(s, f)
	StoreToAddress(view_as<Address>(weaponinfo), f*m, NumberType_Int32);
}

bool SendWeaponAnim(w, i)
{
	static Handle hSendWeaponAnim
	if(!hSendWeaponAnim)
	{
		StartPrepSDKCall(SDKCall_Entity)
		PrepSDKCall_SetVirtual(252-iOS)
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain)
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain)
		hSendWeaponAnim = EndPrepSDKCall()
	}
	return SDKCall(hSendWeaponAnim, w, i)
	// return SDKCall(hSendWeaponAnim, w, i)
}

/*stock int GetWeaponClip(int weapon)
{
	static m_iClip1 = -1
	if(m_iClip1 == -1) m_iClip1 = FindDataMapInfo(weapon, "m_iClip1")
	int i = GetEntData(weapon, m_iClip1)
	return i == 254 ? 0 : i
}*/

int SelectWeightedSequence(int a, int i)
{
	static Handle hSelectWeightedSequence
	if(!hSelectWeightedSequence)
	{
		StartPrepSDKCall(SDKCall_Entity)
		PrepSDKCall_SetVirtual(208-iOS)
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain)
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain)
		hSelectWeightedSequence = EndPrepSDKCall()
	}
	return SDKCall(hSelectWeightedSequence, a, i)
}

MRESReturn DH_PrimaryAttackPost(int b)
{
	if(!hRestoreWeaponAttr) return MRES_Ignored
	char n[12]
	hRestoreWeaponAttr.GetSectionName(n, 12)
	int weaponinfo = StringToInt(n)
	if(hRestoreWeaponAttr.GotoFirstSubKey(false))
	{
		do
		{
			hRestoreWeaponAttr.GetSectionName(n, 12)
			StoreToAddress(view_as<Address>(weaponinfo + StringToInt(n)), hRestoreWeaponAttr.GetFloat(NULL_STRING), NumberType_Int32);
		}while(hRestoreWeaponAttr.GotoNextKey(false))
	}
	InitHandle(hRestoreWeaponAttr)
	return MRES_Ignored
}
