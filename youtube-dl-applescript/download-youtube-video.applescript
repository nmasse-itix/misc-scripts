set theResponse to display dialog "URL de la vidéo à télécharger ?" default answer "" with icon note buttons {"Annuler", "Continuer"} default button "Continuer"

if (button returned of theResponse) is equal to "Continuer" then
    tell application "Terminal"
        activate
        do script "clear; cd ~/Movies/ && youtube-dl -i --no-playlist \"" & (text returned of theResponse) & "\" ; open ~/Movies/ ; exit"
    end tell
end if
