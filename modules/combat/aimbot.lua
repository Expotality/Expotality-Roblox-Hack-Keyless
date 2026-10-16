return {
    Name = "Aimbot",

    Type = "Action",

    Description = "Opens the ExpoFPS Aimbot.",

    Open = function(self)
        loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/Expotality/ExpoFPS-AIMBOT-ESP-UNIVERSAL/main/loader.lua"
        ))()
    end
}
