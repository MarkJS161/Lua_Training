-- lic_type_checking : for check license type is match in our accept
local swapNot = false local data = ""
os.trace("Running %s on '%s'", _VERSION , os.getenv("DEVICE.NAME"))
os.sleep(500)

function loop (n)
  local e, str
  print(string.format("LUA: Hello World, this is the first lua script on AVL3 ... (loops %d, %u)", n, os.clock()))
  print(os.date("LUA: Today is %A, the %d/%m/%Y (%c)"))
  if swapNot then
    e, str = avl.pfal(string.format("MSG.Send.USB,0,\"HEY!!!, %s\"", data))
  else
    e, str = avl.pfal(os.date("MSG.Send.USB,0,\"HEY!!!, today is %A, the %d/%m/%Y (%c) : Please swap your driving license\""))
  end
  print("LUA:", str, e and "= OK" or "= Error")
end

function event (e) -- check, which event coming and do what in that event show or do something
  local ev
  local t = os.clock()
  if e.type == ALARM_SYS_DEVICE_START then
  os.trace("Startup type=%d,%d (%d ms)", e.u_startreason, e.u_starttype, t)
  elseif e.type == ALARM_SYS_ERROR then
  os.trace("Error \"%s\" (%d ms)", e.u_string, t)
  elseif e.type == ALARM_SYS_TIMER then
  os.trace("Timer event %d ... (%d ms)", e.type, t)
  elseif e.type == ALARM_SYS_TRIGGER then
  os.trace("Trigger event %d ... (%d ms)", e.type, t)
  elseif e.type == ALARM_SYS_COUNTER then
  os.trace("Counter event %d ... (%d ms)", e.type, t)
  elseif e.type == ALARM_SYS_SERIALDATA0 then
  os.trace("Serial data \"%.10s...\" (%d bytes) (%d ms)", e.u_recvdata, e.u_recvlen, t)
  ev = avl.pfal(string.format("MSG.Send.USB,0,\"Hello World, This card ID :%s\"", e.u_recvdata))
  data = ""
  check_magnetic_input(e.u_recvdata)
  swapNot = true
  elseif e.type == ALARM_IO_IN then
  os.trace("IO%d changed (%s) (%d ms)", e.idx, e.u_value == 0 and "raising" or "falling", t)
  elseif e.type == ALARM_IO_MOTION_MOVING then
  os.trace("Device moving ... (%d ms)", t)
  elseif e.type == ALARM_IO_MOTION_STANDING then
  os.trace("Device standing ... (%d ms)", t)
  elseif e.type == ALARM_GSM_VOICECALL_INCOMING_RING then
  os.trace("Knocking \"%s\" ... (%d ms)", e.u_callid, t)
  elseif e.type == ALARM_TCP_CLIENT_CONNECTED then
  os.trace("TCP connected \"%s\" ... (%d ms)", e.u_ipadress, t)
  else
  os.trace("Unknown event %d/%d ... (%d ms)", e.type, e.idx, t)
  end
end

function check_magnetic_input (cardInfo)
    local ev
    index = 1
    track_On = 1
    firstDigit = 1
    lastDigit = 0
    length = string.len(cardInfo)
    -- Divide card info to 3 tracks 1: track_name, 2: track_date & license num, 3: Driving License
    while index <= length do
        if string.sub(cardInfo, index, index) == '?' then -- '?' use to divide track
            if string.sub(cardInfo, firstDigit, firstDigit) == '%' or string.sub(cardInfo, index-1, index-1) == '^' then -- TRACK #1 : Driver Name
                track_On = track_On + 1
                lastDigit = lastDigit + index - 1
                lic_track_1 = string.sub(cardInfo, firstDigit, lastDigit)
                print(string.format("TRACK #1 : %s",lic_track_1))
                ev = avl.pfal(string.format("MSG.Send.USB,0,\"TRACK #1 : %s\"",lic_track_1))
                firstDigit = firstDigit + index
            elseif string.sub(cardInfo, firstDigit, firstDigit) == ';' or string.sub(cardInfo, index-1, index-1) == '=' then --- TRACK #2 : ID No. & Day of birth
                track_On = track_On + 1
                lastDigit = (lastDigit * 0) + index -1
                lic_track_2 = string.sub(cardInfo, firstDigit, lastDigit)
                print(string.format("TRACK #2 : %s",lic_track_2))
                ev = avl.pfal(string.format("MSG.Send.USB,0,\"TRACK #2 : %s\"",lic_track_2))
                firstDigit = (firstDigit * 0) + index + 1
            elseif string.sub(cardInfo, firstDigit, firstDigit) == '+' or track_On == 3 then -- TRACK #3 : license No. & info
                lastDigit = (lastDigit * 0) + index - 1
                lic_track_3 = string.sub(cardInfo, firstDigit+1, lastDigit)
                print(string.format("TRACK #3 : %s",lic_track_3))
                ev = avl.pfal(string.format("MSG.Send.USB,0,\"TRACK #3 : %s\"",lic_track_3))
            end
        end
        index = index + 1
    end
    data = ""
    if string.len(lic_track_1) ~= 0 and string.len(lic_track_2) ~= 0 and string.len(lic_track_3) ~= 0 then -- 1 1 1
        data = data..("MSG.Send.USB,0,\"GET ALL 3 TRACKS INSIDE\"")
        getDriverName(lic_track_1)
        getCardDate(lic_track_2)
        getLicType(lic_track_3)
    elseif string.len(lic_track_1) ~= 0 and string.len(lic_track_2) ~= 0 and string.len(lic_track_3) == 0 then -- 1 1 0
        data = data..("MSG.Send.USB,0,\"GET 2 TRACKS INSIDE; MISS TRACK#3\"")
        getDriverName(lic_track_1)
        getCardDate(lic_track_2)
    elseif string.len(lic_track_1) == 0 and string.len(lic_track_2) ~= 0 and string.len(lic_track_3) ~= 0 then -- 0 1 1
        data = data..("MSG.Send.USB,0,\"GET 2 TRACKS INSIDE; MISS TRACK#1\"")
        getCardDate(lic_track_2)
        getLicType(lic_track_3)
    elseif string.len(lic_track_1) ~= 0 and string.len(lic_track_2) == 0 and string.len(lic_track_3) ~= 0 then -- 1 0 1
        data = data..("MSG.Send.USB,0,\"GET 2 TRACKS INSIDE; MISS TRACK#2\"")
        getDriverName(lic_track_1)
        getLicType(lic_track_3)
    elseif string.len(lic_track_1) ~= 0 and string.len(lic_track_2) == 0 and string.len(lic_track_3) == 0 then -- 1 0 0
        data = data..("MSG.Send.USB,0,\"GET ONLY 1 TRACK INSIDE; MISS TRACK# 2 & 3\"")
        getDriverName(lic_track_1)
    elseif string.len(lic_track_1) == 0 and string.len(lic_track_2) ~= 0 and string.len(lic_track_3) == 0 then -- 0 1 0
        data = data..("MSG.Send.USB,0,\"GET ONLY 1 TRACK INSIDE; MISS TRACK# 1 & 3\"")
        getCardDate(lic_track_2)
    elseif string.len(lic_track_1) == 0 and string.len(lic_track_2) == 0 and string.len(lic_track_3) ~= 0 then -- 0 0 1
        data = data..("MSG.Send.USB,0,\"GET ONLY 1 TRACK INSIDE; MISS TRACK# 1 & 2\"")
        getLicType(lic_track_3)
    else -- 0 0 0
        data = data..("MSG.Send.USB,0,\"CANNOT GET ALL TRACKS INSIDE;\"")
    end
end
  
function getDriverName(track_1)
    local evt
    local track_1_len = 0
    local mr = 0 local mss = 0 local mrs = 0
    local hasLast = 0 local firstCh = 0 local lastCh = 0
    firstOrNot = 1
    mr = string.find(track_1, "MR")
    mss = string.find(track_1, "MS")
    mrs = string.find(track_1, "MRS")
    -- find MR., MS., MRS.
    if mr ~= nil then
        title = string.sub(track_1, mr, mr+1)
        track_1_len = track_1_len + mr-2
    elseif mss ~= nil then
        title = string.sub(track_1, mss, mss+1)
        track_1_len = track_1_len + mss-2
    elseif mrs ~= nil then
        title = string.sub(track_1, mrs, mrs+2)
        track_1_len = track_1_len + mrs-2
    else
        -- Unknown is a man, woman, or somethings. 
        data = data.."Unknown Driver Name : Anonymous\n"
        evt = avl.pfal("MSG.Send.USB,0,\"Unknown Driver Name : Anonymous\"")
    end
    print(string.format("Length of name : %d", track_1_len))
    if track_1_len > 0 then
        -- Track #1 is keep driver name information
        -- get one digits from name and change to ascii for compare is a alphabet or not?
        for i = 1, track_1_len, 1 do
            ascDigit = track_1:byte(i)
            ascNext = track_1:byte(i+1)
            -- if current index is not alphabet but next is alphabet keep first index
            if (ascDigit > 90 or ascDigit < 65) and (ascNext <= 90 or ascNext >= 65) then
                firstCh = (firstCh * 0) + i + 1
            elseif (ascDigit <= 90 or ascDigit >= 65) and (ascNext > 90 or ascNext < 65) then -- keep last index, if next index is not alphabet
                lastCh = (lastCh * 0) + i
                -- check in track#1 lastname come before firstname
                if firstOrNot == 1 then
                  lastName = string.sub(track_1, firstCh, lastCh)
                  firstOrNot = firstOrNot + 1
                elseif firstOrNot == 2 then
                  firstName = string.sub(track_1, firstCh, lastCh)
                end
            end
        end
        print(string.format( "The Driver Name: %s.%s %s", title, firstName, lastName))
        data = data..string.format( "The Driver Name: %s.%s %s\n", title, firstName, lastName)
        evt = avl.pfal(string.format("MSG.Send.USB,0,\"The Driver Name: %s.%s %s\"", title, firstName, lastName))
    end
end

function getCardDate(track_2)
    local eve
    local first = 0
    local track_2_len = string.len(track_2)
    local keepdata = {"","","",""} local index = 1
    
    if track_2_len > 1 then
        -- Track #2 is keep date information
        -- Country code of driving license country
        -- ID No. of Driver
        -- The Date of Expiry for to renew card
        -- The Date of Driver Birth 
        for i = 1, track_2_len, 1 do
            if string.sub(track_2,i,i) == ';' then
                first = i+1
            end
            if i == 7 or i == 25 then
                keepdata[index] = string.sub(track_2, first, i)
                first = (first * 0) + i + 1
                index = index + 1
            end

            if string.sub(track_2,i,i) == '=' then
                keepdata[index] = string.sub(track_2, first, i-1)
                if i ~= track_2_len then
                    first = (first * 0) + i + 1
                end
                index = index + 1
            end
        end
        print(string.format("The country code : %s.", keepdata[1]))
        print(string.format("The ID No. : %s, %d.", keepdata[2], string.len(keepdata[2])))
        print(string.format("The Date of Expiry : M:%s-Y:%s.", string.sub(keepdata[3], 3), string.sub(keepdata[3], 1, 2)))
        print(string.format("The Date of Birth : D:%s-M:%s-Y:%s.", string.sub(keepdata[4],7 ), string.sub(keepdata[4], 5, 6), string.sub(keepdata[4], 1, 4)))
        eve = avl.pfal(string.format("MSG.Send.USB,0,\"The country code : %s.\"", keepdata[1]))
        eve = avl.pfal(string.format("MSG.Send.USB,0,\"The ID No. : %s.\"", keepdata[2]))
        eve = avl.pfal(string.format("MSG.Send.USB,0,\"The Date of Expiry : M:%s-Y:%s.\"", string.sub(keepdata[3], 3), string.sub(keepdata[3], 1, 2)))
        eve = avl.pfal(string.format("MSG.Send.USB,0,\"The Date of Birth : D:%s-M:%s-Y:%s.\"", string.sub(keepdata[4], 7), string.sub(keepdata[4], 5, 6), string.sub(keepdata[4], 1, 4)))
    else
        print("No one, can find my card found date.")
        eve = avl.pfal("No one, can find my card found date.")
    end
end

function getLicType(track_3)
    local evt
    local lic_index = {"","","",""}
    local firstIndex = 0 local lastIndex = 0 local trackIndex = 1
    local length = string.len(track_3)
    for digit = 1, length, 1 do
        if string.sub(track_3, digit, digit) == ' ' and string.sub(track_3, digit+1, digit+1) ~= ' ' then
            firstIndex = firstIndex + digit +1
        elseif string.sub(track_3, digit, digit) ~= ' ' and string.sub(track_3, digit+1, digit+1) == ' ' then
            lastIndex = lastIndex + digit
            -- Track #3 is keep driving license information
            -- license type : e.g. 21, 12, 22, 11, 23, etc.
            -- gender of driver : male or female or between them or "2 in 1"?.
            -- license no. : 7~8 digits (XXXXXXX / i.e. 9999958, 0007046, 35711728, 59001720)
            -- location : where release this card? 5 digits maybe postal code
            info = string.sub(track_3, firstIndex, lastIndex)
            lic_index[trackIndex] = string.sub(track_3, firstIndex, lastIndex)
            trackIndex = trackIndex + 1
            firstIndex = firstIndex * 0
            lastIndex = lastIndex * 0
        end
    end
    
    if string.len(lic_index[1]) == 2 then
        -- if license type is match/same 21, 22, 23 : I/O6 is high -> low if swap correct card.
        if lic_index[1] == "21" or lic_index[1] == "22" or lic_index[1] == "23" then
            evt = avl.pfal(string.format("MSG.Send.USB,0,\"OH YEAH!!!, BEST MATCH License type : %s\"", lic_index[1]))
            evt = avl.pfal("IO6.Set=low")
            evt = avl.pfal("IO6.Set=hpulse, 1000")
            evt = avl.pfal("IO6.Set=hpulse, 1000")
            print(string.format("OH YEAH!!!, BEST MATCH License type : %s", lic_index[1]))
        end
    else
        print(string.format("NO BEST MATCH, License type : %s", lic_index[1]))
        evt = avl.pfal(string.format("MSG.Send.USB,0,\"NO BEST MATCH, License type : %s\"", lic_index[1]))
    end
    

    if trackIndex >= 4 then
        evt = avl.pfal("MSG.Send.USB,0,\"License Information Complete\"")
        data = data..string.format("License Type : %s\n", lic_index[1])
        data = data..string.format("Gender (Male = 1 , Female = 2, Unknown = 3) : %s\n", lic_index[2])
        data = data..string.format("License No. : %s\n", lic_index[3])
        data = data..string.format("Location No. : %s\n", lic_index[4])
        evt = avl.pfal(string.format("MSG.Send.USB,0,\"License Type : %s\"", lic_index[1]))
        evt = avl.pfal(string.format("MSG.Send.USB,0,\"Gender (Male = 1 , Female = 2, Unknown = 3) : %s\"", lic_index[2]))
        evt = avl.pfal(string.format("MSG.Send.USB,0,\"License No. : %s\"", lic_index[3]))
        evt = avl.pfal(string.format("MSG.Send.USB,0,\"Location No. : %s\"", lic_index[4]))
    else 
        -- trackIndex not complete (Not Equals == 4)
        evt = avl.pfal("MSG.Send.USB,0,\"License Information Not complete (some information is miss)\n\"")
        data = data..("License Information Not complete (some information is missing)\n")
        if string.len(lic_index[1]) ~= 2 then
            evt = avl.pfal(string.format("MSG.Send.USB,0,\"License Type part, Not Complete: %s\"", lic_index[1]))
            data = data..(string.format("License Type part, Not Complete: %s\n", lic_index[1]))
        end
        if string.len(lic_index[2]) ~= 1 then
            evt = avl.pfal(string.format("MSG.Send.USB,0,\"License Gender part, Not Complete: %s\"", lic_index[2]))
            data = data..(string.format("\nLicense Gender part, Not Complete: %s\n", lic_index[2]))
        end
        if string.len(lic_index[3]) < 7 and string.len(lic_index[3]) > 8 then
            evt = avl.pfal(string.format("MSG.Send.USB,0,\"License No. part, Not Complete: %s\"", lic_index[3]))
            data = data..(string.format("\nLicense No. part, Not Complete: %s\n", lic_index[3]))
        end
        if string.len(lic_index[4]) ~= 5 then
            evt = avl.pfal(string.format("MSG.Send.USB,0,\"License Location part, Not Complete: %s\"", lic_index[4]))
            data = data..(string.format("\nLicense Location part, Not Complete: %s\n", lic_index[4]))
        end
    end

end

local x = 0

while 1 do
  local ev = avl.event(10000)
  x = x + 1
  if (ev == nil) then 
  	loop (x)
  else
  	event(ev)
  end  
end