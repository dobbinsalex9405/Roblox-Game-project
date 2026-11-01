--!strict
-- Hatchery Heist client start-up. UI arrives with M2 (gameplay) and M5 (shop and odds screen).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreClient = require(ReplicatedStorage.CoreClient.CoreClient)

CoreClient.start()
