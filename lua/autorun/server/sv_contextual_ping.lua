-- All
util.AddNetworkString("contextual_ping_all_location_sv")
util.AddNetworkString("contextual_ping_all_entity_sv")
util.AddNetworkString("contextual_ping_all_location_cl")
util.AddNetworkString("contextual_ping_all_entity_cl")

-- Team
util.AddNetworkString("contextual_ping_team_location_sv")
util.AddNetworkString("contextual_ping_team_entity_sv")
util.AddNetworkString("contextual_ping_team_location_cl")
util.AddNetworkString("contextual_ping_team_entity_cl")

--Ragdoll
util.AddNetworkString("contextual_ping_entity_ragdoll_cl")

--[[---------------------------------------------------------
    Utility function to get a description of the item pinged at
-----------------------------------------------------------]]
function GetEntityDescription(ent)
    local description

    if ent:IsPlayer() then
        description = ent:Nick()
    elseif ent:IsWeapon() then
        description = "a Weapon"
    elseif ent:IsRagdoll() then
        if engine.ActiveGamemode() == "terrortown" then
            if CORPSE.GetFound(ent, false) then
                description = "the body of " .. CORPSE.GetPlayerNick(ent, "a Terrorist")
            else
                description = "an unidentified Body"
            end
        else
            description = "a Ragdoll"
        end
    elseif ent:IsNPC() then
        description = "an NPC"
    elseif ent:IsNextBot() then
        description = ent:GetName()
    else
        description = "Something"
    end
    return description
end

--[[---------------------------------------------------------
    net.Receive function to send a location ping to
    all other players
-----------------------------------------------------------]]
net.Receive("contextual_ping_all_location_sv", function(len, ply)
    local vec = net.ReadVector()
        
    net.Start("contextual_ping_all_location_cl")
        net.WriteVector(vec)
        net.WriteEntity(ply)
    net.Broadcast()
end)

--[[---------------------------------------------------------
    net.Receive function to send an entity ping to
    all other players
-----------------------------------------------------------]]
net.Receive("contextual_ping_all_entity_sv", function(len, ply)
    local ent = net.ReadEntity()

    net.Start("contextual_ping_all_entity_cl")
        net.WriteEntity(ent)
        net.WriteEntity(ply)
    net.Broadcast()
end)

--[[---------------------------------------------------------
    net.Receive function to send a location ping to
    all other players on the traitor team
-----------------------------------------------------------]]
net.Receive("contextual_ping_team_location_sv", function(len, ply)
    local vec = net.ReadVector()
    local recipients = player.GetHumans()
    local traitors = {}

    if ply:GetRole() == ROLE_TRAITOR then
        for k, v in pairs(recipients) do
            if v:GetRole() == ROLE_TRAITOR then
                table.insert(traitors, v)
            end
        end

        net.Start("contextual_ping_team_location_cl")
            net.WriteVector(vec)
            net.WriteEntity(ply)
        net.Send(traitors)
    else
        net.Start("contextual_ping_all_location_cl")
            net.WriteVector(vec)
            net.WriteEntity(ply)
        net.Broadcast()
    end
end)

--[[---------------------------------------------------------
    net.Receive function to send an entity ping to
    all other players on the traitor team
-----------------------------------------------------------]]
net.Receive("contextual_ping_team_entity_sv", function(len, ply)
    local ent = net.ReadEntity()
    local recipients = player.GetHumans()
    local traitors = {}

    if ply:GetRole() == ROLE_TRAITOR then
        for k, v in pairs(recipients) do
            if v:GetRole() == ROLE_TRAITOR then
                table.insert(traitors, v)
            end
        end

        net.Start("contextual_ping_team_entity_cl")
            net.WriteEntity(ent)
            net.WriteEntity(ply)
        net.Send(traitors)
    else

        net.Start("contextual_ping_all_entity_cl")
            net.WriteEntity(ent)
            net.WriteEntity(ply)
        net.Broadcast()
    end
end)

--[[---------------------------------------------------------
    When an entity is killed (i.e. player or npc) then
    draw the ping / halo on their ragdoll entity instead
-----------------------------------------------------------]]
hook.Add("CreateEntityRagdoll", "ContextualPingEntityRagdoll", function(ent, ragdoll)
    net.Start("contextual_ping_entity_ragdoll_cl")
        net.WriteEntity(ent)
        net.WriteEntity(ragdoll)
    net.Broadcast()
end)

if engine.ActiveGamemode() == "terrortown" then
    hook.Add("TTTOnCorpseCreated", "ContextualPingEntityRagdoll", function(corpse, ply)
        local id = corpse:EntIndex()

        net.Start("contextual_ping_entity_ragdoll_cl")
            net.WriteEntity(ply)
            net.WriteUInt(id, 13)
        net.Broadcast()
    end)
end
