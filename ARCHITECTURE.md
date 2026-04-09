# tavern-quest — Architecture Overview

Godot 4.6.1 · Forward+ · Jolt Physics · ENet Multiplayer

---

## 1. Autoloads / Singletons

| Name | Zweck |
|---|---|
| `NetworkManager` | ENet-Host/Join, LAN-Discovery via UDP-Broadcast, Signale für Peer-Events |
| `LocaleManager` | Sprachauswahl, lädt `.translation`-Dateien |
| `VoiceOver` | Spielt Sprach-Audio per Key ab |
| `DialogManager` | Lädt Dialog-JSON, steuert Gesprächsfluss, emittiert `quest_offered` |
| `InventoryManager` | 30-Slot-Array mit `ItemData`-Dictionaries, Stapeln & Tauschen |
| `CharacterStats` | Spieler-Stats (5 Attribute) als Dictionary, berechnet abgeleitete Multiplikatoren |
| `QuestManager` | Liste aktiver/abgeschlossener Quests als `Array[Dictionary]` |
| `GuildRankManager` | Rang (F→S) und Quest-Punkte; Aufstieg via Promotions-Quests |

Alle Singletons laufen **pro Peer** — kein geteilter Zustand über das Netzwerk.

---

## 2. Szenen-Struktur

```
main.tscn  (World / Node3D)
├── DayNightCycle      (Node + day_night_cycle.gd)
├── WorldEnvironment   (ProceduralSky, SSAO, Glow)
├── Sun                (DirectionalLight3D)
├── Ground             (StaticBody3D)
├── NavigationRegion3D (NavMesh, runtime-gebacken via nav_baker.gd)
├── Tavern             (tavern.tscn → NPC-Szenen instanziiert)
├── Village            (village.tscn → quest_board.tscn u.a.)
├── PickableItems      (health_potion, iron_nails, gold_coin … als .tres)
├── Enemies            (enemy.tscn × n)
├── TrainingDummy      (training_dummy.tscn)
└── GameManager        (Node + game_manager.gd)
    └── Players        (Node3D — Ziel des MultiplayerSpawner)
        └── [peer_id]  (player.tscn, authority = peer_id)

player.tscn  (CharacterBody3D + player.gd)
├── Pivot / Mannequin  (AnimationPlayer, Skeleton3D, BoneAttachment → Sword)
├── CameraYaw / SpringArm3D / Camera3D
├── CombatHandler      (Node + combat_handler.gd, runtime-instanziiert)
├── SwordHitbox        (Area3D, runtime-instanziiert am hand_r-Bone)
├── HUD                (CanvasLayer + hud.gd)
├── ComboHUD           (CanvasLayer + combo_hud.gd)
├── GameMenu           (CanvasLayer + game_menu.gd)
├── DialogUI           (CanvasLayer + dialog_ui.gd)
└── InventoryUI        (CanvasLayer + inventory_ui.gd)
```

Alle UI-CanvasLayer werden nur für den lokalen Authority-Player instanziiert (`_is_mine()`).

---

## 3. Datenhaltung

| Domäne | Typ | Wo |
|---|---|---|
| **Items** | `ItemData` (Resource, `class_name`) | `.tres`-Dateien unter `data/items/`. Felder: `id`, `display_name`, `icon`, `stackable`, `max_stack`. |
| **Inventar** | `Array` von `{ "item": ItemData, "count": int }` oder `null` | `InventoryManager.slots` (Autoload, Runtime-only, kein Speichern) |
| **Quests** | `Array[Dictionary]` mit Keys `title_key`, `rank`, `source`, `rewarded` | `QuestManager._active_quests` / `_completed_quests` (Autoload, Runtime-only) |
| **Spieler-Stats** | `Dictionary { stat: int }` + `stat_points: int` | `CharacterStats.stats` (Autoload, Runtime-only) |
| **Gildrang** | `int _rank_index` + `int _points` | `GuildRankManager` (Autoload, Runtime-only) |
| **Dialog-Daten** | JSON-Dateien (`nodes`-Graph mit Choices, `give_quest`, `turn_in_quest`) | `res://data/dialogs/` — zur Laufzeit geladen von `DialogManager` |

Es gibt **kein Persistenz-System** (kein `save`/`load`). Alle Zustände sind Session-lokal.

---

## 4. Kommunikation zwischen Systemen

### Signale (primäres Muster)
- `DialogManager.quest_offered` → `QuestManager.accept_quest` (direkte Verbindung in `_ready`)
- `QuestManager.quest_completed` → `GuildRankManager._on_quest_completed` (direkte Verbindung)
- `InventoryManager.slot_changed / inventory_changed` → `InventoryUI` (UI reagiert)
- `CharacterStats.stats_changed` → `GameMenu`/`HUD` (UI-Updates)
- `GuildRankManager.rank_changed / points_changed` → UI
- `NetworkManager.player_connected/disconnected` → `GameManager` (Spawn/Despawn)

### Direkte Node-Referenzen
- `Player` hält Refs auf alle eigenen UI-CanvasLayer, `CombatHandler`, `_sword_hitbox`
- `CombatHandler` erhält `Player`, `AnimationPlayer`, `Area3D` via `setup()`-Injektion
- NPCs (`bartender.gd`, `receptionist.gd` …) rufen `DialogManager.start()` direkt auf
- `DialogManager` greift direkt auf `QuestManager` und `InventoryManager` zu (turn-in-Logik)

### Multiplayer (RPC)
- `GameManager._rpc_request_spawn` — Client → Server: Spawn anfordern
- `Player.take_damage` — RPC `any_peer/call_local/reliable`: Schaden auf Authorität anwenden
- `CombatHandler._do_damage` — sendet `take_damage.rpc_id(1, dmg)` an Server
- Animations-Sync: `net_anim` und `net_combat` als `int`-Vars, via Godot MultiplayerSynchronizer (implizit durch Szenen-Replikation)

---

## 5. Wichtigste Skripte

| Skript | Zuständigkeit |
|---|---|
| `scripts/network_manager.gd` | ENet-Session-Lifecycle, LAN-Broadcast/Discovery, Peer-Events |
| `scripts/world/game_manager.gd` | Spieler-Spawn/Despawn mit `MultiplayerSpawner`, Safe-Position-Check |
| `scripts/player/player.gd` | Bewegung, Input, State-Machine (NORMAL/DIALOG/INVENTORY/MENU/BOARD_VIEW), Interaktions-Raycast, Health, RPC-Empfang |
| `scripts/player/combat_handler.gd` | Combo-System (L/H-Eingaben → Combo-Key → Animation + Hitbox), Damage-Dispatch via RPC |
| `scripts/player/character_stats.gd` | 5-Attribut-System, berechnet Multiplikatoren für Schaden, Speed, HP |
| `scripts/dialog/dialog_manager.gd` | JSON-Dialog-Graph: Playback, Choices, Quest-Offer, Quest-Turn-in, Item-Entnahme |
| `scripts/world/quest_manager.gd` | Aktive/abgeschlossene Quests, Board-Reward-Tracking |
| `scripts/world/guild_rank_manager.gd` | Rang-Progression F→S via Punkte + Promotions-Quests |
| `scripts/inventory/inventory_manager.gd` | Slot-basiertes Inventar, Stapeln, Tauschen, Signale pro Slot |
| `scripts/world/enemy.gd` | Einfacher Gegner mit `take_damage`-RPC-Target und Navigation |
