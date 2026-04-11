# Save & Load System - Tavern Quest

## Ordnerstruktur

```
user://saves/
  [world_name]/
    world_info.json          -- Metadaten (world_name, last_played)
    world_state.json         -- Welt-Zustand (Dropped Items, NPC-States, Gruppen, Tageszeit)
    players/
      [player_name].json     -- Pro-Spieler-Daten (Skills, Inventar, Equipment, Stats, Quests, Gold, HP, Stamina)
```

Spieler werden ueber ihren **Namen** identifiziert, nicht per Peer-ID oder UUID.
Das loest das Problem, dass bei Debug-Neustarts die Peer-ID wechselt und Saves verloren gingen.


## Beteiligte Dateien

| Datei | Rolle |
|---|---|
| `scripts/save_manager.gd` | Autoload. Liest/schreibt JSON-Dateien. Verwaltet Welt-Ordner. |
| `scripts/world/game_manager.gd` | Orchestriert Save/Load beim Spawn, Disconnect und Auto-Save. |
| `scripts/world/world_state.gd` | Autoload. Haelt transienten Welt-Zustand (Dropped Items, NPC-States, removed_items, Tageszeit). |
| `scripts/world/adventure_group_manager.gd` | Autoload. Gruppen-Daten werden ueber WorldState mit-persistiert. |
| Komponenten: `skills_component.gd`, `inventory_component.gd`, `stats_component.gd`, `quest_component.gd`, `guild_rank.gd` | Jede Komponente hat `get_save_data()` und `apply_save_data()`. |


## Speicher-Ablauf (Save)

### Spieler-Daten

1. **`game_manager._collect_save_data(player)`** iteriert ueber alle Komponenten des Player-Nodes:
   - `Skills.get_save_data()` → skills, hotbar, points, last_position
   - `Inventory.get_save_data()` → Array von Slots (null oder {id, count})
   - `Inventory.get_equipment_save_data()` → Equipment-Dictionary
   - `Inventory.gold` → Gold-Betrag
   - `Stats.get_save_data()` → stats Dictionary + stat_points
   - `Quests.get_save_data()` → active + completed Arrays
   - `GuildRank.get_save_data()` → rank_index + points
   - `player.health` → HP
   - `player._stamina` → Stamina

2. **`SaveManager.update_player_data(player_name, data)`** schreibt das Dictionary als JSON.

3. **Wann wird gespeichert?**
   - Auto-Save Timer: alle 60 Sekunden (`game_manager._on_auto_save`)
   - Bei Spieler-Disconnect (`game_manager._on_player_disconnected`)
   - Bei `game_manager.save_all()` (speichert alle Spieler + Welt-Zustand)

### Welt-Zustand

1. **`WorldState.get_save_data()`** sammelt:
   - `dropped_items` → Array von {item_id, count, position{x,y,z}}
   - `npc_states` → Dictionary npc_id → beliebige Daten
   - `time_of_day` → float 0.0-24.0
   - `removed_items` → Array von Node-Pfaden (aufgehobene Welt-Items)
   - `adventure_groups` → AdventureGroupManager.get_save_data()

2. **`SaveManager.save_world_state(data)`** schreibt nach `world_state.json`.


## Lade-Ablauf (Load)

### Spielstart

1. `game_manager._ready()`:
   - `SaveManager.set_world(world_name)` → Ordner sicherstellen
   - `SaveManager.load_world_state()` → `WorldState.apply_save_data(ws)`
   - Spieler spawnen

### Spieler-Spawn

1. **`game_manager._spawn_player(peer_id, player_name)`**:
   - Scene instanziieren, Name = peer_id
   - `SaveManager.get_player_data(player_name)` → Saved Dictionary (oder Defaults)
   - **`_apply_all_save_data(player, player_name, saved)`** VOR `add_child`:
     - Skills: `player_uuid` setzen, `apply_save_data`, Position setzen
     - Inventory: `apply_save_data` (Slots), `apply_equipment_save_data`, `gold` setzen
     - Stats: `apply_save_data`
     - Quests: `apply_save_data`
     - GuildRank: `apply_save_data`
     - HP: aus saved oder max_hp berechnen
     - Stamina: aus saved oder max_stamina
   - `_players.add_child(player)` → MultiplayerSpawner repliziert

2. **Client-Sync** (nur fuer Gaeste, nach Spawn):
   - `_sync_all_to_client(peer_id, player)` sendet RPCs:
     - `sync_player_uuid` → Spielername
     - `sync_skill_data` → Skills, Hotbar, Punkte
     - `force_ui_refresh` → UI-Initialisierung
     - `sync_inventory` → Inventar-Slots
     - `sync_gold` → Gold-Betrag
     - `sync_stats_data` → Stats + Stat-Punkte
     - `sync_quests` → Quest-Daten
     - `sync_position` → Gespeicherte Position
     - `_rpc_sync_removed_items` → Aufgehobene Welt-Items


## Wichtige Regeln

### Reihenfolge beim Spawn

Alle Daten muessen VOR `add_child` angewendet werden. Der MultiplayerSpawner repliziert den Node beim `add_child` — wenn Skills/Inventar noch leer sind, bekommt der Client leere Daten.

### Gast-Position

Der Server simuliert Gast-Spieler nicht. `player.position` auf dem Server bleibt am Spawn-Punkt. Stattdessen:
- Gaeste melden ihre Position per `report_position` RPC an den Server
- `skills.last_position` wird per RPC aktuell gehalten
- Beim Speichern liest der Server `skills.last_position` (nicht `player.position`) fuer Gaeste

### JSON-Typ-Konvertierung

JSON laedt Zahlen als `float`. Bei Integer-Werten immer `int()` casten:
- `int(saved["gold"])`
- `int(entry.get("count", 1))`
- `float(data.get("time_of_day", 8.0))`

### Default-Daten

`SaveManager._default_player_data()` definiert die Grundwerte fuer neue Spieler. Wenn neue Felder hinzugefuegt werden:
1. Default in `_default_player_data()` eintragen
2. In `_collect_save_data()` das Feld sammeln
3. In `_apply_all_save_data()` das Feld laden
4. In der Komponente `get_save_data()` / `apply_save_data()` implementieren
5. Falls Multiplayer: `sync_*` RPC in `_sync_all_to_client()` hinzufuegen

### Gruppen-Persistenz

Abenteuergruppen werden als Teil des Welt-Zustands gespeichert (nicht pro Spieler). Sie bleiben erhalten auch wenn alle Mitglieder offline gehen oder das Spiel geschlossen wird.

- Gespeichert in: `world_state.json` → `adventure_groups`
- Geladen bei: Weltstart in `game_manager._ready()`
- Format: `{ "groups": { name → {leader, members, applications, shared_quest} }, "player_group": { name → group_name } }`

### Welt loeschen

`SaveManager.delete_world(world_name)` loescht rekursiv den gesamten Welt-Ordner inkl. aller Spieler-Saves.


## Checkliste: Neues Feld hinzufuegen

- [ ] Default-Wert in `SaveManager._default_player_data()`
- [ ] Komponente: `get_save_data()` gibt das Feld zurueck
- [ ] Komponente: `apply_save_data()` laedt das Feld
- [ ] `game_manager._collect_save_data()` sammelt das Feld
- [ ] `game_manager._apply_all_save_data()` wendet das Feld an
- [ ] `game_manager._sync_all_to_client()` sendet RPC fuer Multiplayer-Sync
- [ ] Komponente: `sync_*` RPC fuer Client-Empfang
- [ ] JSON-Typ-Konvertierung beachten (float → int wo noetig)
