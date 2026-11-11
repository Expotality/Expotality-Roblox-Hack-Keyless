return {
    Name = "Gameplay Paused Disabler",

    Type = "Action",

    Description = "Disables the annoying 'Gameplay Paused' Pop up.",

    Open = function(self)
      game:GetService("GuiService"):SetGameplayPausedNotificationEnabled(false)
    end
}
