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
                firstDigit = firstDigit + index
            elseif string.sub(cardInfo, firstDigit, firstDigit) == ';' or string.sub(cardInfo, index-1, index-1) == '=' then --- TRACK #2 : ID No. & Day of birth
                track_On = track_On + 1
                lastDigit = (lastDigit * 0) + index -1
                lic_track_2 = string.sub(cardInfo, firstDigit, lastDigit)
                firstDigit = (firstDigit * 0) + index + 1
            elseif string.sub(cardInfo, firstDigit, firstDigit) == '+' or track_On == 3 then -- TRACK #3 : license No. & info
                lastDigit = (lastDigit * 0) + index - 1
                lic_track_3 = string.sub(cardInfo, firstDigit+1, lastDigit)
            end
        end
        index = index + 1
    end
    data = ""
    if string.len(lic_track_3) ~= 0 then
        getDriverName(lic_track_1)
        getLicType(lic_track_3)
    else
        ev = avl.pfal("MSG.Send.USB,0,\"No Track 3\"")
    end
end
  
function getDriverName(track_1)
    local ev
    local track_1_len = 0
    local mr = 0 local mss = 0 local mrs = 0
    local hasLast = 0 local firstCh = 0 local lastCh = 0
    -- Track #1 is keep driver name information
    -- get one digits from name and change to ascii for compare is a alphabet or not?
    firstOrNot = 1
    mr = string.find(track_1, "MR")
    mss = string.find(track_1, "MS")
    mrs = string.find(track_1, "MRS")
      
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
        data = data.."Unknown Driver Name : Anonymous"
        ev = avl.pfal("MSG.Send.USB,0,\"Unknown Driver Name : Anonymous\"")
    end
    print(string.format("Length of name : %d", track_1_len))
    if track_1_len > 0 then
        for i = 1, track_1_len, 1 do
            ascDigit = track_1:byte(i)
            ascNext = track_1:byte(i+1)
            if (ascDigit > 90 or ascDigit < 65) and (ascNext <= 90 or ascNext >= 65) then
                firstCh = (firstCh * 0) + i + 1
            elseif (ascDigit <= 90 or ascDigit >= 65) and (ascNext > 90 or ascNext < 65) then
                lastCh = (lastCh * 0) + i
                if firstOrNot == 1 then
                  lastName = string.sub(track_1, firstCh, lastCh)
                  firstOrNot = firstOrNot + 1
                elseif firstOrNot == 2 then
                  firstName = string.sub(track_1, firstCh, lastCh)
                end
            end
        end
        print(string.format( "The Driver Name: %s.%s %s", title, firstName, lastName))
        data = data..string.format( "The Driver Name: %s.%s %s", title, firstName, lastName)
        ev = avl.pfal(string.format("MSG.Send.USB,0,\"The Driver Name: %s.%s %s\"", title, firstName, lastName))
    end
end
-- new insert
function getCardDate(track_2)
    local ev, country, idNo, expiry, dateBirth
    local first = 0
    local track_2_len = string.len(track_2)
    local index = 1
    
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
            if i == 7 then
                country = string.sub(track_2, first, i)
                first = (first * 0) + i + 1
                index = index + 1
            end

            if i == 25 then
                expiry = string.sub(track_2, first, i)
                first = (first * 0) + i + 1
                index = index + 1
            end

            if string.sub(track_2,i,i) == '=' then
                if index == 2 then
                    idNo = string.sub(track_2, first, i-1)
                else
                    dateBirth = string.sub(track_2, first, i-1)
                end
                if i ~= track_2_len then
                    first = (first * 0) + i + 1
                end
                index = index + 1
            end
        end
        data = data..string.format("The country code : %s.\n", country)
        data = data..string.format("The ID No. : %s.\n", idNo)
        data = data..string.format("The Date of Expiry : M:%s-Y:%s.\n", string.sub(expiry, 3), string.sub(expiry, 1, 2))
        data = data..string.format("The Date of Birth : D:%s-M:%s-Y:%s.\n", string.sub(dateBirth, 7), string.sub(dateBirth, 5, 6), string.sub(dateBirth, 1, 4))
        ev = avl.pfal(string.format("MSG.Send.USB,0,\"The country code : %s.\"", country))
        ev = avl.pfal(string.format("MSG.Send.USB,0,\"The ID No. : %s.\"", idNo))
        ev = avl.pfal( string.format("MSG.Send.USB,0,\"The Date of Expiry : M:%s-Y:%s.\"", string.sub(expiry, 3), string.sub(expiry, 1, 2)) )
        ev = avl.pfal( string.format("MSG.Send.USB,0,\"The Date of Birth : D:%s-M:%s-Y:%s.\"", string.sub(dateBirth, 7), string.sub(dateBirth, 5, 6), string.sub(dateBirth, 1, 4)) )
    else
        print("No one, can find my card found date.")
        ev = avl.pfal("MSG.Send.USB,0,\"No one, can find my card found date.\"")
    end
end
--
function getLicType(track_3)
    local ev, licType, gender, licNo, location
    local firstIndex = 0 local lastIndex = 0 local detail = 1
    local length = string.len(track_3)
    -- Track #3 is keep driving license information
    -- license type : e.g. 21, 12, 22, 11, 23, etc.
    -- gender of driver : male or female or between them or "2 in 1"?.
    -- license no. : 7~8 digits (XXXXXXX / i.e. 9999958, 0007046, 35711728, 59001720)
    -- location : where release this card? 5 digits maybe postal code
    for digit = 1, length, 1 do
        if string.sub(track_3, digit, digit) == ' ' and string.sub(track_3, digit+1, digit+1) ~= ' ' then
            firstIndex = firstIndex + digit +1
        elseif string.sub(track_3, digit, digit) ~= ' ' and string.sub(track_3, digit+1, digit+1) == ' ' then
            lastIndex = lastIndex + digit
            if detail == 1 then
                licType = string.sub(track_3, firstIndex, lastIndex)
                firstIndex = firstIndex * 0
                lastIndex = lastIndex * 0
                detail = detail + 1
            elseif detail == 2 then
                gender = string.sub(track_3, firstIndex, lastIndex) 
                firstIndex = firstIndex * 0
                lastIndex = lastIndex * 0
                detail = detail + 1
            elseif detail == 3 then
                licNo = string.sub(track_3, firstIndex, lastIndex) 
                firstIndex = firstIndex * 0
                lastIndex = lastIndex * 0
                detail = detail + 1
            elseif detail == 4 then
                location = string.sub(track_3, firstIndex, lastIndex) 
            end
        end
    end
      
    if licType == "21" or licType == "22" or licType == "23" then -- if license type is match/same 21, 22, 23 : I/O6 is high -> low if swap correct card
        ev = avl.pfal(string.format("MSG.Send.USB,0,\"OH YEAH!!!, BEST MATCH License type : %s\"", licType))
        ev = avl.pfal("IO6.set=low")
        ev = avl.pfal("IO6.set=hpulse, 1000")
        print(string.format("OH YEAH!!!, BEST MATCH License type : %s", licType))
    else
        print(string.format("NO BEST MATCH, License type : %s", licType))
        ev = avl.pfal(string.format("MSG.Send.USB,0,\"NO BEST MATCH, License type : %s\"", licType))
    end

    if detail == 4 then
        ev = avl.pfal("MSG.Send.USB,0,\"License Information Complete\"")
        data = data..string.format("License Type : %s\n", licType)
        data = data..string.format("Gender (Male = 1 , Female = 2, Unknown = 3) : %s\n", gender)
        data = data..string.format("License No. : %s\n", licNo)
        data = data..string.format("Location No. : %s\n", location)
        ev = avl.pfal(string.format("MSG.Send.USB,0,\"License Type : %s\"", licType))
        ev = avl.pfal(string.format("MSG.Send.USB,0,\"Gender (Male = 1 , Female = 2, Unknown = 3) : %s\"", gender))
        ev = avl.pfal(string.format("MSG.Send.USB,0,\"License No. : %s\"", licNo))
        ev = avl.pfal(string.format("MSG.Send.USB,0,\"Location No. : %s\"", location))
    else
        ev = avl.pfal("MSG.Send.USB,0,\"License Information Not complete (some information is miss)\n\"")
        data = data..("\nLicense Information Not complete (some information is missing)")
    end

end

local x = 0

while 1 do
  local ev = avl.event(10000) -- every 10 seconds, have event coming or not? before callback
  x = x + 1
  if (ev == nil) then 
  	loop (x)
  else
  	event(ev)
  end  
end