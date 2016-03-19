if Prat then return end  -- TODO: better behaviour when Prat is around.


local loc_mt = {
		__index = function(t, k)
			_G.error("Locale key " .. tostring(k) .. " is not provided.")
		end
	}

local L = setmetatable({},  loc_mt)

function L.AddLocale(L, name, loc)
	if GetLocale() == name or name == "enUS" then
		for k, v in pairs(loc) do
			if v == true then
				L[k] = k
			else
				L[k] = v
			end
		end
	end
end


--@debug@
L:AddLocale("enUS", {
	module_name = "Bubblicious",
	module_desc = "Chat bubble related customizations",
	shorten_name = "Shorten Bubbles",
	shorten_desc = "Shorten the chat bubbles down to a single line each. Mouse over the bubble to expand the text.",
	color_name = "Color Bubbles",
	color_desc = "Color the chat bubble border the same as the chat type.",
	icons_name = "Show Raid Icons",
	icons_desc = "Show raid icons in the chat bubbles.",
	font_name = "Use Chat Font",
	font_desc = "Use the same font you are using on the chatframe",
	fontsize_name = "Font Size",
	fontsize_desc = "Set the chat bubble font size",	
})
--@end-debug@

-- These Localizations are auto-generated. To help with localization
-- please go to http://www.wowace.com/projects/bubblicious/localization/


--[===[@non-debug@
L:AddLocale("enUS", 
--@localization(locale="enUS", format="lua_table", same-key-is-true=true)@
)
L:AddLocale("frFR",  
--@localization(locale="frFR", format="lua_table", same-key-is-true=true)@
)
L:AddLocale("deDE", 
--@localization(locale="deDE", format="lua_table", same-key-is-true=true)@
)
L:AddLocale("koKR",  
--@localization(locale="koKR", format="lua_table", same-key-is-true=true)@
)
L:AddLocale("esMX",  
--@localization(locale="esMX", format="lua_table", same-key-is-true=true)@
)
L:AddLocale("ruRU",  
--@localization(locale="ruRU", format="lua_table", same-key-is-true=true)@
)
L:AddLocale("zhCN",  
--@localization(locale="zhCN", format="lua_table", same-key-is-true=true)@
)
L:AddLocale("esES",  
--@localization(locale="esES", format="lua_table", same-key-is-true=true)@
)
L:AddLocale("zhTW",  
--@localization(locale="zhTW", format="lua_table", same-key-is-true=true)@
)
--@end-non-debug@]===]

local addon = LibStub("AceAddon-3.0"):NewAddon("Bubblicious")

local defaults = {
	profile = {
	    on = true,
	    shorten = false,
	    color = true,
	    icons = true,
        font = true,
        fontsize = 14,
	}
} 



local toggleOption = {
		name = function(info) return L[info[#info].."_name"] end,
		desc = function(info) return L[info[#info].."_desc"] end,
		type="toggle", 
}

local options =  {
    handler = addon,
    get = "GetValue",
    set = "SetValue",	

    name = L["module_name"],
    desc = L["module_desc"],
    type = "group",
    args = {
    	shorten = toggleOption,
    	color = toggleOption,
    	icons = toggleOption,
        font = toggleOption,
        fontsize = {
        	name = L.fontsize_name,
        	desc = L.fontsize_desc,
        	type="range", min=8, max=32, step=1, order=101            
        }
	}
}



--[[------------------------------------------------
	Module Event Functions
------------------------------------------------]]--

local BUBBLE_SCAN_THROTTLE = 0.1

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BubbliciousDB", defaults, "Default")
    
	local acreg = LibStub("AceConfigRegistry-3.0")
	acreg:RegisterOptionsTable(L.module_name, options)

	local acdia = LibStub("AceConfigDialog-3.0")
	acdia:AddToBlizOptions(L.module_name, L.module_name)

    
    local cmd_name = L.module_name:upper()
	SlashCmdList[cmd_name] = 
    	function()     
        	local acd = LibStub("AceConfigDialog-3.0")
            if acd.OpenFrames[L.module_name] then
                acd:Close(L.module_name)
            else
                acd:Open(L.module_name)
            end
        end
        
    _G["SLASH_"..cmd_name.."1"] = "/"..cmd_name:lower()
end

-- things to do when the module is enabled
function addon:OnEnable()
    self.update = self.update or CreateFrame('Frame');
    self.throttle = BUBBLE_SCAN_THROTTLE

    self.update:SetScript("OnUpdate", 
        function(frame, elapsed) 
            self.throttle = self.throttle - elapsed
            if frame:IsShown() and self.throttle < 0 then
                self.throttle = BUBBLE_SCAN_THROTTLE
                self:FormatBubbles()
            end
        end)

    self:ApplyOptions()
end

function addon:OnDisable()
    self:RestoreDefaults()
end

function addon:SetValue(info, b)
	self.db.profile[info[#info]] = b
	addon:ApplyOptions()
end
function addon:GetValue(info)
	return self.db.profile[info[#info]]
end

function addon:ApplyOptions()
	self.shorten = self.db.profile.shorten
	self.color = self.db.profile.color
	self.icons = self.db.profile.icons
    self.font = self.db.profile.font 
    self.fontsize = self.db.profile.fontsize
	
	if self.shorten or self.color or self.format or self.icons or self.font then
	    self.update:Show()
	else
        self.update:Hide()
	end
end

function addon:FormatBubbles()
    self:IterateChatBubbles("FormatCallback")
end

function addon:RestoreDefaults()
    self.update:Hide()
    
    self:IterateChatBubbles("RestoreDefaultsCallback")
end

local MAX_CHATBUBBLE_WIDTH = 300

-- Called for each chatbubble, passed the bubble's frame and its fontstring
function addon:FormatCallback(frame, fontstring)
    -- Optimization: don't process bubbles that aren't shown.
    if not frame:IsShown() then 
        -- Clear last text so that if the same text is spoken again the bubble
        -- will be reprocessed
        fontstring.lastText = nil
        return 
    end
   
    -- Handle dynamic expansion/compression of the chat bubble.
    -- Note: The text is not actually changed in this step
    if self.shorten then 
        local wrap = fontstring:CanWordWrap() or 0
       
        -- If the mouse is over, then expand the bubble
        if frame:IsMouseOver() then
            fontstring:SetWordWrap(1)
        elseif wrap == 1 then
            fontstring:SetWordWrap(0)
        end 
    end 
    
    -- Keep our max bubble width up to date with the max width that 
    -- we observe the default UI using
    MAX_CHATBUBBLE_WIDTH = math.max(frame:GetWidth(), MAX_CHATBUBBLE_WIDTH)
 
    local text = fontstring:GetText() or ""
 
    -- Optimization: Dont process text on a given chat bubble more than once  
    if text == fontstring.lastText then
        -- Even if we have processed the bubble text, we may still need 
        -- to handle dynamic expansion/compression
        if self.shorten then
            fontstring:SetWidth(fontstring:GetWidth())
        end
        return 
    end
        
    if self.color then 
        -- Color the bubble border the same as the chat
        frame:SetBackdropBorderColor(fontstring:GetTextColor())
    end


    if self.font then
        local a,b,c = fontstring:GetFont()

        -- Set the font the same as the font used in ChatFrame1
        -- Also set the custom size (default client size is a bit over 14)
        fontstring:SetFont(ChatFrame1:GetFont(), self.fontsize, c)
    end


    if self.icons then
        -- Translate raid icon {rt1} {star} into actual icons
		local term;
		for tag in string.gmatch(text, "%b{}") do
			term = strlower(string.gsub(tag, "[{}]", ""));
			if ( ICON_TAG_LIST[term] and ICON_LIST[ICON_TAG_LIST[term]] ) then
				text = string.gsub(text, tag, ICON_LIST[ICON_TAG_LIST[term]] .. "0|t");
			end
		end  
    end

    -- We should end up here exactly once per bubble, resize the fontstring so that it
    -- takes up the correct space horizontally (which also sizes the bubble)
    fontstring:SetText(text)    
    fontstring.lastText = text  
    fontstring:SetWidth(math.min(fontstring:GetStringWidth(), MAX_CHATBUBBLE_WIDTH - 14))
end

-- Called for each chatbubble, passed the bubble's frame and its fontstring
function addon:RestoreDefaultsCallback(frame, fontstring)
   frame:SetBackdropBorderColor(1,1,1,1)
   fontstring:SetWordWrap(1)
   fontstring:SetWidth(fontstring:GetWidth())
end


-- A pretty generic function to process chat bubbles. 
-- This function is also provided under the MIT license, and is free
-- for you to reuse in your own addons
function addon:IterateChatBubbles(funcToCall)
    for i = 1, WorldFrame:GetNumChildren() do
        local v = select(i, WorldFrame:GetChildren())
        local b = v.isChatBubble == nil and v:GetBackdrop()
        if v.isChatBubble ~= false and b and b.bgFile == "Interface\\Tooltips\\ChatBubble-Background" then
            v.isChatBubble = true
            for i = 1, v:GetNumRegions() do
                local frame = v
                local v = select(i, v:GetRegions())
                if v:GetObjectType() == "FontString" then
                    local fontstring = v
                    if type(funcToCall) == "function" then
                        funcToCall(frame, fontstring)
                    else
                        self[funcToCall](self, frame, fontstring)
                    end
                end
            end
        else
            v.isChatBubble = false
        end
    end
end
