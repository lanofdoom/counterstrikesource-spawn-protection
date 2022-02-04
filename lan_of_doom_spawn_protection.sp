#include <sourcemod>

public const Plugin myinfo = {
    name = "Spawn Protection", author = "LAN of DOOM",
    description = "Enables limited invulnerability after player spawn",
    version = "1.0.0",
    url = "https://github.com/lanofdoom/counterstrikesource-spawn-protection"};

static const char kPlayerClassname[] = "CCSPlayer";

static const char kTakeDamagePropertyName[] = "m_takedamage";
static const int kTakeDamageNoDamage = 0;
static const int kTakeDamageNormalDamage = 2;

static const char kRenderModePropertyName[] = "m_nRenderMode";
static const int kRenderModeNormal = 0;
static const int kRenderModeTransparent = 1;

static const char kColorPropertyName[] = "m_clrRender";
static const int kColorTransparent[4] = {255, 255, 255, 128};
static const int kColorOpaque[4] = {255, 255, 255, 255};

static int g_render_mode_offset = 0;
static int g_color_offset = 0;

static ArrayList g_spawn_protection_timer_end_time;
static ArrayList g_spawn_protection_timers;

static ConVar g_spawn_protection_time_cvar;
static ConVar g_spawn_protection_remove_delay_cvar;

//
// Logic
//

static Handle GetTimer(int userid) {
  while (g_spawn_protection_timers.Length <= userid) {
    g_spawn_protection_timers.Push(INVALID_HANDLE);
    g_spawn_protection_timer_end_time.Push(0.0);
  }

  return g_spawn_protection_timers.Get(userid);
}

static Action TimerElapsed(Handle timer, any userid) {
  g_spawn_protection_timers.Set(userid, INVALID_HANDLE);

  int client = GetClientOfUserId(userid);
  if (!client) {
    return Plugin_Stop;
  }

  if (IsClientInGame(client) && IsPlayerAlive(client)) {
    SetEntProp(client, Prop_Data, kTakeDamagePropertyName,
               kTakeDamageNormalDamage, 1);
    SetEntData(client, g_render_mode_offset, kRenderModeNormal, 1);
    SetEntDataArray(client, g_color_offset, kColorOpaque, 4, 1);
  }

  return Plugin_Stop;
}

static void Grant(int userid, float seconds) {
  Handle timer =
      CreateTimer(seconds, TimerElapsed, userid, TIMER_FLAG_NO_MAPCHANGE);
  g_spawn_protection_timers.Set(userid, timer);

  float end_time = GetTickedTime() + seconds;
  g_spawn_protection_timer_end_time.Set(userid, end_time);
}

static void RemoveAfter(int userid, float delay) {
  Handle old_timer = GetTimer(userid);
  if (old_timer == INVALID_HANDLE) {
    return;
  }

  if (delay <= 0.0) {
    TriggerTimer(old_timer);
    return;
  }

  float end_time = g_spawn_protection_timer_end_time.Get(userid);
  float seconds_remaining = end_time - GetTickedTime();

  if (delay > seconds_remaining) {
    return;
  }

  KillTimer(old_timer);

  Grant(userid, delay);
}

static void Invalidate(int userid) {
  Handle old_timer = GetTimer(userid);
  if (old_timer == INVALID_HANDLE) {
    return;
  }

  KillTimer(old_timer);
}

//
// Hooks
//

static Action OnPlayerDeath(Event event, const char[] name,
                            bool dont_broadcast) {
  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  Invalidate(userid);

  return Plugin_Continue;
}

static Action OnPlayerSpawn(Event event, const char[] name,
                            bool dont_broadcast) {
  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  Invalidate(userid);

  float spawn_protection = GetConVarFloat(g_spawn_protection_time_cvar);
  if (spawn_protection < 0.0) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(userid);
  if (!client) {
    return Plugin_Stop;
  }

  SetEntProp(client, Prop_Data, kTakeDamagePropertyName, kTakeDamageNoDamage,
             1);
  SetEntData(client, g_render_mode_offset, kRenderModeTransparent, 1);
  SetEntDataArray(client, g_color_offset, kColorTransparent, 4, 1);

  Grant(userid, spawn_protection);

  return Plugin_Continue;
}

static Action OnWeaponFire(Event event, const char[] name,
                           bool dont_broadcast) {
  int userid = GetEventInt(event, "userid");
  if (!userid) {
    return Plugin_Continue;
  }

  float remove_delay = GetConVarFloat(g_spawn_protection_remove_delay_cvar);

  RemoveAfter(userid, remove_delay);

  return Plugin_Continue;
}

//
// Forwards
//

public void OnMapEnd() {
  g_spawn_protection_timer_end_time.Clear();
  g_spawn_protection_timers.Clear();
}

public void OnPluginStart() {
  g_spawn_protection_time_cvar =
      CreateConVar("sm_lanofdoom_spawn_protection_time", "4.0",
                   "Controls how the player is protected from damage after " ...
                   "spwaning in seconds. Protection is removed after a " ...
                   "delay controlled by " ...
                   "sm_lanofdoom_spawn_protection_remove_delay if the " ...
                   "player uses a weapon.");

  g_spawn_protection_remove_delay_cvar =
      CreateConVar("sm_lanofdoom_spawn_protection_remove_delay", "1.0",
                   "Controls the maximum amount of time in seconds that a " ...
                   "player can retain their spawn protection after using a " ...
                   "weapon.");

  g_spawn_protection_timer_end_time = CreateArray(1, 0);
  g_spawn_protection_timers = CreateArray(1, 0);

  g_render_mode_offset =
      FindSendPropInfo(kPlayerClassname, kRenderModePropertyName);
  g_color_offset = FindSendPropInfo(kPlayerClassname, kColorPropertyName);

  HookEvent("player_death", OnPlayerDeath);
  HookEvent("player_spawn", OnPlayerSpawn);
  HookEvent("weapon_fire", OnWeaponFire);
}