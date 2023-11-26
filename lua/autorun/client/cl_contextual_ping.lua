local PING_ICON = Material("vgui/crosshair043.png")

local ping_entities_all = {}
local ping_entities_detective = {}
local ping_entities_traitor = {}

local ping_ttt_ragdolls = {}

local PING_INNOCENT = Color(26, 255, 26, 255)
local PING_TRAITOR = Color(255, 26, 26, 255)
local PING_DETECTIVE = Color(26, 26, 255, 255)

local PING_ALL = KEY_T
local PING_TEAM = KEY_B

local ping_on_cooldown = false

--[[---------------------------------------------------------
    Ternary statement - fif
-----------------------------------------------------------]]
local function fif(condition, if_true, if_false)
    if condition then return if_true else return if_false end
end

local isTTT = fif(engine.ActiveGamemode() == "terrortown", true, false)

--[[---------------------------------------------------------
    Sends what the player is looking at to the server
    - Either a location or an entity
-----------------------------------------------------------]]
local function PingLocation(isTeam)
    if ping_on_cooldown == true then return end

    local ply = LocalPlayer()
    local eye = ply:GetEyeTrace()
    local pingLoc = eye.HitPos
    local pingEnt = eye.Entity

    if !ply:Alive() then return end

    if isTTT then
        if ply:IsSpec() then return end
    end

    local validEntity = false
    local requestName = "contextual_ping_"
    requestName = requestName .. fif(isTTT == true and isTeam == true, "team", "all")

    if IsValid(pingEnt) then
        if pingEnt:IsPlayer() or pingEnt:IsNPC() or pingEnt:IsWeapon() or pingEnt:IsRagdoll() or pingEnt:IsNextBot() then
            validEntity = true
        end
    end

    if validEntity then
        requestName = requestName .. "_entity_sv"

        net.Start(requestName)
            net.WriteEntity(pingEnt)
        net.SendToServer()
    else
        requestName = requestName .. "_location_sv"

        net.Start(requestName)
            net.WriteVector(pingLoc)
        net.SendToServer()
    end

    ping_on_cooldown = true
    timer.Create("ContextualPingCooldown" .. ply:UserID(), 1, 1, function()
        ping_on_cooldown = false
    end)
end

--[[---------------------------------------------------------
    Sends what the player is looking at but only to their team
-----------------------------------------------------------]]
local function PingTeam()
    PingLocation(true)
end

--[[---------------------------------------------------------
    Key bindings for pinging to all players or just players
    in the users team
-----------------------------------------------------------]]
concommand.Add("contextual_ping_all", PingLocation)
concommand.Add("contextual_ping_team", PingTeam)
hook.Add("PlayerButtonDown", "ContextualPingButtonDown", function(ply, button)
    if button == PING_ALL and !input.LookupBinding("contextual_ping_all", true) then
        PingLocation()
    elseif button == PING_TEAM and !input.LookupBinding("contextual_ping_team", true) then
        PingTeam()
    end
end)

--[[---------------------------------------------------------
    Draws the ping icon on the screen
-----------------------------------------------------------]]
local function DrawPing(pingLocaton, pingPly, isTeam)
    local offScreen = {
        above = pingLocaton.y < 0,
        below = pingLocaton.y > ScrH(),
        right = pingLocaton.x > ScrW(),
        left = pingLocaton.x < 0
    }

    pingLocaton.x = math.Clamp(pingLocaton.x, 0, ScrW())
    pingLocaton.y = math.Clamp(pingLocaton.y, 0, ScrH())

    local wh = 32
    surface.SetMaterial(PING_ICON)

    local pingColour = PING_INNOCENT
    if isTTT then
        if isTeam == true and pingPly:GetRole() == ROLE_TRAITOR then
            pingColour = PING_TRAITOR
        elseif pingPly:GetRole() == ROLE_DETECTIVE then
            pingColour = PING_DETECTIVE
        end
    end

    surface.SetDrawColor(pingColour)
    if !offScreen.above and !offScreen.below and !offScreen.right and !offScreen.left then
        surface.DrawTexturedRect(pingLocaton.x - wh, pingLocaton.y - wh, 64, 64)

        surface.SetFont("ChatFont")
        local plyNick = pingPly:Nick()
        local ts = surface.GetTextSize(plyNick)

        surface.SetTextColor(pingColour)
        surface.SetTextPos(pingLocaton.x - (ts / 2), pingLocaton.y - (wh * 1.3))
        surface.DrawText(plyNick)
    else
        surface.DrawTexturedRect(pingLocaton.x - (offScreen.right and 64 or 0), pingLocaton.y - (offScreen.below and 64 or 0), 64, 64)
    end
end

--[[---------------------------------------------------------
    Used to ping at a specific location when the player who
    sent the ping is not looking at an entity
-----------------------------------------------------------]]
local function PingAtLocation(pingLoc, pingPly, isTeam)
    if IsValid(pingPly) then
        local pingLocScr = pingLoc

        cam.Start3D()
            pingLocScr = pingLocScr:ToScreen()
        cam.End3D()

        DrawPing(pingLocScr, pingPly, isTeam)
    end
end

--[[---------------------------------------------------------
    Used to ping at a specific location when the player who
    sent the ping is looking at an entity
-----------------------------------------------------------]]
local function PingAtEntity(pingEnt, pingPly, isTeam)
    if IsValid(pingPly) then
        local userId = pingPly:UserID()
        local pingLocScr

        if IsValid(pingEnt) then
            if pingEnt != LocalPlayer() then
                pingLocScr = pingEnt:GetPos()

                if !pingEnt:IsWeapon() then
                    local head = pingEnt:LookupBone("ValveBiped.Bip01_Head1")
                    if(head) then
                        local headPos = pingEnt:GetBonePosition(head)
                        if(headPos == pingLocScr) then
                            headPos = pingEnt:GetBoneMatrix(head):GetTranslation()
                        end
                        pingLocScr = headPos
                    else
                        if pingEnt:IsPlayer() then
                            pingLocScr = pingLocScr + (pingEnt:Crouching() and Vector(0, 0, 28) or Vector(0, 0, 64))
                        elseif pingEnt:IsNPC() or pingEnt:IsNextBot() then
                            pingLocScr = pingLocScr + Vector(0, 0, 64)
                        end
                    end
                end

                PingAtLocation(pingLocScr, pingPly, isTeam)
            end
        end
    end
end

--[[---------------------------------------------------------
    net.Receive function when a location ping is sent to all players
-----------------------------------------------------------]]
local function PingAllLocation()
    local pingLoc = net.ReadVector()
    local pingPly = net.ReadEntity()

    if IsValid(pingPly) then
        local userId = pingPly:UserID()
        local pingUserNick = pingPly:Nick()

        ping_entities_all[userId] = nil
        ping_entities_detective[userId] = nil

        hook.Remove("HUDPaint", "ContextualPingIncoming" .. userId)

        hook.Add("HUDPaint", "ContextualPingIncoming" .. userId, function()
            PingAtLocation(pingLoc, pingPly, false)
        end)

        if pingPly == LocalPlayer() then
            surface.PlaySound("garrysmod/ui_click.wav" )
        end

        timer.Create("ContextualPing" .. userId, 10, 1, function()
            hook.Remove("HUDPaint", "ContextualPingIncoming" .. userId)
        end)
    end
end

--[[---------------------------------------------------------
    net.Receive function when an entity ping is sent to all players
-----------------------------------------------------------]]
local function PingAllEntity()
    local pingEnt = net.ReadEntity()
    local pingPly = net.ReadEntity()

    if IsValid(pingPly) then
        local userId = pingPly:UserID()
        local pingUserNick = pingPly:Nick()

        if isTTT then
            if pingPly:GetRole() == ROLE_DETECTIVE then
                ping_entities_detective[userId] = pingEnt
            else
                ping_entities_all[userId] = pingEnt
            end
        else
            ping_entities_all[userId] = pingEnt
        end

        hook.Remove("HUDPaint", "ContextualPingIncoming" .. userId)

        if ping_entities_all[userId] != LocalPlayer() then
            hook.Add("HUDPaint", "ContextualPingIncoming" .. userId, function()
                if IsValid(ping_entities_detective[userId]) and isTTT then
                    PingAtEntity(ping_entities_detective[userId], pingPly, false)
                elseif IsValid(ping_entities_all[userId]) then
                    PingAtEntity(ping_entities_all[userId], pingPly, false)
                end
            end)
        end

        if pingPly == LocalPlayer() then
            surface.PlaySound("garrysmod/ui_click.wav" )
        end

        timer.Create("ContextualPing" .. userId, 10, 1, function()
            hook.Remove("HUDPaint", "ContextualPingIncoming" .. userId)
            hook.Remove("HUDPaint", "ContextualPingDrawHalo"  .. userId)
            ping_entities_all[userId] = nil
            ping_entities_detective[userId] = nil
        end)
    end
end

net.Receive("contextual_ping_all_location_cl", PingAllLocation)
net.Receive("contextual_ping_all_entity_cl", PingAllEntity)

--[[---------------------------------------------------------
    net.Receive function when a location ping is sent to the
    players team
-----------------------------------------------------------]]
local function PingTeamLocation()
    local pingLoc = net.ReadVector()
    local pingPly = net.ReadEntity()

    if IsValid(pingPly) then
        if !isTTT then
            PingAllLocation()
        else
            if pingPly:GetRole() != ROLE_TRAITOR then
                PingAllLocation()
            else
                local userId = pingPly:UserID()
                local pingUserNick = pingPly:Nick()

                ping_entities_traitor[userId] = nil

                hook.Remove("HUDPaint", "ContextualPingIncomingTeam" .. userId)

                hook.Add("HUDPaint", "ContextualPingIncomingTeam" .. userId, function()
                    PingAtLocation(pingLoc, pingPly, true)
                end)

                if pingPly == LocalPlayer() then
                    surface.PlaySound("garrysmod/ui_click.wav" )
                end

                timer.Create("ContextualPingTeam" .. userId, 10, 1, function()
                    hook.Remove("HUDPaint", "ContextualPingIncomingTeam" .. userId)
                end)
            end
        end
    end
end

--[[---------------------------------------------------------
    net.Receive function when an entity ping is sent to the
    players team
-----------------------------------------------------------]]
local function PingTeamEntity()
    local pingEnt = net.ReadEntity()
    local pingPly = net.ReadEntity()

    if IsValid(pingPly) then
        if !isTTT then
            PingAllEntity()
        else
            if pingPly:GetRole() != ROLE_TRAITOR then
                PingAllEntity()
            else
                local userId = pingPly:UserID()
                local pingUserNick = pingPly:Nick()

                ping_entities_traitor[userId] = pingEnt

                hook.Remove("HUDPaint", "ContextualPingIncomingTeam" .. userId)

                if ping_entities_traitor[userId] != LocalPlayer() then
                    hook.Add("HUDPaint", "ContextualPingIncomingTeam" .. userId, function()
                        if IsValid(ping_entities_traitor[userId]) then
                            PingAtEntity(ping_entities_traitor[userId], pingPly, true)
                        end
                    end)
                end

                if pingPly == LocalPlayer() then
                    surface.PlaySound("garrysmod/ui_click.wav" )
                end

                timer.Create("ContextualPingTeam" .. userId, 10, 1, function()
                    hook.Remove("HUDPaint", "ContextualPingIncomingTeam" .. userId)
                    hook.Remove("HUDPaint", "ContextualPingDrawHaloTeam"  .. userId)
                    ping_entities_traitor[userId] = nil
                end)
            end
        end
    end
end

net.Receive("contextual_ping_team_location_cl", PingTeamLocation)
net.Receive("contextual_ping_team_entity_cl", PingTeamEntity)

--[[---------------------------------------------------------
    When an entity is killed (i.e. player or npc) then
    draw the ping / halo on their ragdoll entity instead
-----------------------------------------------------------]]
local function ReplaceEntityWithRagdoll(ent, ragdoll)
    -- Check if the entity killed was pinged to all players
    for k, v in pairs(ping_entities_all) do
        if v == ent then
            ping_entities_all[k] = ragdoll
        end
    end

    -- Check if the entity killed was pinged by a detective
    for k, v in pairs(ping_entities_detective) do
        if v == ent then
            ping_entities_detective[k] = ragdoll
        end
    end

    -- Check if the entity killed was pinged to the players team
    for k, v in pairs(ping_entities_traitor) do
        if v == ent then
            ping_entities_traitor[k] = ragdoll
        end
    end
end

hook.Add("CreateClientsideRagdoll", "ContextualPingClientRagdoll", ReplaceEntityWithRagdoll)
net.Receive("contextual_ping_entity_ragdoll_cl", function()
    local ent = net.ReadEntity()
    local id = net.ReadUInt(13)
    local rag = Entity(id)

    if rag and rag:IsValid() then
        ReplaceEntityWithRagdoll(ent, rag)
    else
        ping_ttt_ragdolls[id] = ent
    end
end)

if isTTT then
    hook.Add("OnEntityCreated", "ContextualPingEntityCreated", function(ent)
        if (ent:GetClass() == "prop_ragdoll") then
            for k, v in pairs(ping_ttt_ragdolls) do
                if k == ent:EntIndex() then
                    ReplaceEntityWithRagdoll(v, ent)
                    ping_ttt_ragdolls[k] = nil
                end
            end
        end
    end)
end
