local httpService = game:GetService("HttpService")

local InterfaceManager = {} do
	InterfaceManager.Folder = "FluentSettings"
	InterfaceManager.SettingsCache = nil -- Cache for settings
	InterfaceManager.LastSaveTime = 0 -- Debounce timer
	InterfaceManager.SaveDelay = 1 -- Minimum time between saves (1 second)
	InterfaceManager.PendingSave = false -- Flag for pending save
    InterfaceManager.Settings = {
        Theme = "Dark",
        Acrylic = true,
        Transparency = true,
        MenuKeybind = "LeftControl"
    }

    function InterfaceManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

    function InterfaceManager:SetLibrary(library)
		self.Library = library
	end

    function InterfaceManager:BuildFolderTree()
		local paths = {}

		local parts = self.Folder:split("/")
		for idx = 1, #parts do
			paths[#paths + 1] = table.concat(parts, "/", 1, idx)
		end

		table.insert(paths, self.Folder)
		table.insert(paths, self.Folder .. "/settings")

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

    function InterfaceManager:SaveSettings()
		-- Debounce saves to prevent excessive file writes
		local currentTime = tick()
		
		if currentTime - self.LastSaveTime < self.SaveDelay then
			-- Mark that we need to save later
			if not self.PendingSave then
				self.PendingSave = true
				task.delay(self.SaveDelay, function()
					self.PendingSave = false
					self:SaveSettings()
				end)
			end
			return
		end
		
		self.LastSaveTime = currentTime
		local encoded = httpService:JSONEncode(InterfaceManager.Settings)
		
		-- Only write if data has changed
		if self.SettingsCache ~= encoded then
			self.SettingsCache = encoded
			local success, err = pcall(writefile, self.Folder .. "/options.json", encoded)
			if not success then
				warn("Failed to save settings:", err)
			end
		end
    end

    function InterfaceManager:LoadSettings()
        local path = self.Folder .. "/options.json"
        if isfile(path) then
            local readSuccess, data = pcall(readfile, path)
			if not readSuccess then
				warn("Failed to read settings:", data)
				return
			end

			-- Cache the raw data
			self.SettingsCache = data

            local success, decoded = pcall(httpService.JSONDecode, httpService, data)

            if success then
				-- Validate and sanitize loaded settings
                for i, v in next, decoded do
					if InterfaceManager.Settings[i] ~= nil then
                    	InterfaceManager.Settings[i] = v
					end
                end
            else
				warn("Failed to decode settings:", decoded)
			end
        end
    end

    function InterfaceManager:BuildInterfaceSection(tab)
        assert(self.Library, "Must set InterfaceManager.Library")
		local Library = self.Library
        local Settings = InterfaceManager.Settings

        InterfaceManager:LoadSettings()

		local section = tab:AddSection("Interface")

		local InterfaceTheme = section:AddDropdown("InterfaceTheme", {
			Title = "Theme",
			Description = "Changes the interface theme.",
			Values = Library.Themes,
			Default = Settings.Theme,
			Callback = function(Value)
				Library:SetTheme(Value)
                Settings.Theme = Value
                InterfaceManager:SaveSettings()
			end
		})

        InterfaceTheme:SetValue(Settings.Theme)
	
		if Library.UseAcrylic then
			section:AddToggle("AcrylicToggle", {
				Title = "Acrylic",
				Description = "The blurred background requires graphic quality 8+",
				Default = Settings.Acrylic,
				Callback = function(Value)
					Library:ToggleAcrylic(Value)
                    Settings.Acrylic = Value
                    InterfaceManager:SaveSettings()
				end
			})
		end
	
		section:AddToggle("TransparentToggle", {
			Title = "Transparency",
			Description = "Makes the interface transparent.",
			Default = Settings.Transparency,
			Callback = function(Value)
				Library:ToggleTransparency(Value)
				Settings.Transparency = Value
                InterfaceManager:SaveSettings()
			end
		})
	
		local MenuKeybind = section:AddKeybind("MenuKeybind", { Title = "Minimize Bind", Default = Settings.MenuKeybind })
		MenuKeybind:OnChanged(function()
			Settings.MenuKeybind = MenuKeybind.Value
            InterfaceManager:SaveSettings()
		end)
		Library.MinimizeKeybind = MenuKeybind
    end
end

return InterfaceManager