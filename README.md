# GroupPolicy-WindowsLAPS

Please download these 2 KBs

-https://www.catalog.update.microsoft.com/Search.aspx?q=KB5025230

-https://www.catalog.update.microsoft.com/Search.aspx?q=KB5025229

and rename them to KB5025230.msu and KB5025229.msu respectively, and place inside the GroupPolicy-WindowsLAPS folder (or same dir as the script itself)

They are over the 25MB limit on github and is therefore not supplied here.


--

How to: Place the GroupPolicy-WindowsLAPS folder anywhere, and run the .ps1 script as admin.


Please note this version is intended for environments with a high probability of being unpatched, as it contains substantial code intended for self-healing/auto-patching
You can scrap 70% of the code if the environment is already updated with the corresponding KBs.
