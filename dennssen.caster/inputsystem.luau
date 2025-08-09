--!strict

local Util = require("util")

export type Keybind = {
	primary: Key,
	modifiers: { Key },
}

export type CustomInput = {
	name: string,
	description: string,
	hotkey: Key,
	modifiers: { Key },
	editable: boolean,
}

export type InputSystem = {
	__index: InputSystem,

	inputs: {
		keyboard: { [string]: CustomInput },
		gamepad: { [string]: CustomInput },
	},
	defaultKeybinds: {
		keyboard: { [string]: Keybind },
		gamepad: { [string]: Keybind },
	},
	keyToBeRebinded: {
		key: string,
		type: string,
	},
	pressedRebindModifiers: { [string]: { time: number } },
	pressedInputKeys: { [string]: { isModifier: boolean, time: number } },

	keyToString: (key: Key) -> string,

	setDefaultKeybinds: (keyboard: { [string]: Keybind }, gamepad: { [string]: Keybind }) -> (),
	deserializeKeybinds: (keybinds: string) -> { [string]: Keybind },
	getKeyboardKeysDown: () -> { Key },
	getGamepadKeysDown: () -> { Key },
	createCustomInput: (
		_name: string,
		_description: string,
		_hotkey: Key,
		_modifiers: { Key }?,
		_editable: boolean?
	) -> CustomInput,
	compareCustomInputs: (a: Keybind, b: Keybind) -> boolean,
	getCustomKey: (key: CustomInput) -> { down: boolean, held: boolean, up: boolean },
	getCustomAnalog: (key: CustomInput) -> number,
	serializeKeybinds: () -> { keyboard: string, gamepad: string },
	setNewInputTimes: (newInputs: { Key }) -> (),
	removeOldInputTimes: () -> (),
	saveKeybinds: () -> (),
	removeGamepadKeys: (keysList: { Key }) -> { Key },
	removeKeyboardKeys: (keysList: { Key }) -> { Key },
	rebind: (primary: string, modifiers: { Key }?) -> (),
	doRebind: () -> (),

	guiKeyboardInputs: (inputOrder: { string }?) -> (),
	guiGamepadInputs: (inputOrder: { string }?) -> (),

	readInputStart: () -> (),
	readInputEnd: () -> (),
}

local InputSystem: InputSystem = {} :: InputSystem
InputSystem.__index = InputSystem
InputSystem.inputs = {
	keyboard = {},
	gamepad = {},
}
InputSystem.defaultKeybinds = {
	keyboard = {},
	gamepad = {},
}
InputSystem.keyToBeRebinded = {
	key = "",
	type = "",
}
InputSystem.pressedRebindModifiers = {}
InputSystem.pressedInputKeys = {}

local keyboardKeys: { string } = {
	"Tab",
	"Enter",
	"Pause",
	"CapsLock",
	"Escape",
	"SpaceBar",
	"PageUp",
	"PageDown",
	"End",
	"Home",
	"Left",
	"Up",
	"Right",
	"Down",
	"Insert",
	"BackSpace",
	"Delete",
	"Zero",
	"One",
	"Two",
	"Three",
	"Four",
	"Five",
	"Six",
	"Seven",
	"Eight",
	"Nine",
	"A",
	"B",
	"C",
	"D",
	"E",
	"F",
	"G",
	"H",
	"I",
	"J",
	"K",
	"L",
	"M",
	"N",
	"O",
	"P",
	"Q",
	"R",
	"S",
	"T",
	"U",
	"V",
	"W",
	"X",
	"Y",
	"Z",
	"NumPadZero",
	"NumPadOne",
	"NumPadTwo",
	"NumPadThree",
	"NumPadFour",
	"NumPadFive",
	"NumPadSix",
	"NumPadSeven",
	"NumPadEight",
	"NumPadNine",
	"Multiply",
	"Add",
	"Subtract",
	"Decimal",
	"Divide",
	"F8",
	"F9",
	"F10",
	"F12",
	"NumLock",
	"ScrollLock",
	"LeftShift",
	"RightShift",
	"LeftControl",
	"RightControl",
	"LeftAlt",
	"RightAlt",
	"LeftCommand",
	"RightCommand",
	"Semicolon",
	"Equals",
	"Comma",
	"Hyphen",
	"Underscore",
	"Period",
	"Slash",
	"Tilde",
	"LeftBracket",
	"Backslash",
	"RightBracket",
	"Apostrophe",
	"Quote",
	"LeftParantheses",
	"RightParantheses",
	"Ampersand",
	"Asterix",
	"Caret",
	"Dollar",
	"Exclamation",
	"Colon",
	"A_AccentGrave",
	"E_AccentGrave",
	"E_AccentAigu",
	"C_Cedille",
	"Section",
	"LeftMouseButton",
	"MiddleMouseButton",
	"RightMouseButton",
}

local modifierKeys = {
	"LeftAlt",
	"LeftControl",
	"LeftShift",
	"RightAlt",
	"RightControl",
	"RightShift",
	"DPad_Up",
	"DPad_Down",
	"DPad_Right",
	"DPad_Left",
}

function InputSystem.keyToString(key: Key): string
	return string.gsub(tostring(key), "Gamepad_", "")
end

function InputSystem.setDefaultKeybinds(keyboard: { [string]: Keybind }, gamepad: { [string]: Keybind })
	InputSystem.defaultKeybinds.keyboard = keyboard
	InputSystem.defaultKeybinds.gamepad = gamepad
end

function InputSystem.deserializeKeybinds(string: string): { [string]: Keybind }
	local keybinds: { [string]: Keybind } = {}

	for fullEntry in string:gmatch("{(.-:{.-}})}") do
		local key, content = fullEntry:match("(.-):{(.*)}")
		if not key or not content then
			continue
		end

		local entry = {}

		entry.primary = Input.Key[content:match('primary:"([^"]+)"')]
		if entry.primary == nil then
			entry.primary = Input.Gamepad[content:match('primary:"([^"]+)"')]
		end

		local modifierContent = content:match("modifiers:{(.-)}") or ""
		entry.modifiers = {}

		for modifier in modifierContent:gmatch('"([^"]+)"') do
			local modifierKey = Input.Key[modifier]
			if modifierKey == nil then
				modifierKey = Input.Gamepad[modifier]
			end

			table.insert(entry.modifiers, modifierKey)
		end

		keybinds[key] = entry
	end

	return keybinds
end

function InputSystem.getGamepadKeysDown(): { Key }
	local bannedInputs =
		{ -- values to be ignored because their apperances are not predictable or should not be accepted
			Input.Gamepad.Left2D,
			Input.Gamepad.Right2D,
			Input.Gamepad.RightY,
			Input.Gamepad.RightX,
			Input.Gamepad.LeftY,
			Input.Gamepad.LeftX,
			Input.Gamepad.LeftTriggerAxis,
			Input.Gamepad.RightTriggerAxis,
			Input.Gamepad.LeftStick_Down,
			Input.Gamepad.LeftStick_Left,
			Input.Gamepad.LeftStick_Right,
			Input.Gamepad.LeftStick_Up,
			Input.Gamepad.RightStick_Down,
			Input.Gamepad.RightStick_Left,
			Input.Gamepad.RightStick_Right,
			Input.Gamepad.RightStick_Up,
		}
	local inputMeta = getmetatable(Input)
	local gamepad = inputMeta.__index.Gamepad
	local inputTable = nil
	for key, value in pairs(gamepad) do
		if type(value) == "table" then
			inputTable = value
			break
		end
	end

	local pressedKeys: { Key } = {}

	for key, _ in pairs(inputTable) do
		if Input.getKeyDown(Input.Gamepad[key]) then
			local banned = false
			for _, bannedValue in pairs(bannedInputs) do
				if InputSystem.keyToString(bannedValue) == InputSystem.keyToString(Input.Gamepad[key]) then
					banned = true
					break
				end
			end

			if banned then
				continue
			end

			table.insert(pressedKeys, Input.Gamepad[key])
		end
	end

	return pressedKeys
end

function InputSystem.getKeyboardKeysDown(): { Key }
	local bannedInputs = {}
	local pressedKeys: { Key } = {}

	for _, key in pairs(keyboardKeys) do
		if Input.getKeyDown(Input.Key[key]) then
			local banned = false
			for _, bannedValue: Key in pairs(bannedInputs) do
				if bannedValue == Input.Key[key] then
					banned = true
					break
				end
			end

			if banned then
				continue
			end

			table.insert(pressedKeys, Input.Key[key])
		end
	end
	return pressedKeys
end

function InputSystem.createCustomInput(
	_name: string,
	_description: string,
	_hotkey: Key,
	_modifires: { Key }?,
	_editable: boolean?
): CustomInput
	if _editable == nil then
		_editable = true
	end

	return {
		name = _name,
		description = _description,
		hotkey = _hotkey,
		modifiers = _modifires,
		editable = _editable,
	} :: CustomInput
end

function InputSystem.compareCustomInputs(a: Keybind, b: Keybind): boolean
	if InputSystem.keyToString(a.primary) ~= InputSystem.keyToString(b.primary) then
		return false
	end

	if (a.modifiers ~= nil) ~= (b.modifiers ~= nil) then
		return false
	end

	local isEqual = true

	if a.modifiers and b.modifiers then
		for _, aKey: Key in a.modifiers do
			if table.find(b.modifiers, aKey) == nil then
				isEqual = false
				break
			end
		end

		for _, bKey: Key in b.modifiers do
			if table.find(a.modifiers, bKey) == nil then
				isEqual = false
				break
			end
		end
	end

	return isEqual
end

function InputSystem.getCustomKey(key: CustomInput): { down: boolean, held: boolean, up: boolean }
	local primary = key.hotkey
	local modifiers = key.modifiers

	local inputData = {
		down = false,
		held = false,
		up = false,
	}

	-- no keys are pressed atm
	if Util.getDictSize(InputSystem.pressedInputKeys) == 0 then
		return inputData
	end

	-- primary key isn't pressed so no point in checking modifiers
	if InputSystem.pressedInputKeys[InputSystem.keyToString(primary)] == nil then
		return inputData
	end

	local currentPrimaryTime = InputSystem.pressedInputKeys[InputSystem.keyToString(primary)].time

	if Util.getDictSize(modifiers) > 0 then
		-- check for modifier keys not being held down
		for _, key: Key in modifiers do
			if not Input.getKeyDown(key) and not Input.getKey(key) then
				return inputData
			end

			-- if modifier is pressed after primary we don't allow the input
			local modTime = InputSystem.pressedInputKeys[InputSystem.keyToString(key)].time
			if modTime > currentPrimaryTime then
				return inputData
			end
		end
	else
		-- check for unwanted modifier keys that are pressed and held down and also CONCIDERED modifiers
		for _, key: string in modifierKeys do
			local modifier = InputSystem.pressedInputKeys[key]
			if modifier == nil then
				continue
			end

			-- check if the modifier key is concidered a modifier
			local isModifier = modifier.isModifier and key ~= InputSystem.keyToString(primary)

			local inputKey = Input.Key[key]
			if inputKey == nil then
				inputKey = Input.Gamepad[key]
			end

			if (Input.getKeyDown(inputKey) or Input.getKey(inputKey)) and isModifier then
				return inputData
			end
		end
	end

	if Input.getKeyDown(primary) then
		inputData.down = true
	end

	if Input.getKey(primary) then
		inputData.held = true
	end

	if Input.getKeyUp(primary) then
		inputData.up = true
	end

	return inputData
end

function InputSystem.getCustomAnalog(key: CustomInput): number
	local primary = key.hotkey
	local modifiers = key.modifiers

	if modifiers then
		-- check for modifier keys not being held down
		for _, key: Key in modifiers do
			if not Input.getKeyDown(key) and not Input.getKey(key) then
				return 0
			end
		end
	end

	return Input.getAnalog(primary)
end

function InputSystem.serializeKeybinds(): { keyboard: string, gamepad: string }
	local serializedKeyboardString = ""
	for key, value: CustomInput in InputSystem.inputs.keyboard :: { [string]: CustomInput } do
		serializedKeyboardString ..= "{" .. `{key}:` .. "{" .. `primary:"{InputSystem.keyToString(value.hotkey)}",modifiers:` .. "{"

		if value.modifiers then
			for i, modifier: Key in value.modifiers do
				serializedKeyboardString ..= `"{InputSystem.keyToString(modifier)}"`
				if i ~= #value.modifiers then
					serializedKeyboardString ..= `,`
				end
			end
		end

		serializedKeyboardString ..= "}}}"
	end

	local serializedGamepadString = ""
	for key, value: CustomInput in InputSystem.inputs.gamepad :: { [string]: CustomInput } do
		serializedGamepadString ..= "{" .. `{key}:` .. "{" .. `primary:"{InputSystem.keyToString(value.hotkey)}",modifiers:` .. "{"

		if value.modifiers then
			for i, modifier: Key in value.modifiers do
				serializedGamepadString ..= `"{InputSystem.keyToString(modifier)}"`
				if i ~= #value.modifiers then
					serializedGamepadString ..= `,`
				end
			end
		end

		serializedGamepadString ..= "}}}"
	end

	return {
		keyboard = serializedKeyboardString,
		gamepad = serializedGamepadString,
	}
end

function InputSystem.setNewInputTimes(newInputs: { Key })
	for _, newInput in newInputs do
		if newInput then
			local newInputString = InputSystem.keyToString(newInput)

			local conciderModifier = true
			if table.find(modifierKeys, newInputString) ~= nil then
				for key: string, pressedInput in InputSystem.pressedInputKeys :: { [string]: any } do
					if table.find(modifierKeys, key) == nil then
						conciderModifier = false
					end
				end
			else
				conciderModifier = false
			end

			InputSystem.pressedInputKeys[newInputString] = {
				time = os.clock(),
				isModifier = conciderModifier,
			}
		end
	end
end

function InputSystem.removeOldInputTimes()
	local removeKeys = {}
	for keyKey: string, _ in InputSystem.pressedInputKeys do
		local key: Key
		if Input.Key[keyKey] then
			key = Input.Key[keyKey]
		else
			key = Input.Gamepad[keyKey]
		end

		if Input.getKeyDown(key) or Input.getKey(key) then
			continue
		end

		table.insert(removeKeys, keyKey)
	end

	for _, removeKeyKey: string in removeKeys do
		InputSystem.pressedInputKeys[removeKeyKey] = nil
	end
end

function InputSystem.saveKeybinds()
	local keybindsSerilazied = InputSystem.serializeKeybinds()
	config.keyboardKeybinds = keybindsSerilazied.keyboard
	config.gamepadKeybinds = keybindsSerilazied.gamepad
	saveConfig()
end

function InputSystem.removeGamepadKeys(keysList: { Key }): { Key }
	local removeIndexes: { number } = {}
	for i, key: Key in keysList do
		local keyString = InputSystem.keyToString(key)
		if table.find(keyboardKeys, keyString) == nil then
			table.insert(removeIndexes, i)
		end
	end

	for _, index in removeIndexes do
		table.remove(keysList, index)
	end

	return keysList
end

function InputSystem.removeKeyboardKeys(keysList: { Key }): { Key }
	local removeIndexes: { number } = {}
	for i, key: Key in keysList do
		local keyString = InputSystem.keyToString(key)
		if table.find(keyboardKeys, keyString) ~= nil then
			table.insert(removeIndexes, i)
		end
	end

	for _, index in removeIndexes do
		table.remove(keysList, index)
	end

	return keysList
end

function InputSystem.rebind(primary: string, modifiers: { Key }?)
	if InputSystem.keyToBeRebinded.type == "keyboard" then
		if table.find(keyboardKeys, primary) == nil then
			return
		end

		local _modifiers: { Key }

		if modifiers then
			_modifiers = InputSystem.removeGamepadKeys(modifiers)
		else
			_modifiers = {}
		end

		InputSystem.inputs.keyboard[InputSystem.keyToBeRebinded.key].modifiers = _modifiers
		InputSystem.inputs.keyboard[InputSystem.keyToBeRebinded.key].hotkey = Input.Key[primary]
	elseif InputSystem.keyToBeRebinded.type == "gamepad" then
		if table.find(keyboardKeys, primary) ~= nil then
			return
		end

		local _modifiers: { Key }

		if modifiers then
			_modifiers = InputSystem.removeKeyboardKeys(modifiers)
		else
			_modifiers = {}
		end

		InputSystem.inputs.gamepad[InputSystem.keyToBeRebinded.key].modifiers = _modifiers
		InputSystem.inputs.gamepad[InputSystem.keyToBeRebinded.key].hotkey = Input.Gamepad[primary]
	end

	InputSystem.keyToBeRebinded.key = ""
	InputSystem.pressedRebindModifiers = {}
	InputSystem.saveKeybinds()
end

function InputSystem.doRebind()
	if Util.getDictSize(InputSystem.pressedInputKeys) == 0 then
		if Util.getDictSize(InputSystem.pressedRebindModifiers) ~= 0 then
			local primary: string
			local biggestTime = 0

			for key: string, pressedRebindInput in InputSystem.pressedRebindModifiers :: { [string]: { time: number } } do
				if pressedRebindInput.time > biggestTime then
					biggestTime = pressedRebindInput.time
					primary = key
				end
			end

			local modifiers = {}
			for key, _ in InputSystem.pressedRebindModifiers do
				if key ~= primary then
					table.insert(modifiers, Input.Key[key])
				end
			end

			InputSystem.rebind(primary, modifiers)
		end

		return
	end

	local newestKey: string
	local biggestTime = 0
	for key, pressedInputInfo in InputSystem.pressedInputKeys do
		if pressedInputInfo.time > biggestTime then
			biggestTime = pressedInputInfo.time
			newestKey = key
		end
	end

	-- newest key is primary
	if table.find(modifierKeys, newestKey) == nil then
		local modifiers = {}

		for key, pressedInputInfo in InputSystem.pressedInputKeys do
			if table.find(modifierKeys, key) ~= nil and pressedInputInfo.isModifier then
				local modifierKey = Input.Key[key]
				if modifierKey == nil then
					modifierKey = Input.Gamepad[key]
				end

				table.insert(modifiers, modifierKey)
			end
		end

		InputSystem.rebind(newestKey, modifiers)
	else
		-- store modifier
		InputSystem.pressedRebindModifiers[newestKey] = {
			time = biggestTime,
		}
	end
end

function InputSystem.guiKeyboardInputs(inputOrder: { string }?)
	if Gui.beginTable("KeyboardControls", 3) then
		Gui.tableSetupColumn("Name")
		Gui.tableSetupColumn("Description")
		Gui.tableSetupColumn("Hotkey")
		Gui.tableHeadersRow()

		local _inputOrder: { string } = {}
		if inputOrder then
			_inputOrder = inputOrder
		else
			for key: string, _ in InputSystem.inputs.keyboard do
				table.insert(_inputOrder, key)
			end
		end

		for _, customInputKey: string in _inputOrder do
			local customInput = InputSystem.inputs.keyboard[customInputKey]

			Gui.tableNextRow()
			Gui.tableNextColumn()
			Gui.text(customInput.name)
			Gui.tableNextColumn()
			Gui.text(customInput.description)
			Gui.tableNextColumn()

			local buttonLabel = ""
			if customInput.modifiers then
				for _, input: Key in customInput.modifiers do
					buttonLabel = buttonLabel .. `{InputSystem.keyToString(input)} + `
				end
			end
			buttonLabel = buttonLabel .. `{InputSystem.keyToString(customInput.hotkey)}`

			if InputSystem.keyToBeRebinded.key == customInputKey and InputSystem.keyToBeRebinded.type == "keyboard" then
				buttonLabel = "..."
			end

			if Gui.button(`{buttonLabel}##{customInputKey}`) then
				if InputSystem.keyToBeRebinded.key ~= customInputKey then
					InputSystem.keyToBeRebinded.key = customInputKey
					InputSystem.keyToBeRebinded.type = "keyboard"
				else
					InputSystem.keyToBeRebinded.key = ""
				end
			end

			Gui.sameLine()

			if
				not InputSystem.compareCustomInputs({
					primary = customInput.hotkey,
					modifiers = customInput.modifiers,
				}, {
					primary = InputSystem.defaultKeybinds.keyboard[customInputKey].primary,
					modifiers = InputSystem.defaultKeybinds.keyboard[customInputKey].modifiers,
				}) and Gui.button(`{Icon.Undo}##{customInputKey}`)
			then
				local defaultValue = InputSystem.defaultKeybinds.keyboard[customInputKey]
				InputSystem.inputs.keyboard[customInputKey].modifiers = defaultValue.modifiers
				InputSystem.inputs.keyboard[customInputKey].hotkey = defaultValue.primary
				InputSystem.saveKeybinds()
			end
		end
		Gui.endTable()
	end
end

function InputSystem.guiGamepadInputs(inputOrder: { string }?)
	if Gui.beginTable("ControllerControls", 3) then
		Gui.tableSetupColumn("Name")
		Gui.tableSetupColumn("Description")
		Gui.tableSetupColumn("Hotkey")
		Gui.tableHeadersRow()

		local _inputOrder: { string } = {}
		if inputOrder then
			_inputOrder = inputOrder
		else
			for key: string, _ in InputSystem.inputs.gamepad do
				table.insert(_inputOrder, key)
			end
		end

		for _, customInputKey: string in _inputOrder do
			local customInput: CustomInput = InputSystem.inputs.gamepad[customInputKey]

			Gui.tableNextRow()
			Gui.tableNextColumn()
			Gui.text(customInput.name)
			Gui.tableNextColumn()
			Gui.text(customInput.description)
			Gui.tableNextColumn()

			local buttonLabel = ""
			if customInput.modifiers then
				for _, input: Key in customInput.modifiers do
					buttonLabel = buttonLabel .. `{InputSystem.keyToString(input)} + `
				end
			end
			buttonLabel = buttonLabel .. `{InputSystem.keyToString(customInput.hotkey)}`

			if InputSystem.keyToBeRebinded.key == customInputKey and InputSystem.keyToBeRebinded.type == "gamepad" then
				buttonLabel = "..."
			end

			if not customInput.editable then
				Gui.beginDisabled()
			end

			if Gui.button(`{buttonLabel}##{customInputKey}`) then
				if InputSystem.keyToBeRebinded.key ~= customInputKey then
					InputSystem.keyToBeRebinded.key = customInputKey
					InputSystem.keyToBeRebinded.type = "gamepad"
				else
					InputSystem.keyToBeRebinded.key = ""
				end
			end

			if not customInput.editable then
				Gui.endDisabled()
			end

			Gui.sameLine()

			if
				not InputSystem.compareCustomInputs({
					primary = customInput.hotkey,
					modifiers = customInput.modifiers,
				}, {
					primary = InputSystem.defaultKeybinds.gamepad[customInputKey].primary,
					modifiers = InputSystem.defaultKeybinds.gamepad[customInputKey].modifiers,
				}) and Gui.button(`{Icon.Undo}##{customInputKey}`)
			then
				local defaultValue = InputSystem.defaultKeybinds.gamepad[customInputKey]
				InputSystem.inputs.gamepad[customInputKey].modifiers = defaultValue.modifiers
				InputSystem.inputs.gamepad[customInputKey].hotkey = defaultValue.primary
				InputSystem.saveKeybinds()
			end
		end
		Gui.endTable()
	end
end

function InputSystem.readInputStart()
	InputSystem.setNewInputTimes(InputSystem.getKeyboardKeysDown())
	InputSystem.setNewInputTimes(InputSystem.getGamepadKeysDown())

	if InputSystem.keyToBeRebinded.key ~= "" then
		InputSystem.doRebind()
	end
end

function InputSystem.readInputEnd()
	InputSystem.removeOldInputTimes()
end

return InputSystem
