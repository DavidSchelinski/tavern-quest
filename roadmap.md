================================================================================
  TAVERN QUEST – ROADMAP
================================================================================

LEGENDE
-------
  [x] Fertig          [~] Teilweise fertig          [ ] Offen

VISION
------
Ein kooperatives Multiplayer-RPG in dem Spieler gemeinsam oder alleine Quests
annehmen, Monster besiegen und aufsteigen. Die Taverne dient als zentraler
Treffpunkt. Ein Spieler hostet die Welt – alle anderen verbinden sich zu ihm.


================================================================================
  PHASE 1 – FUNDAMENT                                          [weitgehend fertig]
================================================================================

[x] Spieler-Bewegung (Walk, Sprint, Jump mit Animationen)
[x] Third-Person-Kamera mit SpringArm
[x] Interaktionssystem (Raycast, Interactable-Gruppe)
[x] Quest-Board (Grundstruktur – Szene + Bereich vorhanden)
[x] Taverne (Szene, Barkeeper-NPC)
[x] Animationsübergänge (Blending)
[x] Bewegungslogik gekoppelt an Animationszustand
[x] Hauptmenü (Spiel starten, Hosten, Beitreten, Beenden)
[x] Grundlegendes UI-Framework (Game-Menü, Dialog-UI, Inventory-UI, Combo-HUD)
[x] Lokalisierung (LocaleManager)
[x] Voice-Over System

[ ] Spieler-Charakterauswahl / Name vergeben
[ ] Einstellungen (Lautstärke, Grafik, Steuerung)
[ ] Speichersystem (Spielerdaten lokal persistieren)


================================================================================
  PHASE 2 – CHARAKTERSYSTEM                                            [offen]
================================================================================

CHARAKTER-BEWERTUNG (Onboarding)
  Beim ersten Start wird der Spieler bewertet. Eine Reihe kurzer Aktivitäten
  oder Fragen ermittelt die Grundwerte. Diese sind dann fest und bestimmen
  den bevorzugten Kampfstil.

  Primäre Attribute:
    - Stärke       → Nahkampfschaden, Traglast
    - Beweglichkeit → Ausweichen, Angriffsgeschwindigkeit, Klettern
    - Verteidigung  → Schadensreduktion, Blocken
    - Ausdauer      → Stamina-Pool, Resistenz gegen Erschöpfung
    - Charisma      → NPC-Rekrutierung, bessere Questbelohnungen, Handel

  Sekundäre Werte (abgeleitet):
    - HP, Stamina, Mana
    - Kritische Trefferchance / -schaden
    - Bewegungsgeschwindigkeit (modifiziert durch Beweglichkeit)
    - Gewichtskapazität (modifiziert durch Stärke)

RANG-SYSTEM
  Ränge: F → E → D → C → B → A → S → S+ → S++
  - Jeder Spieler startet bei F-Rang
  - Rang steigt durch gesammelte Erfahrungspunkte aus Quests
  - Rang bestimmt welche Quests angenommen werden dürfen
  - Höherer Rang schaltet neue Gebiete, Ausrüstung und NPC-Rekruten frei

[ ] Attribut-Datenstruktur (Resource-Klasse)
[ ] Onboarding-Sequenz / Bewertungstest
[ ] Rang-System mit XP-Kurve
[ ] Charakter-UI (Stats-Übersicht, Rang-Anzeige)
[ ] Levelup / Rang-Aufstieg Logik + Feier-Effekt


================================================================================
  PHASE 3 – ABENTEUERGRUPPEN                                           [offen]
================================================================================

KONZEPT
  Jeder Spieler kann alleine spielen oder eine Abenteuergruppe bilden.
  Gruppenslots: 1-4 Teilnehmer (Spieler, NPCs oder gezähmte Kreaturen).

GRUPPENREGELN
  - Mindestring für Quests = niedrigster Rang aller menschlichen Gruppenmitglieder
  - Belohnungen werden gleichmäßig geteilt (XP und Gold)
  - Gruppenführer nimmt Quest an, alle Mitglieder müssen bestätigen
  - Gruppe wird automatisch aufgelöst wenn Quest abgeschlossen oder alle tot

SOLO-BEGLEITER
  - NPC-Rekruten: in der Taverne oder Welt anwerben (Charisma-Abhängig)
    Typen: Krieger, Heiler, Bogenschütze, Magier
  - Gezähmte Kreaturen: in der Welt gefunden/gebändigt
    Typen: Wolf, Bär, Adler, Golem usw.
  - Begleiter haben eigene KI, vereinfachtes Attributsystem und eigenen Rang

[ ] Gruppen-Datenstruktur (Mitgliederliste, Rang-Check)
[ ] Gruppen-UI (Übersicht, Einladen, Verlassen)
[ ] NPC-Begleiter-System (Rekrutierung, KI, Basis-Kampf)
[ ] Kreaturen-Zähmungssystem
[ ] Belohnungsaufteilung-Logik


================================================================================
  PHASE 4 – QUEST-SYSTEM                                               [offen]
================================================================================

QUEST-TYPEN
  - Besiege [Feind / Boss]                    (Kampf)
  - Sammle / Such nach [Gegenstand]           (Erkundung)
  - Hilf [Dorf / NPC] in [Gebiet]            (Event-Quest)
  - Eskortiere [NPC] von A nach B            (Schutz)
  - Erkunde [Dungeon / Gebiet]               (Entdeckung)
  - Liefere [Gegenstand] an [NPC]            (Botengänge)

QUEST-RANG-ÜBERSICHT
  Rang  Gegner-Stärke    Belohnung   Beispiel
  F     Ratten, Goblins  gering      Keller von Ratten befreien
  E     Wölfe, Banditen  moderat     Banditencamp zerstören
  D     Oger, Untote     ordentlich  Friedhof säubern
  C     Drachen (klein)  gut         Drachennest ausräuchern
  B     Riesen, Dämonen  sehr gut    Riesenangriff abwehren
  A     Legendenmonster  exzellent   Alten Drachen erlegen
  S     Weltbedrohungen  episch      Dämonenfürst versiegeln
  S+    ---              legendär    ---
  S++   ---              mythisch    ---

QUEST-ABLAUF
  1. Quest-Board in Taverne → Auswahl nach verfügbaren Rängen
  2. Quest annehmen → Briefing-Dialog mit Auftraggeber-NPC
  3. Welt-Ziel wird markiert (Karte / Kompass)
  4. Quest erfüllen
  5. Zurück zur Taverne oder direktes Abschließen in der Welt
  6. Belohnung empfangen → XP, Gold, evtl. Spezialgegenstand

[ ] Quest-Datenstruktur (Resource-Klasse mit Rang, Typ, Ziel, Belohnung)
[ ] Quest-Board UI (gefiltert nach Rang, sortierbar)
[ ] Quest-Tracker (HUD-Anzeige aktiver Quest, Zielmarkierung)
[ ] Quest-Generator (prozedural für F-C) + handgefertigte S-Quests
[ ] Quest-Abschluss-Logik + Belohnungsverteilung
[ ] Auftraggeber-NPC-Dialoge


================================================================================
  PHASE 5 – MULTIPLAYER (Godot High-Level Multiplayer API)    [weitgehend fertig]
================================================================================

ARCHITEKTUR
  Godot's ENet-basierter Multiplayer wird verwendet.
  Ein Spieler übernimmt die Host-Rolle (listen-server):
    - Startet den Server lokal
    - Tritt selbst als Spieler bei
    - Andere Spieler verbinden sich über IP:Port oder LAN-Discovery

  Keine dedizierte Server-Binärdatei notwendig für den Anfang.
  Optional später: Export als dedizierten headless Server.

NETZWERK-SCOPE
  Was synchronisiert wird:
    - Spielerpositionen und Animationen (MultiplayerSynchronizer)
    - Quest-Zustand der Gruppe (zentral beim Host)
    - Gesundheit, Statuseffekte
    - Gegner-KI und Positionen (host-autoritär)
    - Chat-Nachrichten
    - Gruppeneinladungen / -aktionen

  Was lokal bleibt:
    - Kamera-Steuerung
    - UI-Zustand
    - Eingabe

[x] Netzwerk-Manager (host, join, close, Fehler-Signale)
[x] LAN-Discovery (UDP-Broadcast + automatische Servererkennung)
[x] Spieler-Spawning über Netzwerk (Multiplayer-Authority pro Spieler)
[x] MultiplayerSynchronizer für Bewegung + Animationen (net_anim, net_combat)
[x] RPC-System für Kampfaktionen (take_damage, _net_hit, _net_destroy, _net_respawn)
[~] Verbindungsfehler-Handling (Signale vorhanden, kein UI-Feedback)

[ ] Lobby / Warteraum UI
[ ] Chat-System
[ ] Host-Migration (optional: wenn Host geht, neuer Host wird bestimmt)


================================================================================
  PHASE 6 – KAMPFSYSTEM                                      [in Arbeit]
================================================================================

KONZEPT
  Echtzeit-Kampf, Attribute beeinflussen Werte, kein rundenbasiertes System.

  Aktionen:
    - Leichtangriff (schnell, wenig Schaden)
    - Schwereangriff (langsam, viel Schaden)
    - Kombo-System (bis zu 3er-Ketten, 14 Kombinationen)
    - Ausweichen / Rollen (Stamina-Kosten)
    - Blocken (Verteidigung + Stamina)
    - Spezialangriff (je nach Klasse/Attributverteilung)
    - Magie / Fähigkeiten (Mana-Kosten)

  Statuseffekte: Vergiftet, Betäubt, Geschwächt, Brennend, Gefroren usw.

[x] Hitbox / Hurtbox System (Area3D an Knochenanbindung, Polling + Signale)
[x] Kombo-System (L/H-Eingaben, 14 Kombinationen, Kombo-Fenster-HUD)
[x] Schaden-Zahlenpopups (Label3D, animiert über dem Ziel)
[x] Trainings-Dummy (Ziel mit Gesundheit, Glow-Feedback, Respawn, Loot-Drop)
[~] Schaden-Formel (Fixwerte pro Kombo vorhanden, noch keine Attribut-Integration)

[ ] Stamina-System
[ ] Gegner-KI (Basisklassen: Nah, Fern, Magie)
[ ] Gegner-Ränge (F–S) mit skalierten Werten
[ ] Boss-Kämpfe (besondere Angriffsmuster)
[ ] Statuseffekt-System
[ ] Spieler-Tod / Respawn-Logik (in Gruppe: andere können wiederbeleben)
[ ] Ausweichen / Rollen
[ ] Blocken


================================================================================
  PHASE 7 – WELT & INHALTE                                    [in Arbeit]
================================================================================

WELT-STRUKTUR
  - Taverne (Hub) → Zentraler Start
  - Umgebung der Taverne (Tutorial-Gebiet, F-E Quests)
  - Wald          (E-D Rang)
  - Bergdorf      (C-B Rang, Dorf-Hilfe-Quests)
  - Ruinen        (B-A Rang)
  - Dämonengebiet (S Rang)

[x] Tag-Nacht-Zyklus (beeinflusst Atmosphäre)
[x] Inventar-System (ItemData Resource, Manager, UI)
[~] Loot-System (PickableItem-Szene + 5 Item-Ressourcen vorhanden, kein Drop-Table)

[ ] Welt-Streaming / Szenen-Wechsel zwischen Gebieten
[ ] Karte / Minimap
[ ] Wetter-System (optional)
[ ] Ausrüstungs-System (Waffe, Rüstung, Accessoire mit Attribut-Boni)
[ ] Händler-NPCs in der Taverne
[ ] Handgefertigte S-Quests (Story-Quests)


================================================================================
  PHASE 8 – POLISH & RELEASE                                           [offen]
================================================================================

[ ] Sound-Design (Schritte, Kampf, Umgebung, Musik)
[ ] Partikeleffekte (Kampf, Magie, Levelup)
[ ] Vollständiges Controller-Support
[ ] Performance-Optimierung (LOD, Culling, Netzwerk-Batching)
[ ] Fehlerbehandlung und Edge-Cases
[ ] Spieler-Feedback einbauen (Beta-Test)
[ ] Achievements / Erfolge
[ ] Steam-Integration (optional)


================================================================================
  PRIORISIERTE NÄCHSTE SCHRITTE
================================================================================

  1. Speichersystem + Charaktername         (Phase 1 abschließen)
  2. Attribut-Datenstruktur + Rang-System   (Phase 2, Basis für alles weitere)
  3. Stamina-System + Ausweichen/Blocken    (Phase 6 erweitern)
  4. Quest-Datenstruktur + Board-UI         (Phase 4)
  5. Gegner-KI (erste Feindtypen)           (Phase 6)
  6. Lobby-UI + Chat                        (Phase 5 abschließen)
  7. Welt-Inhalte (erste Gebiete, Gegner)   (Phase 7)


================================================================================
  OFFENE ENTSCHEIDUNGEN
================================================================================

  - Taverne oder Gilde als Hub? (beeinflusst Namensgebung + Atmosphäre)
  - Klassen-System oder nur Attribut-basiert?
  - Feste Welt oder prozedural generierte Dungeons?
  - Relay-Server (für einfachen Join ohne Port-Weiterleitung) – Steam, EOS?
  - Maximale Spieleranzahl pro Server (4, 8, 16?)


================================================================================
