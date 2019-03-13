#if defined _criticalhits_included
 #endinput
#endif
#define _criticalhits_included

/**
*	Toggle criticals per-player to on or off. (This is ignored if always crits is on)
*
*	client		:: Client index.
*	status		:: True is on, false is off.
*
*	Return		:: N/A
**/
native void CriticalHits_ToggleCrits(int client, bool status);

/**
*	Called right before a weapon is about to crit.
*	
*	Plugin_Continue = Do Nothing.
*	Plugin_Changed = Set the status.
*	Plugin_Handled = Stop the crit from happening.
*	Plugin_Stop = Stop the crit from happening.
*	
*	client		:: Client index.
*	weapon		:: Weapon index.
*	class		:: Classname of the weapon entity.
*	status		:: Returns the value, sets the value. (true = on, false = off)
*
*	Return		:: Action.
**/
forward Action OnWeaponCritical(int client, int weapon, const char[] class, bool &status);

/**
*	Called right after the crit has landed but not before the damage has landed.	
*
*	client		:: Client index.
*	weapon		:: Weapon index.
*	class		:: Classname of the weapon entity.
*
*	Return		:: N/A
**/
forward void OnWeaponCriticalPost(int client, int weapon, const char[] class);

#if !defined REQUIRE_PLUGIN
public void __pl_criticalhits_SetNTVOptional()
{
	MarkNativeAsOptional("CriticalHits_ToggleCrits");
}
#endif

public SharedPlugin __pl_criticalhits =
{
	name = "criticalhits",
	file = "criticalhits.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
