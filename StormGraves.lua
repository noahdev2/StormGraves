--[[
    First Release By Storm Team (Raau,Martin) @ 14.Nov.2020    
]]

if Player.CharName ~= "Graves" then return end

require("common.log")
module("Storm Graves", package.seeall, log.setup)

local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs

local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell

---@type TargetSelector
local TS = _G.Libs.TargetSelector()
local Graves = {}

local spells = {
    Q = Spell.Skillshot({
        Slot = Enums.SpellSlots.Q,
        Range = 925,
        Radius = 50,
        Delay = 0.25,
        Speed = 2000,
        Collisions = { Wall = true, WindWall = true },
        Type = "Linear",
        UseHitbox = true
    }),
    W = Spell.Skillshot({
        Slot = Enums.SpellSlots.W,
        Range = 950,
        Radius = 250,
        Delay = 0.25,
        Type = "Circular",
        UseHitbox = true
    }),
    E = Spell.Skillshot({
        Slot = Enums.SpellSlots.E,
        Range = 425,
        Delay = 0
    }),
    R = Spell.Skillshot({
        Slot = Enums.SpellSlots.R,
        Range = 1000,
        Radius = 100,
        Delay = 0.25,
        Speed = 2100,
        Collisions = {WindWall = true },
        Type = "Linear",
        UseHitbox = true
    }),
}

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end


function Graves.IsEnabledAndReady(spell, mode)
    return Menu.Get(mode .. ".Use"..spell) and spells[spell]:IsReady()
end
local lastTick = 0
function Graves.OnTick()    
    if not GameIsAvailable() then return end 

    local gameTime = Game.GetTime()
    if gameTime < (lastTick + 0.25) then return end
    lastTick = gameTime    

    if Graves.Auto() then return end
    if not Orbwalker.CanCast() then return end

    local ModeToExecute = Graves[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end
function Graves.OnDraw() 
    local playerPos = Player.Position
    local pRange = Orbwalker.GetTrueAutoAttackRange(Player)   
    

    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..k..".Enabled", true) then
            Renderer.DrawCircle3D(playerPos, v.Range, 30, 2, Menu.Get("Drawing."..k..".Color")) 
        end
    end
end

function Graves.GetTargets(range)
    return {TS:GetTarget(range, true)}
end

function Graves.ComboLogic(mode)
    if Graves.IsEnabledAndReady("Q", mode) then
        local qChance = Menu.Get(mode .. ".ChanceQ")
        for k, qTarget in ipairs(Graves.GetTargets(spells.Q.Range)) do
            if spells.Q:CastOnHitChance(qTarget, qChance) then
                return
            end
        end
    end
    if Graves.IsEnabledAndReady("W", mode) then
        local wChance = Menu.Get(mode .. ".ChanceW")
        for k, wTarget in ipairs(Graves.GetTargets(spells.W.Range)) do
            if spells.W:CastOnHitChance(wTarget, wChance) then
                return
            end
        end
    end
    if Graves.IsEnabledAndReady("R", mode) then
        local rChance = Menu.Get(mode .. ".ChanceR")
        local dmg = Graves.Rdmg()
        for k, rTarget in ipairs(Graves.GetTargets(spells.R.Range)) do
            local rDmg = DmgLib.CalculatePhysicalDamage(Player, rTarget, dmg)
            local ksHealth = spells.R:GetKillstealHealth(rTarget)
            
            if  rDmg > ksHealth and spells.R:CastOnHitChance(rTarget, rChance) then
                return
            end
        end
    end
end
function Graves.Rdmg()
    return (250 + (spells.R:GetLevel() - 1) * 150) + (1.5 * Player.BonusAD)
end
function Graves.Qdmg()
    return (45 + (spells.R:GetLevel() - 1) * 15) + (0.8 * Player.BonusAD)
end
---@param source AIBaseClient
---@param spell SpellCast
function Graves.OnInterruptibleSpell(source, spell, danger, endT, canMove)
    if not (source.IsEnemy and Menu.Get("Misc.IntW") and spells.Q:IsReady() and danger > 2) then return end

    spells.W:CastOnHitChance(source, Enums.HitChance.VeryHigh)
end
---@param _target AttackableUnit
function Graves.OnPostAttack(_target)
    local useEJungle = Menu.Get("Clear.UseEJ")
    local UseEfarm = Menu.Get("Clear.UseE")
    local UseEcombo  = Menu.Get("Combo.UseE")
    local target = _target.AsAI
    local castPos = Renderer.GetMousePos()
    if not (target or Player:GetBuff("gravesbasicattackammo2")) then return end
    
    local mode = Orbwalker.GetMode()
    if target.IsMonster and mode == "Waveclear" and useEJungle then
        if spells.E:IsReady() then spells.E:Cast(castPos)
        end
    end
    if target.IsMinion and mode == "Waveclear" and UseEfarm then
        if spells.E:IsReady() then spells.E:Cast(castPos)
        end
    end
    if target.IsHero and UseEcombo then
        if mode == "Combo" and spells.E:IsReady() then
            spells.E:Cast(castPos)
                return
            end
        end
end
function Graves.Auto() 
    local KSR = Menu.Get("KillSteal.R")
    local KSQ = Menu.Get("KillSteal.Q")
    local rToKill = Menu.Get("Misc.ForceR") 
    if rToKill then 
        for k, rTarget in ipairs(TS:GetTargets(spells.R.Range, true)) do        
            if spells.R:IsReady() and spells.R:CastOnHitChance(rTarget, Enums.HitChance.Medium) then
               return
            end 
       end
    end
    if KSR then 
        for k, rTarget in ipairs(TS:GetTargets(spells.R.Range, true)) do        
             local rDmg = DmgLib.CalculatePhysicalDamage(Player, rTarget, Graves.Rdmg())
             local ksHealth = spells.R:GetKillstealHealth(rTarget)
             if rDmg > ksHealth and  spells.R:CastOnHitChance(rTarget, Enums.HitChance.High) then
                return
             end 
        end
    end
    if KSQ then 
        for k, QTarget in ipairs(TS:GetTargets(spells.Q.Range, true)) do        
             local rDmg = DmgLib.CalculatePhysicalDamage(Player, QTarget, Graves.Qdmg())
             local ksHealth = spells.Q:GetKillstealHealth(QTarget)
             if rDmg > ksHealth and  spells.Q:CastOnHitChance(QTarget, Enums.HitChance.High) then
                return
             end 
        end
    end
end   


function Graves.Combo()  Graves.ComboLogic("Combo")  end
function Graves.Waveclear()
    local usejQ = Menu.Get("Clear.UseQJ")
    local farmQ = Menu.Get("Clear.UseQ")
        for k, v in pairs(ObjManager.Get("neutral", "minions")) do
            local minion = v.AsAI
            local minionInRange = spells.Q:IsInRange(minion)
            if minionInRange and minion.IsMonster and usejQ and minion.IsTargetable then
                if spells.Q:IsReady() then spells.Q:CastOnHitChance(minion,Enums.HitChance.Low)
                    return
                end     
            end                  
        end
        for k, v in pairs(ObjManager.Get("enemy", "minions")) do
            local minion = v.AsAI
            local minionInRange = spells.Q:IsInRange(minion)
            if minionInRange and minion.IsTargetable and farmQ then
                if spells.Q:IsReady() then spells.Q:CastOnHitChance(minion,Enums.HitChance.Low)
                    return
                end     
            end                  
        end
        
end


function Graves.LoadMenu()

    Menu.RegisterMenu("StormGraves", "Storm Graves", function()
        Menu.ColumnLayout("cols", "cols", 1, true, function()
            Menu.ColoredText("Combo", 0xFFD700FF, true)
            Menu.Checkbox("Combo.UseQ",   "Use [Q]", true) 
            Menu.Slider("Combo.ChanceQ", "HitChance [Q]", 0.7, 0, 1, 0.05)   
            Menu.Checkbox("Combo.UseW",   "Use [W]", true)
            Menu.Slider("Combo.ChanceW", "HitChance [W]", 0.7, 0, 1, 0.05)   
            Menu.Checkbox("Combo.UseE",   "Use [E]", true)
            Menu.Checkbox("Combo.UseR",   "Use [R] when killable", true)
            Menu.Slider("Combo.ChanceR", "HitChance [R]", 0.7, 0, 1, 0.05)  
        end)
        Menu.Separator()
        Menu.ColoredText("Jungle", 0xFFD700FF, true)
        Menu.Checkbox("Clear.UseQJ",   "Use [Q] Jungle", true) 
        Menu.Checkbox("Clear.UseEJ",   "Use [E] Jungle", true) 
        Menu.ColoredText("Lane", 0xFFD700FF, true)
        Menu.Checkbox("Clear.UseQ",   "Use [Q] Lane", true) 
        Menu.Checkbox("Clear.UseE",   "Use [E] Lane", false) 
        Menu.Separator()

        Menu.ColoredText("KillSteal Options", 0xFFD700FF, true)
        Menu.Checkbox("KillSteal.R", "Use [R] to KS", true)     
        Menu.Checkbox("KillSteal.Q", "Use [Q] to KS", true)    
        Menu.Separator()

        Menu.ColoredText("Misc Options", 0xFFD700FF, true)      
        Menu.Checkbox("Misc.IntW", "Use [W] Interrupt", true)   
        Menu.Keybind("Misc.ForceR", "Force [R] Key", string.byte('T'))     
        Menu.Separator()

        Menu.ColoredText("Draw Options", 0xFFD700FF, true)
        Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range")
        Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0x118AB2FF)    
        Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range")
        Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x118AB2FF)  
        Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range")
        Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)    
        Menu.Checkbox("Drawing.R.Enabled",   "Draw [R] Range")
        Menu.ColorPicker("Drawing.R.Color", "Draw [R] Color", 0x118AB2FF)     
    end)     
end

function OnLoad()
    Graves.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Graves[eventName] then
            EventManager.RegisterCallback(eventId, Graves[eventName])
        end
    end    
    return true
end