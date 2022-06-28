# Pause Screen Completion Marks API
Code that can be included into Binding of Isaac: Repentance mods to allow them to render completion marks on the pause menu.

## What does this API do?

Two distinct but related things:

1. For **character mods** that are **already tracking their own vanilla achievements**, this allows them to easily display those achievements on the pause menu.
2. For mods that have their own **custom achievements or completion marks**, this allows them to display them on the pause menu if they so desire, alongside any marks from other mods.

## WHAT THIS API DOES NOT DO

**This API does *NOT* track achievements!** This is for mods already tracking their own achievements to display them on the pause screen while allowing multiple mods to share that space!

If you're just looking for completion mark tracking & display for any modded character not using this API, check out [Completion Marks for ALL Modded Characters](https://steamcommunity.com/sharedfiles/filedetails/?id=2503022727) instead.

If you're a modder trying to figure out how to handle unlocks and save data, you'll have to look elsewhere, sorry. Try taking a look at some popular character mods that feature unlocks.

## How to install

### 1. Place the "resources" folder into your mod's folder.

Merge with your existing resources folder if one exists. The graphical assets for this API are contained within a subfolder called "pause screen completion marks", so this should not overwrite any existing files.

### 2. Place `"pause_screen_completion_marks_api.lua"` wherever your scripts go.

Putting it directly in your folder next to `"main.lua"` is fine if you have no dedicated folder for your other scripts.

### 3. `include(...)` the API file.

Somewhere in your lua code (doesn't really matter where, but it should above wherever you want to actually call the API), you'll have to `"include()"` the lua file we just added.

Just add a line like one of these examples, depending on where you put the lua file:

```lua
include("pause_screen_completion_marks_api") -- If you put the lua file in your main folder, next to main.lua
include("myscripts.pause_screen_completion_marks_api") -- If you put it in a subfolder, add it like this. Remember that the path has to be specified from the top-level folder (where main.lua is) even if you're including it from another script in the same folder!
include("myscripts/pause_screen_completion_marks_api") -- This works too, same as the above.
```

Note that the `"include()"` call will NOT return anything, so don't try to store it in a variable! This API should only be accessed through its global variable: `PauseScreenCompletionMarksAPI`.

Please do NOT use `"require()"` for this API!

### 4. Set up the shader

A shader is required in order to render over the pause menu.

If you don't have a `"content/shaders.xml"` file already, just drop my `"shaders.xml"` into your content folder, and skip to the next step.

If your mod already has a shader used for rendering above the hud, you should make this API use that shader, as well, rather than adding another. After `include`'ing the API, call this function:

```lua
PauseScreenCompletionMarksAPI:SetShader("YourShaderName")
```

This will allow the API to use your existing shader, if needed. Better to avoid having multiple shaders in your mod if possible.

If your shader can't be used for this purpose, you can just add my dummy shader to your existing file manually.

## How to update

Simply overwrite your current `"pause_screen_completion_marks_api.lua"` file with the latest one!

## How to use

### Vanilla completion marks for modded characters.

You'll need to provide a callback function to the API for it to fetch your completion info from:

```lua
PauseScreenCompletionMarksAPI:AddModCharacterCallback(YourCharacterId, mod.FunctionThatReturnsYourCompletionTable)

PauseScreenCompletionMarksAPI:AddModCharacterCallback(YourCharacterId, function()
	return MyCompletionTable
end)
```

Basically, you provide a function for the API to call when it wants to get the completion marks for your character. The function you provide must return a table in an appropriate format.

Please note that I'm happy to update the API to be able to recognize the format you're already storing your completion marks in, if that wuld be easier for you than changing your existing format so that its acceptable to this API. Within reason of course, depending on how wacky your format is.

However, in general, a format like this is preferred/accepted:

```
tab[markName] = { Unlock = true, Hard = false }
tab[markName] = { Unlocked = false, HardMode = false }
tab[markLayer] = markFrame
```

"markLayer" and "markFrame" refer to the corresponding layer and frame numbers in `"gfx/ui/completion_widget.anm2"`.

"markName" is a string representing the name of the completion mark. Here's a simple set of examples:

```
DELIRIUM
MOMSHEART
ISAAC
SATAN
BOSSRUSH
BLUEBABY
LAMB
MEGASATAN
ULTRAGREED
HUSH
MOTHER
BEAST
```

Note that the API is capable of recognizing a whole bunch of variations of these names, and normalizes any strings you provide, so for example, all of the following would be correctly identified:

```
Mother
mother
MOTHER
witness
The Witness
THE_WITNESS!
```

Just let me know if the API doesn't recognize the format of your unlocks, and as long as your format isn't TOO obtuse, I can consider adding support for it.

### Custom completion marks

You'll need to provide a callback function for the API to fetch your custom completion marks from:

```lua
PauseScreenCompletionMarksAPI:AddModMarksCallback("UNIQUE_MOD_NAME", function(playerType)
	return FunctionThatReturnsYourCustomMarks(playerType)
end)

PauseScreenCompletionMarksAPI:AddModMarksCallback("UNIQUE_MOD_NAME", FunctionThatReturnsYourCustomMarks)
```

The function you provide must return a table of sprites it should render on the pause menu. The API will call this function ONCE each time the pause menu is first opened, and will keep the provided sprites until the pause menu is closed.

The callback provides the character ID of player 1, in case you have custom achievements tied to specific characters.

There are two main formats you can provide sprites:

#### *1. One Sprite object for each mark*

If you just provide a table of Sprite objects directly, the API will render them as-is. The API will NOT change the current animation or frame of the sprite before rendering it! So please note that any changes you make to this sprite object afterwards WILL be reflected on the pause menu! Update your sprites to the appropriate frame in this function to make sure they reflect the current unlock status.

```lua
local sampleSprite1 = Sprite()
sampleSprite1:Load("gfx/.../my_custom_mark_sprite_1.anm2", true)

local sampleSprite2 = Sprite()
sampleSprite2:Load("gfx/.../my_custom_mark_sprite_2.anm2", true)

local function FunctionThatReturnsYourCustomMarks(playerType)
	local sprites = {}
	
	sampleSprite1:SetFrame("MarkA", 0)
	table.insert(sprites, sampleSprite1)
	
	sampleSprite2:SetFrame("MarkB", 1)
	table.insert(sprites, sampleSprite2)
	
	return sprites
end

PauseScreenCompletionMarksAPI:AddModMarksCallback("UNIQUE_MOD_NAME", FunctionThatReturnsYourCustomMarks)
```

#### *2. One Sprite with specific Animations and/or Frames for each mark*

Alternatively, if you want to be more efficient and use a single sprite/anm2 for all your marks (recommended) you can instead pass a set of tables that specify a specific animation & frame to render from a shared sprite:

```lua
local sampleSprite = Sprite()
sampleSprite:Load("gfx/.../my_custom_marks_sprite.anm2", true)

local function FunctionThatReturnsYourCustomMarks(playerType)
	local sprites = {}
	
	table.insert(sprites, {
		Sprite = sampleSprite,
		Animation = "Mark1",
		Frame = 2,
	})
	
	table.insert(sprites, {
		Sprite = sampleSprite,
		Animation = "Mark2",
		Frame = 0,
	})
	
	table.insert(sprites, {
		Sprite = sampleSprite,
		Animation = "Mark3",
		Frame = 1,
	})
	
	return sprites
end

PauseScreenCompletionMarksAPI:AddModMarksCallback("UNIQUE_MOD_NAME", FunctionThatReturnsYourCustomMarks)
```

If you do it this way, the API will set the sprite to the provided Animation and Frame before rendering it.

An example sprite and anm2 are viewable at "resources\gfx\ui\pause screen completion marks\sample_marks.anm2".