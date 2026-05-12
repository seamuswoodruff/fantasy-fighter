# Maker's Statement — Of Shadows and Steel

**Seamus Woodruff**
DCS 247 — AI in the World
Bowdoin College, 2026

---

## What This Is

*Of Shadows and Steel* is a 2D local multiplayer platform fighter built in Godot 4.6.2. two to four person local multiplayer, or one player against a CPU opponent (which is admittedly not the greatest.) players can choose from a roster of twelve characters and fight on one of three stages. The game runs natively on macOS or can be played in a browser at https://seamuswoodruf.itch.io/of-shadows-and-steel.

While I had originally gone in the direction of a platform fighter because my roommates and I all love playing super smash bros, I decided to pivot away from the floating platforms, side killzones, and damage based system to a simpler to implement HP based system and no side or roof killboxes/.

---

## How It Was Made

The technical backbone of this project is a combination of **Godot 4.6.2**, an open-source game engine, and **Claude Code** running through a Model Context Protocol (MCP) server connection. With the Godot engine's MCP tools Claude code can run the game, read= debug output, create scenes, and add nodes. Paired alongside multiple instances of Claude Cowork I was able to fully build a beginning file structure for the game, find and correctly organize assets, research the necessary game mechanics, and then write a series of .MD files that detailed the phases for claude codee to follow during the initial build of the game. and then more.MD instruction files once we got to the heavy debugging, balancing, expanding, and polishing work later in the project.

What this meant in practice: I would describe what I wanted to build, read and edit Cowork's proposed implementation doc, catch issues before they were passed to Code, request corrections, and then pass the instruction files over to Code to implement. I would then run cycles of the gameplay debug preview window to find bugs and issues with the game, before detailing the necessary fixes back to Claude code. In theory I imagined the process would go as follows not writing any GDScript myself or even working directly with the Godot Engine. Instead, I planned to operate solely as architect, Quality controller, and game designer. Specifying systems, reviewing implementations, catching logical errors, and making judgment calls about design. In reality this was only partially how things went. As I probably should anticipated, this was far more involved and hands on than I had hoped, Claude code was pretty good at writing code in GDscript (thank god, I did not want to try and teach myself a new coding language), and any manually edits or changes I did need to make were straightforward enought that my knowledge of Python and Java/coding languages in general made it fairly easy. What Claude Code sucks at it is graphical interfaces or placing any sort of collision objects, pretty much anything requiring interaction with a GUI I had to go and redo manually, which meant teaching myself how the Godot engine interface actually works. essentially all of the stages, collision objects, and HUD elements I had to make/place manually, and then work to debug them with Claude Code when my work lead to gamebreaking bugs when it interacted with the GDscript written by Claude. It also meant I had to edit by hand or painstakingly describe to Claude over and over what I wanted, and element placement for every single menu page. Claude Code is also not necessarily that good at picking variable values, which also lead to hours upon hours of not only debugging gameplay balance (which I expected) but also just about every other section of the game, tweaking size values, opacity, color, etc. for all of the UI. 

All of this meant that at every stage I had to have a pretty solid idea of everything that was being built, where it lived in the project, what scripts controlled what, and what interactions there were so I could catch the frequent bugs that occured as Claude Code built one thing and simultaneously broke another. I also was in a constant battle to manage CLaude Code's context window so that it didn't randomly hallucinate after compacting the conversation and start reverting changes we'd made or reimplementing something we'd already tested and then discarded (this happened multiple times). All in all, Claude Cowork reports that there were 40 major bugs documented in the devlogs, which definitely have gaps in them, some of which took me hours to resolve on there own. Some were simple (wrong collision layer numbers), some were subtle (a race condition between a hurt animation ending and a hitstun timer expiring that caused characters to freeze permanently), some were architectural (a VFX system that treated each PNG as a single frame instead of a sprite sheet, flooding the screen with 768×576 explosion pixel blocks during gameplay), and some just made me want to toss my computer out a window.

In total I'd estimate that this project probably took me in the neighborhood of 40-50 hours to complete, which was not my intention, and that's not including the time spent setting up the game engine, and figuring out the MCP server. Or accounting for the time lost when I completely bricked my computer and lost everything since my last github commit plus having to set up a completely new computer again (luckily I was pretty on top of pushing my commits). Still I think it's pretty amazing how capable Claude Code was in this project, and in game development in general. Prior to agentic AIs like this, there is simply no way that I could have achieved anything close to this, in this amount of time, with absolutely zero game devlopment knowledge, in a game engine I've never used before, that uses a coding language I had no experience with.


---

## Scope

The full build contains:

**Twelve playable characters** across four archetypes: Knights (three visual variants sharing one script), Samurai (two variants), and a roster of six ranged/magic characters (Fire Wizard, Lightning Mage, Wanderer Magician, Samurai Archer, and three ninjas Kunoichi, Ninja Monk, and Ninja Peasant). Each has a distinct movesetmade up of a  light attack, heavy attack, and two special inputs. Specials include various projectile throws, a healing animation, a block/defend stance, and a charged dash. Character behaviors are implemented in six scripts extending a shared base class, with subclasses overriding specific methods rather than duplicating physics logic.

**Three stages** with backgrounds, hand-placed platform collision bodies, stage-specific music and ambient audio, and kill zones that trigger respawn logic. Two stages use Gemini-generated backgrounds; one uses a free pixel art asset pack inspired by Genshin Impact's Mondstadt region.

**A complete menu flow**: animated main menu, character select with animated idle previews for each character character, stage select with thumbnail cards, a win screen displaying the winner's win animation, an options screen with working volume sliders and a controls reference table, a pause menu accessible mid-match, and a full credits menu.

**A 4-player system** with dynamic HUD, controller detection, and per-match stock count selection. The character select screen rebuilds its panel layout in real time as players join or as a P2 slot is toggled to CPU.

**A CPU AI controller**: a five-state machine (approach, attack, retreat, recover, idle) that drives all character archetypes without character-specific knowledge. It finds the nearest living opponent, closes distance, attacks when in range, backs off when hit, and avoids walking off stage edges (sometimes). the CPU is still pretty rough, I'd like to tune it further but ran out of time.

**A full audio and VFX pipeline**: 48 SFX groups crossfaded between attack/impact/footstep/UI categories, per-stage music playlists with 1-second crossfade transitions, ambient loops, and a VFX sprite-sheet parser.

---

## What Was Hard

**The state machine** required the most careful design work. Fighting game characters have many mutually exclusive states, idle, running, attacking, hurt, dead, blocking, special, and transitions between them have to be managed precisely. Early in development, characters would freeze in hurt states because the animation timer and the hitstun timer could disagree about when to exit. Characters would lock into attack states if an animation played under the wrong name. The fix for the freeze bug took significant debugging time

**Hitboxes registering multiple hits per swing** a more subtle bug that persisted into late development when I finally added active damage readouts and could see it visually happening. each physics frame, `_on_sprite_frame_changed()` re-evaluated whether a hitbox should be active and set `monitoring = true` when inside the active window. But `set_deferred("monitoring", false)`, the call used to disable the hitbox after a hit, queues its execution to the end of the frame. On the next frame, the frame-changed callback runs again, sees the frame is still active, re-enables monitoring, and the areas (still overlapping) fires `area_entered` a second time. A three-frame active window reliably produced three hits which completely broke my damage balancing, but went under the radar because I couldn't playtest with multiple people before this point.

**The 96-pixel frame size problem** appeared when integrating the three ninja characters. Every existing character used 128×128 pixel sprite frames, the standard for the asset packs sourced from Craftpix. Two of the ninja sprites used 96×96 frames. Because frame slicing is computed as `image_width / frame_size`, passing the wrong size produces wrong frame counts. The fix required detecting the frame size per character and parameterizing the sprite builder accordingly just for the two characters. This in turn lead to the characters rendering at incorrect sizes and heights in the game itself and having broken hitboxes, which lead to more debugging.

These are just a few salient examples of how things would constantly break, and required significant playtesting and debugging in order to fix them, and get the game running again.


## Reflection

This project ended up being a lot more time and effort than I had planned on getting myself into, but also produced something I'm pretty happy with, and gave me a newfound idea of just how mcuh is possible with the help of AI. It also drove home the point pretty clearly though, that if you want to make something good with AI that's also fairly complex, it's going to take a lot of time, effort, and very strict supervision, and the danger of making complete AI "slop" is very much real. I probably could have turned this project in at a barely acceptable level with around 10 hours of actual game development work, but it would have been a playable game in name alone, with pretty horrendous graphics and not even the vaguest sense of balanced gameplay. Where I'm at now after 4-5x that amount of time spent just on the active development is what I would consider the minimum deliverable that I'm actually proud of, and I think is reasonably fun to play. I hope you enjoy testing it out.

-Seamus Woodruff



---

*Built with Godot 4.6.2 and Claude Code (Anthropic) via MCP.*
*Bowdoin College — DCS 247: AI in the World — Spring 2026*
