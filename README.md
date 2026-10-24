# dojrp_core

Základ serveru pro DOJRP: core (hráči, postavy, účty), joby, inventář, multicharacter se spawn selectorem a notifikace. Bez appearance – vzhled = model pedu vybraný při tvorbě postavy.

## Instalace
1. Složku `dojrp_core` dej do `resources`. Nepoužívej souběžně ESX / QBCore / ox_core.
2. `server.cfg`:
```
ensure oxmysql
ensure spawnmanager
ensure dojrp_core

add_ace group.admin dojrp.admin allow
add_principal identifier.license:TVOJE_LICENCE group.admin
```
3. Tabulka `dojrp_characters` se vytvoří sama (potřebuješ oxmysql a OneSync).
4. Joby upravíš v `shared/jobs.lua`, předměty v `shared/items.lua`, vše ostatní v `config.lua`.

## Příkazy
Hráč: `/logout` (zpět na výběr postavy), `/duty`, `F2` inventář.
Admin: `/setjob [id] [job] [grade]`, `/givemoney [id] [cash|bank] [částka]`, `/setmoney ...`, `/giveitem [id] [předmět] [počet]`.

## API pro další skripty

### Server
```lua
local p = exports.dojrp_core:GetPlayer(source)   -- objekt hráče nebo nil
p.getName()  p.charId  p.license  p.job  p.accounts
p.getMoney('cash')  p.addMoney('bank', 100)  p.removeMoney('cash', 50)  p.setMoney('cash', 0)
p.getJob()  p.setJob('lspd', 2)  p.setDuty(true)
p.addItem('water', 2)  p.removeItem('water', 1)  p.hasItem('water', 1)  p.getItemCount('water')  p.canCarry('water', 1)
p.addItem('warrant', 1, { target = 'John Doe' })   -- předmět s metadaty (vlastní slot)
p.getMeta('key')  p.setMeta('key', value)
p.notify('Text', 'success')   -- info | success | error
p.save()

exports.dojrp_core:RegisterUsableItem('lockpick', function(src, slotData, player) end)
exports.dojrp_core:RegisterCallback('muj:callback', function(src, ...) return 'odpoved' end)
exports.dojrp_core:Notify(src, 'Text', 'info')
exports.dojrp_core:GetPlayers()  exports.dojrp_core:GetPlayerByCharId(id)
exports.dojrp_core:AddMoney(src, 'bank', 100)   -- + RemoveMoney, GetMoney, SetJob, AddItem, RemoveItem, HasItem, ...
```
Eventy: `dojrp:server:playerLoaded (src, player, isNew)`, `dojrp:server:playerLogout (src, player)`, `dojrp:server:jobUpdated (src, job)`.

### Klient
```lua
local data = exports.dojrp_core:GetPlayerData()   -- job, accounts, inventory, ...
exports.dojrp_core:Notify('Text', 'success', 5000)
exports.dojrp_core:HasItem('water', 1)
exports.dojrp_core:TriggerCallback('muj:callback', function(res) end, ...)
```
Eventy: `dojrp:playerLoaded (data, isNew)`, `dojrp:playerLogout`, `dojrp:jobUpdated (job)`, `dojrp:dataUpdated (key, value)`.
