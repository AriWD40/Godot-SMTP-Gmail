# Godot-SMTP-Gmail

Important: if you want to use this with a Gmail account, you have to turn on "Access for less secure apps", you will find detailed tutorials elsewhere. Please don't use your own personal Gmail account for this, it's probably safe, but lets try and be on the safe side, ok?

This is an overhaul of an existing project by the username Burst (Last active 2018), with added SSL protection and port to Godot 3.2. You can find the original source code here https://godotforums.org/discussion/20317/smtp-client-script-sharing-with-you. I will also add the original code here for safekeeping and posterity.

I got frustrated as there had been many requests for an email capability in Godot, and after a very deep google dive, I finally found one. Although it didn't work at all, I managed to rewrite it for Gmail and adapt it to Godot 3.2. I hope this helps somebody, like me, looking at thread after thread of "it can't be done". 

In order to rewrite it, I familiarized myself with the SMTP protocol and its return codes, as the original code was not functional with Gmail. If you wish to learn about SMTP return codes yourself (perhaps you want to make this work for your own server), visit https://en.wikipedia.org/wiki/List_of_SMTP_server_return_codes and especially https://tools.ietf.org/html/rfc788.

I also had to study the SSL standard, and Godots implementation of it. I have not yet mastered the SSL, but got advice and help from Bojidar Marinov, a Godot developer, found on the Godot Discord server and on github: https://github.com/bojidar-bg. His help was invaluable, as I could not find adequate documentation in Godots Docs pages. Many thanks, Bojidar Marinov!

I have added a few comments in the code, but please contact me for further explanaitions, though I won't promise how well I'll remember any of this if a long time has passed. Find me on Discord, username: Mosfet.

