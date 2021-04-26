
/**
 * MAIN REQUIREMENTS
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>


/**
 * CUSTOM DEFINITIONS TO BE EDITED
 */

#define _SV_TICK_RATE_KV_FILE_      "SvTickRate.TXT"
#define _SV_TICK_RATE_KV_TITLE_     "SvTickRate"


/**
 * CUSTOM INFORMATION
 */

public Plugin myinfo =
{
    name =          "Tick Rate Control",
    author =        "CARAMEL® HACK",
    description =   "Provides Custom Tick Rate Values",
    version =       __DATE__,
    url =           "https://hattrick.go.ro/",
};


/**
 * CUSTOM PRIVATE FUNCTIONS
 */

static bool _Create_Dir_(const char[] szDirPath, const int nCombinations = 8192)
{
    static int nIter = 0;

    for (nIter = 0; nIter < nCombinations; nIter++)
    {
        if (CreateDirectory(szDirPath, nIter))
        {
            return true;
        }
    }

    return false;
}

static void _Get_Sv_Full_Ip_(char[] szFullIpAddr, const int nLen)
{
    static char net_public_adr[PLATFORM_MAX_PATH] = { 0, ... }, hostip[PLATFORM_MAX_PATH] = { 0, ... },
        ip[PLATFORM_MAX_PATH] = { 0, ... }, hostport[PLATFORM_MAX_PATH] = { 0, ... };

    static ConVar net_public_adr_h = null, hostip_h = null, ip_h = null, hostport_h = null;
    static int hostip_n = 0;

    if (net_public_adr_h == null)
    {
        net_public_adr_h = FindConVar("net_public_adr");
    }

    if (hostip_h == null)
    {
        hostip_h = FindConVar("hostip");
    }

    if (ip_h == null)
    {
        ip_h = FindConVar("ip");
    }

    if (hostport_h == null)
    {
        hostport_h = FindConVar("hostport");
    }

    if (net_public_adr_h != null)
    {
        net_public_adr_h.GetString(net_public_adr, sizeof (net_public_adr));

        ReplaceStringEx(net_public_adr, sizeof (net_public_adr), "::", ":", 2, 1, true);
    }

    if (hostip_h != null)
    {
        hostip_n = hostip_h.IntValue;

        FormatEx(hostip, sizeof (hostip), "%d.%d.%d.%d", (hostip_n >> 24) & 0xFF, (hostip_n >> 16) & 0xFF, (hostip_n >> 8) & 0xFF, hostip_n & 0xFF);
    }

    if (ip_h != null)
    {
        ip_h.GetString(ip, sizeof (ip));

        ReplaceStringEx(ip, sizeof (ip), "::", ":", 2, 1, true);
    }

    if (hostport_h != null)
    {
        hostport_h.GetString(hostport, sizeof (hostport));
    }

    if (IsCharNumeric(net_public_adr[0]))
    {
        if (FindCharInString(net_public_adr, ':') == -1)
        {
            FormatEx(szFullIpAddr, nLen, "%s:%s", net_public_adr, hostport);
        }

        else
        {
            strcopy(szFullIpAddr, nLen, net_public_adr);
        }
    }

    else if (IsCharNumeric(hostip[0]))
    {
        if (FindCharInString(hostip, ':') == -1)
        {
            FormatEx(szFullIpAddr, nLen, "%s:%s", hostip, hostport);
        }

        else
        {
            strcopy(szFullIpAddr, nLen, hostip);
        }
    }

    else if (IsCharNumeric(ip[0]))
    {
        if (FindCharInString(ip, ':') == -1)
        {
            FormatEx(szFullIpAddr, nLen, "%s:%s", ip, hostport);
        }

        else
        {
            strcopy(szFullIpAddr, nLen, ip);
        }
    }

    else if (strlen(net_public_adr) > 0)
    {
        if (FindCharInString(net_public_adr, ':') == -1)
        {
            FormatEx(szFullIpAddr, nLen, "%s:%s", net_public_adr, hostport);
        }

        else
        {
            strcopy(szFullIpAddr, nLen, net_public_adr);
        }
    }

    else if (strlen(hostip) > 0)
    {
        if (FindCharInString(hostip, ':') == -1)
        {
            FormatEx(szFullIpAddr, nLen, "%s:%s", hostip, hostport);
        }

        else
        {
            strcopy(szFullIpAddr, nLen, hostip);
        }
    }

    else if (strlen(ip) > 0)
    {
        if (FindCharInString(ip, ':') == -1)
        {
            FormatEx(szFullIpAddr, nLen, "%s:%s", ip, hostport);
        }

        else
        {
            strcopy(szFullIpAddr, nLen, ip);
        }
    }

    else
    {
        FormatEx(szFullIpAddr, nLen, ":%s", hostport);
    }
}

bool _Get_From_Kv_File_(const char[] szFileTitle, const char[] szFileName, const char[] szEntry, const char[] szKey, char[] szValue, const int nLen)
{
    static KeyValues hKv = null;
    static char szBuffer[PLATFORM_MAX_PATH] = { 0, ... };

    hKv = new KeyValues(szFileTitle);

    if (hKv == null)
    {
        return false;
    }

    hKv.ImportFromFile(szFileName);

    if (!hKv.GotoFirstSubKey())
    {
        delete hKv;

        hKv = null;

        return false;
    }

    do
    {
        hKv.GetSectionName(szBuffer, sizeof (szBuffer));

        if (strcmp(szBuffer, szEntry, false) == 0)
        {
            hKv.GetString(szKey, szValue, nLen);

            delete hKv;

            hKv = null;

            return true;
        }
    }

    while (hKv.GotoNextKey());

    delete hKv;

    hKv = null;

    return false;
}

static int _Get_Sv_Tick_Rate_()
{
    return RoundToNearest(1.0 / GetTickInterval());
}


/**
 * CUSTOM PUBLIC FORWARDS
 */

public void OnPluginStart()
{
    OnMapStart();

    OnConfigsExecuted();
}

public void OnMapStart()
{
    static char szFullIpAddr[PLATFORM_MAX_PATH] = { 0, ... }, szDataPath[PLATFORM_MAX_PATH] = { 0, ... }, szDefaultTickRate[PLATFORM_MAX_PATH] = { 0, ... },
        szTickRateKvFile[PLATFORM_MAX_PATH] = { 0, ... }, szTickRate[PLATFORM_MAX_PATH] = { 0, ... }, szHours[PLATFORM_MAX_PATH] = { 0, ... },
        szCurrentHour[PLATFORM_MAX_PATH] = { 0, ... };

    static Handle hData = INVALID_HANDLE;
    static int nTickInterval = 0, nHostStateInterval = 0, nTickRate = 0, nDefaultTickRate = 0;
    static Address hStartSound = Address_Null, hSpawnServer = Address_Null, hTickInterval = Address_Null, hIntervalPerTick = Address_Null;
    static float fIntervalPerTick = 0.0, fDefaultIntervalPerTick = 0.0;

    BuildPath(Path_SM, szDataPath, sizeof (szDataPath), "data");

    if (!DirExists(szDataPath))
    {
        _Create_Dir_(szDataPath);
    }

    if ((hData = LoadGameConfigFile("tick_rate_control.games")) != INVALID_HANDLE)
    {
        if
        (
            (
                (hStartSound = GameConfGetAddress(hData,        "sv_startsound"))
                    !=
                (Address_Null)
            )
            &&
            (
                (hSpawnServer = GameConfGetAddress(hData,       "spawnserver"))
                    !=
                (Address_Null)
            )
            &&
            (
                (nTickInterval = GameConfGetOffset(hData,       "m_flTickInterval"))
                    !=
                (-1)
            )
            &&
            (
                (nHostStateInterval = GameConfGetOffset(hData,  "host_state_interval"))
                    !=
                (-1)
            )
        )
        {
            hTickInterval       = view_as<Address>(LoadFromAddress(hStartSound  + view_as<Address>(nTickInterval),      NumberType_Int32));
            hIntervalPerTick    = view_as<Address>(LoadFromAddress(hSpawnServer + view_as<Address>(nHostStateInterval), NumberType_Int32));

            if (hTickInterval   != Address_Null && hIntervalPerTick != Address_Null)
            {
                if (DirExists(szDataPath))
                {
                    FormatEx(szTickRateKvFile, sizeof (szTickRateKvFile), "%s/%s", szDataPath, _SV_TICK_RATE_KV_FILE_);

                    if (FileExists(szTickRateKvFile))
                    {
                        _Get_Sv_Full_Ip_(szFullIpAddr, sizeof (szFullIpAddr));

                        if (_Get_From_Kv_File_(_SV_TICK_RATE_KV_TITLE_, szTickRateKvFile, szFullIpAddr,         "tick_rate",                szTickRate,         sizeof (szTickRate)))
                        {
                            if (_Get_From_Kv_File_(_SV_TICK_RATE_KV_TITLE_, szTickRateKvFile, szFullIpAddr,     "default_tick_rate",        szDefaultTickRate,  sizeof (szDefaultTickRate)))
                            {
                                if (_Get_From_Kv_File_(_SV_TICK_RATE_KV_TITLE_, szTickRateKvFile, szFullIpAddr, "hours_for_not_default",    szHours,            sizeof (szHours)))
                                {
                                    if (strlen(szTickRate) > 0 && strlen(szDefaultTickRate) > 0 && strlen(szHours) > 0)
                                    {
                                        FormatTime(szCurrentHour, sizeof (szCurrentHour), "%H");

                                        nTickRate =                             StringToInt(szTickRate);
                                        nDefaultTickRate =                      StringToInt(szDefaultTickRate);

                                        fIntervalPerTick =                      1.0 / float(nTickRate);
                                        fDefaultIntervalPerTick =               1.0 / float(nDefaultTickRate);

                                        if (StrContains(szHours, szCurrentHour) != -1)
                                        {
                                            StoreToAddress(hTickInterval,       view_as<int>(fIntervalPerTick), NumberType_Int32);
                                            StoreToAddress(hIntervalPerTick,    view_as<int>(fIntervalPerTick), NumberType_Int32);
                                        }

                                        else
                                        {
                                            StoreToAddress(hTickInterval,       view_as<int>(fDefaultIntervalPerTick), NumberType_Int32);
                                            StoreToAddress(hIntervalPerTick,    view_as<int>(fDefaultIntervalPerTick), NumberType_Int32);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        CloseHandle(hData);

        hData = INVALID_HANDLE;
    }
}

public void OnConfigsExecuted()
{
    ServerCommand("exec %d_tickrate.cfg", _Get_Sv_Tick_Rate_());
}
