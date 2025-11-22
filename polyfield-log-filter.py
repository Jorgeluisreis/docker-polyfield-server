#!/usr/bin/env python3

import os
import sys
import re
import json
from datetime import datetime
try:
    from zoneinfo import ZoneInfo
except Exception:
    ZoneInfo = None

DATA_DIR = os.environ.get('DATA_DIR', '/root/.config/unity3d/Mohammad Alizade/Polyfield')
LOGS_DIR = os.path.join(DATA_DIR, 'logs')
#!/usr/bin/env python3

import os
import sys
import re
import json
from datetime import datetime
try:
    from zoneinfo import ZoneInfo
except Exception:
    ZoneInfo = None

DATA_DIR = os.environ.get('DATA_DIR', '/root/.config/unity3d/Mohammad Alizade/Polyfield')
LOGS_DIR = os.path.join(DATA_DIR, 'logs')
os.makedirs(LOGS_DIR, exist_ok=True)

TZ = os.environ.get('TZ')
if TZ and ZoneInfo:
    try:
        TZINFO = ZoneInfo(TZ)
    except Exception:
        TZINFO = None
else:
    TZINFO = None


RE_MAP_LOAD = re.compile(r"map(?: name)?[:=]\s*'?\"?([^'\"]+)'?\"?", re.IGNORECASE)
RE_LOADING = re.compile(r"loading map\s+([^,\n]+)", re.IGNORECASE)
RE_SERVER_LIST = re.compile(r"server list.*created.*map[:=]?\s*([^,\n]+)", re.IGNORECASE)
RE_ADMIN = re.compile(r"admin(?: granted| added)?(?: to)?\s*(?:player|user)?\s*[:=]?\s*([^,\n]+)", re.IGNORECASE)
RE_BANNED_LOADED = re.compile(r"banned users.*loaded.*?(\d+)", re.IGNORECASE)
RE_XP = re.compile(r"xp\s*(?:added)?[:=]?\s*(\d+).*player[:=]?\s*([^,\n]+)", re.IGNORECASE)
RE_PLAYER_BANNED = re.compile(r"player\s*([^,\n]+)\s*bann?ed(?: for\s*(.*))?" re.IGNORECASE)
RE_PLAYER_KICKED = re.compile(r"\[.*?\]\s*([^\s]+)\s+was in kicked list for:\s*(.+)", re.IGNORECASE)
RE_VOTEKICKED = re.compile(r"\[GameManager\]\s*votekicked:\s*([^\s,\n]+)", re.IGNORECASE)
RE_VOTEKICK_WARN = re.compile(r"\[PlayerControl\]\s*([^\s]+)\s+recived warn:\s*Reason:\s*players vote", re.IGNORECASE)
RE_HIGH_PING_WARN = re.compile(r"\[PlayerControl\]\s*([^\s]+)\s+recived warn:\s*Reason:\s*high ping", re.IGNORECASE)
RE_TEAM_SWITCH = re.compile(r"\[.*?\]\s*([^,\n]+)\s+switched to\s+([^,\n]+)", re.IGNORECASE)
RE_GAME_XP = re.compile(r"(\d+)\s*\+\s*(\d+)\s*new xp added, total score[:=]?\s*(\d+)", re.IGNORECASE)


DEFAULT_ALLOWED_EVENTS = {
    'map_load',
    'player_banned',
    'player_kicked',
    'player_votekicked',
    'player_high_ping',
    'banned_users_loaded',
    'xp_added',
    'admin_granted',
    'server_list_created',
    'team_switched',
    'match_end',
    'server_restarting',
}


env_events = os.environ.get('LOG_EVENTS')
if env_events:
    parsed = set(e.strip().lower() for e in env_events.split(',') if e.strip())
    if 'all' in parsed or '*' in parsed or 'default' in parsed:
        ALLOWED_EVENTS = set(DEFAULT_ALLOWED_EVENTS)
    else:
        ALLOWED_EVENTS = parsed
else:
    ALLOWED_EVENTS = DEFAULT_ALLOWED_EVENTS



def slug(s: str, maxlen=80):
    s = (s or '').strip()
    s = re.sub(r"[^A-Za-z0-9]+", '_', s)
    return s[:maxlen].strip('_').lower() or 'unknown'


def now_ts():
    if TZINFO:
        return datetime.now(TZINFO).strftime('%Y-%m-%d %H:%M:%S %z')
    return datetime.now().strftime('%Y-%m-%d %H:%M:%S')


def human_ts():
    if TZINFO:
        return datetime.now(TZINFO).strftime('%Y-%d-%m %H:%M:%S')
    return datetime.now().strftime('%Y-%d-%m %H:%M:%S')



def file_ts():
    if TZINFO:
        return datetime.now(TZINFO).strftime('%Y-%m-%d_%H-%M')
    return datetime.now().strftime('%Y-%m-%d_%H-%M')


CURRENT_MAP = None
MAP_LOGFILE = {}


def create_map_log(mapname):

    slugname = slug(mapname)
    filename = f"{slugname}_{file_ts()}.log"
    path = os.path.join(LOGS_DIR, filename)
    try:
        with open(path, 'a', encoding='utf-8') as f:
            f.write(f"{human_ts()} | map_log_created: {mapname}\n")
    except Exception:
        pass
    MAP_LOGFILE[slugname] = path
    return path


def append_event(mapname, event_type, payload):

    target_map = mapname
    if mapname == 'global':
        if CURRENT_MAP:
            target_map = CURRENT_MAP
        else:

            return


    if event_type not in ALLOWED_EVENTS and event_type != 'map_load':
        return

    slugname = slug(target_map)
    mapfile = MAP_LOGFILE.get(slugname)
    if not mapfile:

        try:
            mapfile = create_map_log(target_map)
        except Exception:
            mapfile = os.path.join(LOGS_DIR, f"{slugname}.log")

    raw = ''
    if isinstance(payload, dict):
        raw = payload.get('raw') or json.dumps(payload, ensure_ascii=False)
    elif payload is None:
        raw = ''
    else:
        raw = str(payload)

    try:
        with open(mapfile, 'a', encoding='utf-8') as f:
            f.write(f"{human_ts()} | {event_type}: {raw}\n")
    except Exception:
        pass


def process_line(line: str):
    global CURRENT_MAP
    text = (line or '').strip()
    if not text:
        return


    if text.startswith('{'):
        try:
            obj = json.loads(text)
            if isinstance(obj, dict):
                mapname = obj.get('map', 'global')
                event_type = obj.get('event', 'info')
                payload = obj.get('data', {'raw': obj.get('data') or text})

                if event_type == 'map_load':
                    CURRENT_MAP = mapname
                    create_map_log(mapname)
                    if 'map_load' in ALLOWED_EVENTS:
                        append_event(mapname, event_type, payload)
                else:
                    if event_type in ALLOWED_EVENTS:
                        append_event(mapname, event_type, payload)
                return
        except Exception:

            pass


    m = RE_LOADING.search(text)
    if m:
        mapname = m.group(1).strip()
        CURRENT_MAP = mapname
        create_map_log(mapname)
        if 'map_load' in ALLOWED_EVENTS:
            append_event(mapname, 'map_load', {'raw': text})
        return

    m = RE_MAP_LOAD.search(text)
    if m:
        mapname = m.group(1).strip()
        CURRENT_MAP = mapname
        create_map_log(mapname)
        if 'map_load' in ALLOWED_EVENTS:
            append_event(mapname, 'map_load', {'raw': text})
        return

    m = RE_SERVER_LIST.search(text)
    if m:
        mapname = m.group(1).strip()
        CURRENT_MAP = mapname
        create_map_log(mapname)
        if 'server_list_created' in ALLOWED_EVENTS:
            append_event(mapname, 'server_list_created', {'raw': text})
        return

    m = RE_ADMIN.search(text)
    if m:
        who = m.group(1).strip()
        if 'admin_granted' in ALLOWED_EVENTS:
            append_event('global', 'admin_granted', {'who': who, 'raw': text})
        return

    m = RE_BANNED_LOADED.search(text)
    if m:
        try:
            count = int(m.group(1))
        except Exception:
            count = None
        if 'banned_users_loaded' in ALLOWED_EVENTS:
            append_event('global', 'banned_users_loaded', {'count': count, 'raw': text})
        return

    m = RE_XP.search(text)
    if m:
        try:
            xp = int(m.group(1))
        except Exception:
            xp = None
        player = m.group(2).strip() if m.group(2) else None
        if 'xp_added' in ALLOWED_EVENTS:
            append_event('global', 'xp_added', {'player': player, 'xp': xp, 'raw': text})
        return

    m = RE_PLAYER_BANNED.search(text)
    if m:
        player = m.group(1).strip()
        reason = m.group(2).strip() if m.group(2) else None
        if 'player_banned' in ALLOWED_EVENTS:
            append_event('global', 'player_banned', {'player': player, 'reason': reason, 'raw': text})
        return

    m = RE_PLAYER_KICKED.search(text)
    if m:
        player = m.group(1).strip()
        reason = m.group(2).strip()
        if 'player_kicked' in ALLOWED_EVENTS:
            append_event('global', 'player_kicked', {'player': player, 'reason': reason, 'raw': text})
        return

    m = RE_VOTEKICKED.search(text)
    if m:
        player = m.group(1).strip()
        if 'player_votekicked' in ALLOWED_EVENTS:
            append_event('global', 'player_votekicked', {'player': player, 'raw': text})
        return

    m = RE_VOTEKICK_WARN.search(text)
    if m:
        player = m.group(1).strip()
        if 'player_votekicked' in ALLOWED_EVENTS:
            append_event('global', 'player_votekicked', {'player': player, 'reason': 'players vote', 'raw': text})
        return

    m = RE_HIGH_PING_WARN.search(text)
    if m:
        player = m.group(1).strip()
        if 'player_high_ping' in ALLOWED_EVENTS:
            append_event('global', 'player_high_ping', {'player': player, 'reason': 'high ping', 'raw': text})
        return

    m = RE_TEAM_SWITCH.search(text)
    if m:
        player = m.group(1).strip()
        team = m.group(2).strip()
        if 'team_switched' in ALLOWED_EVENTS:
            append_event('global', 'team_switched', {'player': player, 'team': team, 'raw': text})
        return

    m = RE_GAME_XP.search(text)
    if m:
        try:
            a = int(m.group(1))
            b = int(m.group(2))
            total = int(m.group(3))
        except Exception:
            a = b = total = None
        if 'match_end' in ALLOWED_EVENTS:
            append_event('global', 'match_end', {'added1': a, 'added2': b, 'total': total, 'raw': text})
        return


    return


def main():

    while True:
        line = sys.stdin.readline()
        if not line:
            try:
                import time
                time.sleep(0.1)
                continue
            except KeyboardInterrupt:
                break
        try:
            process_line(line)
        except Exception:

            continue


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
