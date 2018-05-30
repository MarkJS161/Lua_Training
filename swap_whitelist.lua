-- swap_card : for check license type is match in our accept
local swapNot = false local data = ""
os.trace("Running %s on '%s'", _VERSION , os.getenv("DEVICE.NAME"))
os.sleep(500)

function loop ()
  local e, str
  if swapNot then
    e, str = avl.pfal(string.format("MSG.Send.USB,0,\"HEY!!!, %s\"", data))
  else
    e, str = avl.pfal(os.date("MSG.Send.USB,0,\"HEY!!!, today is %A, the %d/%m/%Y (%c) : Please swap your driving license\"", os.time()))
  end
end

function event (e) -- check, which event coming and do what in that event show or do something
  local ev
  local t = os.clock()
  if e.type == ALARM_SYS_SERIALDATA0 then
  os.trace("Serial data \"%.10s...\" (%d bytes) (%d ms)", e.u_recvdata, e.u_recvlen, t)
  ev = avl.pfal(string.format("MSG.Send.USB,0,\"Hello World, This card ID :%s\"", e.u_recvdata))
  check_magnetic_input(e.u_recvdata, e.u_recvlen)
  swapNot = true
  else
  os.trace("Unknown event %d/%d ... (%d ms)", e.type, e.idx, t)
  end
end

function check_magnetic_input (cardInfo, cardLength)
    local ev
    index = 1
    track_On = 1
    firstDigit = 1
    lastDigit = 0
    -- Divide card info to 3 tracks 1: track_name, 2: track_date & license num, 3: Driving License
    while index <= cardLength do
        if string.sub(cardInfo, index, index) == '?' then -- '?' use to divide track
            if string.sub(cardInfo, firstDigit, firstDigit) == '%' or string.sub(cardInfo, index-1, index-1) == '^' then -- TRACK #1 : Driver Name
                track_On = track_On + 1
                lastDigit = lastDigit + index - 1
                lic_track_1 = string.sub(cardInfo, firstDigit, lastDigit)
                ev = avl.pfal(string.format("MSG.Send.USB,0,\"TRACK #1 : %s\"",lic_track_1))
                firstDigit = firstDigit + index
            elseif string.sub(cardInfo, firstDigit, firstDigit) == ';' or string.sub(cardInfo, index-1, index-1) == '=' then --- TRACK #2 : ID No. & Day of birth
                track_On = track_On + 1
                lastDigit = (lastDigit * 0) + index -1
                lic_track_2 = string.sub(cardInfo, firstDigit, lastDigit)
                ev = avl.pfal(string.format("MSG.Send.USB,0,\"TRACK #2 : %s\"",lic_track_2))
                firstDigit = (firstDigit * 0) + index + 1
            elseif string.sub(cardInfo, firstDigit, firstDigit) == '+' or track_On == 3 then -- TRACK #3 : license No. & info
                lastDigit = (lastDigit * 0) + index - 1
                lic_track_3 = string.sub(cardInfo, firstDigit+1, lastDigit)
                ev = avl.pfal(string.format("MSG.Send.USB,0,\"TRACK #3 : %s\"",lic_track_3))
            end
        end
        index = index + 1
    end
    data = ""
    if string.len(lic_track_1) ~= 0 and string.len(lic_track_2) ~= 0 and string.len(lic_track_3) ~= 0 then
        ev = avl.pfal("MSG.Send.USB,0,\"GET ALL 3 TRACKS INSIDE\"")
        getDriverName(lic_track_1)
        getCardDate(lic_track_2)
        getLicType(lic_track_3)
    elseif string.len(lic_track_1) ~= 0 and string.len(lic_track_2) ~= 0 and string.len(lic_track_3) == 0 then
        ev = avl.pfal("MSG.Send.USB,0,\"GET 2 TRACKS INSIDE; MISS TRACK#3 (Require Track#3)\"")
        getDriverName(lic_track_1)
        getCardDate(lic_track_2)
    elseif string.len(lic_track_1) == 0 and string.len(lic_track_2) ~= 0 and string.len(lic_track_3) ~= 0 then
        ev = avl.pfal("MSG.Send.USB,0,\"GET 2 TRACKS INSIDE; MISS TRACK#1\"")
        getCardDate(lic_track_2)
        getLicType(lic_track_3)
    elseif string.len(lic_track_1) ~= 0 and string.len(lic_track_2) == 0 and string.len(lic_track_3) ~= 0 then
        ev = avl.pfal("MSG.Send.USB,0,\"GET 2 TRACKS INSIDE; MISS TRACK#2\"")
        getDriverName(lic_track_1)
        getLicType(lic_track_3)
    elseif string.len(lic_track_1) ~= 0 and string.len(lic_track_2) == 0 and string.len(lic_track_3) == 0 then
        ev = avl.pfal("MSG.Send.USB,0,\"GET ONLY 1 TRACK INSIDE; MISS TRACK# 2 & 3\"")
        getDriverName(lic_track_1)
    elseif string.len(lic_track_1) == 0 and string.len(lic_track_2) ~= 0 and string.len(lic_track_3) == 0 then
        ev = avl.pfal("MSG.Send.USB,0,\"GET ONLY 1 TRACK INSIDE; MISS TRACK# 1 & 3\"")
        getCardDate(lic_track_2)
    elseif string.len(lic_track_1) == 0 and string.len(lic_track_2) == 0 and string.len(lic_track_3) ~= 0 then
        ev = avl.pfal("MSG.Send.USB,0,\"GET ONLY 1 TRACK INSIDE; MISS TRACK# 1 & 2 (Require Track#3)\"")
        getLicType(lic_track_3)
    else
        ev = avl.pfal("MSG.Send.USB,0,\"CANNOT GET ALL TRACKS INSIDE (Require Track#3);\"")
    end
end
 
-- Check track#1 => get driver name
-- Track #1 is keep driver name information
-- First position is last name of driver
-- Second position is first name of driver
-- Third position is name title
-- It separated by question marks '?'
function getDriverName(track_1)
    local ev
    local track_1_len = 0
    local mr = 0 local mss = 0 local mrs = 0
    local hasLast = 0 local firstCh = 0 local lastCh = 0
    firstOrNot = 1
    mr = string.find(track_1, "MR")
    mss = string.find(track_1, "MS")
    mrs = string.find(track_1, "MRS")
    -- find MR., MS., MRS. to defined length of name
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
        ev = avl.pfal("MSG.Send.USB,0,\"Unknown Driver Name : Anonymous\"")
    end
    if track_1_len > 0 then
        for i = 1, track_1_len, 1 do
            ascDigit = track_1:byte(i)
            ascNext = track_1:byte(i+1)
            -- if current index is not alphabet but next is alphabet keep first index
            if (ascDigit > 90 or ascDigit < 65) and (ascNext <= 90 or ascNext >= 65) then
                firstCh = (firstCh * 0) + i + 1
            elseif (ascDigit <= 90 or ascDigit >= 65) and (ascNext > 90 or ascNext < 65) then -- keep last index, if next index is not alphabet
                lastCh = (lastCh * 0) + i
                -- check in track#1 lastname come before firstname if already keep lastname. Next, It will be firstname exactly.
                if firstOrNot == 1 then
                  lastName = string.sub(track_1, firstCh, lastCh)
                  firstOrNot = firstOrNot + 1
                elseif firstOrNot == 2 then
                  firstName = string.sub(track_1, firstCh, lastCh)
                end
            end
        end
        data = data..string.format( "The Driver Name: %s.%s %s\n", title, firstName, lastName)
        ev = avl.pfal(string.format("MSG.Send.USB,0,\"The Driver Name: %s.%s %s\"", title, firstName, lastName))
    end
end

-- check track#2
-- Track #2 is keep date information
-- Country code of driving license country
-- ID No. of Driver
-- The Date of Expiry for to renew card
-- The Date of Driver Birth 
function getCardDate(track_2)
    local ev, country, idNo, expiry, dateBirth
    local first = 0
    local track_2_len = string.len(track_2)
    local index = 1
    
    if track_2_len > 1 then
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
        if index >= 4 then
            data = data..string.format("The country code : %s.\n", country)
            data = data..string.format("The ID No. : %s, %d.\n", idNo, string.len(idNo))
            data = data..string.format("The Date of Expiry : M:%s-Y:%s.\n", string.sub(expiry, 3), string.sub(expiry, 1, 2))
            data = data..string.format("The Date of Birth : D:%s-M:%s-Y:%s.\n", string.sub(dateBirth,7), string.sub(dateBirth, 5, 6), string.sub(dateBirth, 1, 4))
            ev = avl.pfal( string.format("MSG.Send.USB,0,\"The country code : %s.\"", country) )
            ev = avl.pfal( string.format("MSG.Send.USB,0,\"The ID No. : %s.\"", idNo) )
            ev = avl.pfal( string.format("MSG.Send.USB,0,\"The Date of Expiry : M:%s-Y:%s.\"", string.sub(expiry, 3), string.sub(expiry, 1, 2)) )
            ev = avl.pfal( string.format("MSG.Send.USB,0,\"The Date of Birth : D:%s-M:%s-Y:%s.\"", string.sub(dateBirth, 7), string.sub(dateBirth, 5, 6), string.sub(dateBirth, 1, 4)) )
        else
            ev = avl.pfal("MSG.Send.USB,0,\"We lost some information in track#2\"")
        end
    else
        ev = avl.pfal("No one, can find my card date found.")
    end
end

-- check track#3 => about license_type
-- Track #3 is keep driving license information
-- license type : e.g. 21, 12, 22, 11, 23, etc.
-- gender of driver : male or female or between them or "2 in 1"?.
-- license no. : 7~8 digits (XXXXXXX / i.e. 9999958, 0007046, 35711728, 59001720)
-- location : where release this card? 5 digits maybe postal code
function getLicType(track_3)
    local ev, licType, gender, licNo, location
    local firstIndex = 0 local lastIndex = 0 local trackIndex = 1
    local length = string.len(track_3)
    if length > 0 then
        for digit = 1, length, 1 do
            if string.sub(track_3, digit, digit) == ' ' and string.sub(track_3, digit+1, digit+1) ~= ' ' then
                firstIndex = firstIndex + digit +1
            elseif string.sub(track_3, digit, digit) ~= ' ' and string.sub(track_3, digit+1, digit+1) == ' ' then
                lastIndex = lastIndex + digit
                info = string.sub(track_3, firstIndex, lastIndex)
                if trackIndex == 1 then
                    licType = string.sub(track_3, firstIndex, lastIndex)
                elseif trackIndex == 2 then
                    gender = string.sub(track_3, firstIndex, lastIndex)
                elseif trackIndex == 3 then
                    licNo = string.sub(track_3, firstIndex, lastIndex)
                elseif trackIndex == 4 then
                    location = string.sub(track_3, firstIndex, lastIndex)
                end
                trackIndex = trackIndex + 1
                firstIndex = firstIndex * 0
                lastIndex = lastIndex * 0
            end
        end
        
        if string.len(licType) == 2 then
            -- if license type is match/same 21, 22, 23 : I/O6 is high -> low if swap correct card. 
            -- Maybe some case, it's come from Users config someone want have all 3 types but someone set only 2 or 1 type(s) to allow check
            -- if whitelist<index> is contain value something is can mean "enable this type(index)" and after get, value is true. otherwise is false only (not contain anything.)
            -- In 'lua' whitelist can get boolean value only (can't get another value e.g. string, integer cannot get to use in lua).
            whiteList = avl.pfal(string.format("Sys.Whitelist.Get,%s", licType))
            if whiteList then
                -- if in whitelist<index> is true, It mean licType is correct and IO6 change to low (no sound) if swap again, It will have sound 1 second before silent.
                ev = avl.pfal(string.format("MSG.Send.USB,0,\"OH YEAH!!!, BEST MATCH License type : %s\"", licType))
                ev = avl.pfal("IO6.Set=low")
                ev = avl.pfal("IO6.Set=hpulse, 1000")
                print(string.format("OH YEAH!!!, BEST MATCH License type : %s", licType))
            else
                ev = avl.pfal("MSG.Send.USB,0,\"It is wrong or not have 'license type' in your valid list (WhiteList), Try again.\"")
            end
        else
            print(string.format("NO BEST MATCH, License type : %s", licType))
            ev = avl.pfal(string.format("MSG.Send.USB,0,\"NO BEST MATCH, This isn't License type : %s (License Type have only 2 digits)\"", licType))
        end

        if trackIndex >= 4 then
            ev = avl.pfal("MSG.Send.USB,0,\"License Information Complete\"")
            data = data..string.format("License Type : %s\n", licType)
            data = data..string.format("Gender (Male = 1 , Female = 2, Unknown = 3) : %s\n", gender)
            data = data..string.format("License No. : %s\n",licNo)
            data = data..string.format("Location No. : %s\n", location)
            ev = avl.pfal(string.format("MSG.Send.USB,0,\"License Type : %s\"", licType))
            ev = avl.pfal(string.format("MSG.Send.USB,0,\"Gender (Male = 1 , Female = 2, Unknown = 3) : %s\"", gender))
            ev = avl.pfal(string.format("MSG.Send.USB,0,\"License No. : %s\"",licNo))
            ev = avl.pfal(string.format("MSG.Send.USB,0,\"Location No. : %s\"", location))
        else 
            -- trackIndex not complete (Not Equals == 4)
            ev = avl.pfal("MSG.Send.USB,0,\"License Information Not complete (some information is lost)\"")
            data = data..("License Information Not complete (some information is missing)\n")
            if string.len(licType) ~= 2 then
                ev = avl.pfal(string.format("MSG.Send.USB,0,\"License Type part, Not Complete: %s\"", licType))
                data = data..string.format("License Type part, Not Complete: %s\n", licType)
            end
            if string.len(gender) ~= 1 then
                ev = avl.pfal(string.format("MSG.Send.USB,0,\"License Gender part, Not Complete: %s\"", gender))
                data = data..string.format("License Gender part, Not Complete: %s\n", gender)
            end
            if string.len(licNo) < 7 and string.len(licNo) > 8 then
                ev = avl.pfal(string.format("MSG.Send.USB,0,\"License No. part, Not Complete: %s\"",licNo))
                data = data..string.format("License No. part, Not Complete: %s\n",licNo)
            end
            if string.len(location) ~= 5 then
                ev = avl.pfal(string.format("MSG.Send.USB,0,\"License Location part, Not Complete: %s\"", location))
                data = data..string.format("License Location part, Not Complete: %s\n", location)
            end
        end
    end
end
-- run in loop check event every 10 seconds.
while 1 do
  local ev = avl.event(10000)
  if (ev == nil) then 
  	loop ()
  else
  	event(ev)
  end  
end