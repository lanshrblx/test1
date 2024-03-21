
repeat wait() until game:IsLoaded() 

-- Services

local HTTPService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Values

local Token = "4bb22d00-28aa-40ab-bc65-c651d77c3ccd"

local Items
local WithdrawQueue = {
    ["RoFlipBot"] = true
}

-- Links

local TradeRemotes = ReplicatedStorage.Trade

-- Functions

local function ChatSay(Message)

    ReplicatedStorage:WaitForChild("DefaultChatSystemChatEvents").SayMessageRequest:FireServer(Message,"normalchat")

end

local function deepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            v = deepCopy(v)
        end
        copy[k] = v
    end
    return copy
end

local function GetItemNameById(Id)

    for _,Item in pairs(Items) do

        if Item.ID == Id then

            return Item.ItemName

        end

    end

end

local function GetItemIdByName(Name)

    for _,Item in pairs(Items) do

        if Item.ItemName == Name then

            return Item.ID

        end

    end

end

local function AddItems(ID : number, Items : table)

    HTTPService:RequestAsync(

        {

            Method = "POST",
            Url = "https://roflip.org/api/public/user/"..ID.."/item/addAll",
            Headers = {
                ["X-API-KEY"] = Token,
                ["Content-Type"] = "application/json"
            },

            Body = HTTPService:JSONEncode({
                items_ids = Items
            })

        }

    )

end

local function UpdateWithdrawQueue()

    local Request = HTTPService:RequestAsync(

        {

            Method = "GET",
            Url = "https://roflip.org/api/public/withdrawal/getAllIncoming",
            Headers = {
                ["X-API-KEY"] = Token
            }

        }

    )

    for _, Data in pairs(HTTPService:JSONDecode(Request.Body)) do

        local RoFlipId = tostring(Data["user"]["id"])

        if WithdrawQueue[RoFlipId] == nil then

            WithdrawQueue[RoFlipId] = {}

        end

        for _, Item in pairs(Data["user_items"]) do

            local ItemId = Item["item_id"]

            if WithdrawQueue[RoFlipId][ItemId] == nil then

                WithdrawQueue[RoFlipId][ItemId] = 1

            else

                WithdrawQueue[RoFlipId][ItemId] += 1

            end

        end

    end

end

local function GetLocalIdFromUserId(UserId)

    local LocalId = HTTPService:GetAsync("https://roflip.org/api/v1/user/getByRolboxId/"..UserId)

    if LocalId ~= "" then

        local Raw = HTTPService:JSONDecode(LocalId)

        return tonumber(Raw["id"])

    end

    return 4

end

local function GetTypeFromId(Id) 

    for _, Item in pairs(Items) do

        if Item.ID == Id then

            if Item.Type == "Weapon" then

                return "Weapons"

            elseif Item.Type == "Pet" then

                return "Pets"

            end

        end

    end

end

local function CountValuesInTable(Table, Value)

    local n = 0

    for _, Value_ in pairs(Table) do

        if Value_ == Value then

            n += 1

        end

    end

    return n

end

-- Lets go!

ChatSay("RoFlip | Bot is now starting...")

_G.RoFlipBotUpdate = true

wait(2)

_G.RoFlipBotUpdate = false

Items = HTTPService:JSONDecode(HTTPService:GetAsync("https://raw.githubusercontent.com/lanshrblx/test1/main/items.json"))

-- After initialization

local CurrentTradeData = {

    Trading = false,
    User = nil,
    RoflipId = nil,
    Items = {},
    ToRemove = {},
    StartTick = nil

}

-- Connections

local Connections = {}

Connections[1] = TradeRemotes.DeclineTrade.OnClientEvent:Connect(function()

    if CurrentTradeData.Trading then

        CurrentTradeData = {

            Trading = false,
            User = nil,
            RoflipId = nil,
            Items = {},
            ToRemove = {},
            StartTick = nil

        }

    end

    ChatSay("RoFlip | Ready for trade")

end)

Connections[2] = TradeRemotes.UpdateTrade.OnClientEvent:Connect(function(Trade)

    local Items_ = {}

    for _, Item in pairs(Trade["Player1"].Offer) do

        local ID = GetItemIdByName(Item[1])

        if ID then

            local Amount = Item[2]

            if Amount <= 100 then

                for i=1, Amount do

                    table.insert(Items_,ID)

                end

            else

                ChatSay("RoFlip | Bot doesn't accept amounts more than 100")

                TradeRemotes.DeclineTrade:FireServer()

                return

            end

        else

            ChatSay("RoFlip | Bot doesn't accept "..Item[1])

            TradeRemotes.DeclineTrade:FireServer()

            return

        end

    end

    CurrentTradeData.Items = Items_
end)

local AcceptTradeCooldown = false

Connections[3] = TradeRemotes.AcceptTrade.OnClientEvent:Connect(function()

    if CurrentTradeData.RoflipId ~= nil and not AcceptTradeCooldown then

        AcceptTradeCooldown = true

        TradeRemotes.AcceptTrade:FireServer()

        print(HTTPService:JSONEncode(CurrentTradeData.Items))

        AddItems(CurrentTradeData.RoflipId, CurrentTradeData.Items)
        
        for _,Index in pairs(CurrentTradeData.ToRemove) do
            
            WithdrawQueue[tostring(CurrentTradeData.RoflipId)][Index] = nil
            
        end

        wait(5)

        CurrentTradeData = {

            Trading = false,
            User = nil,
            RoflipId = nil,
            Items = {},
            ToRemove = {},
            StartTick = nil

        }

        ChatSay("RoFlip | Ready for trade")

        AcceptTradeCooldown = false

    end

end)

TradeRemotes.SendRequest.OnClientInvoke = function(Sender)

    task.spawn(function()

        if CurrentTradeData.Trading == false then

            -- Finding user

            local RoFlipId = GetLocalIdFromUserId(Sender.UserId)

            if RoFlipId == nil then

                --TradeRemotes.CancelRequest:FireServer()

                ChatSay("RoFlip | Can't find "..Sender.Name.."'s RoFlip account")

                return

            end

            ChatSay("RoFlip | Trading with "..Sender.Name.. " (ID:"..RoFlipId..")")

            -- Binding user

            CurrentTradeData.Trading = true
            CurrentTradeData.User = Sender
            CurrentTradeData.RoflipId = RoFlipId
            CurrentTradeData.StartTick = tick()

            TradeRemotes.AcceptRequest:FireServer()

            -- Withrawing items

            local ToWithdraw = WithdrawQueue[tostring(RoFlipId)]

            if ToWithdraw ~= nil and ToWithdraw ~= {} then
                
                local WithdrawCopy = deepCopy(ToWithdraw)

                local TakedIds = 0

                for Index, Value in pairs(WithdrawCopy) do

                    if TakedIds < 4 then

                        TakedIds += 1

                        for _=1, Value do

                            TradeRemotes.OfferItem:FireServer(
                                GetItemNameById(Index),
                                GetTypeFromId(Index)
                            )

                        end
                        

                        WithdrawCopy[Index] = nil
                        table.insert(CurrentTradeData.ToRemove, Index)

                    else

                        break

                    end

                end

            end

        end

    end)

    return require(ReplicatedStorage.Modules.TradeModule).RequestsEnabled

end

ChatSay("RoFlip | Bot started")

-- Anti Afk

Connections[4] = game:GetService("Players").LocalPlayer.Idled:connect(function()

    game:GetService("VirtualUser"):ClickButton2(Vector2.new())

end)

-- Soft Updater

spawn(function()

    while wait(1) do

        if _G.RoFlipBotUpdate == true then

            TradeRemotes.SendRequest.OnClientInvoke = nil

            for _, Connection in pairs(Connections) do

                Connection:Disconnect()

            end

            break

        else

            UpdateWithdrawQueue()
            
            if CurrentTradeData.Trading == true then
                
                if tick() - CurrentTradeData.StartTick >= 60 then
                    
                    TradeRemotes.DeclineTrade:FireServer()
                    
                    ChatSay("RoFlip | Trade timed out")
                    
                    CurrentTradeData = {

                        Trading = false,
                        User = nil,
                        RoflipId = nil,
                        Items = {},
                        ToRemove = {},
                        StartTick = nil

                    }
                    
                    ChatSay("RoFlip | Ready for trade")
                    
                end
                
            end

        end

    end

end)
