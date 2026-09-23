CarCollectiblesConfig = {
    spawnDistance = 100.0,
    despawnDistance = 120.0,
    collectDistance = 3.0,
    streamIntervalMs = 750,
    floatHeight = 0.75,
    bobHeight = 0.12,
    bobSpeed = 1.5,
    rotationSpeed = 20.0,
}

CarCollectibleSets = {
    {
        id = 'nimbus_wheels',
        name = 'Nimbus Wheel',
        model = 'h4_prop_h4_wheel_nimbus_f',
        reward = { cash = 500, playerXp = 50 },
        locations = { -- i highly recommend setting your own locations before you make resource live
            vector3(-308.09, -1001.94, 29.78),
            vector3(84.69, -202.39, 53.89),
            vector3(-329.37, -1319.43, 30.8),
            vector3(-331.27, -1282.56, 30.7),
            vector3(-357.61, -1490, 29.45),
            vector3(-35.84, -1509.1, 30.22),
            
            -- adding new locations to a existing collection need to be added to bottom since we use indexed vectors
        },
    },
    {
        id = 'toolboxes',
        name = 'FixUp Cases',
        model = 'gr_prop_gr_tool_box_01a',
        reward = { cash = 500, playerXp = 50 },
        locations = { 
            vector3(1796.04, 3898.61, 33.5),
            vector3(1902.03, 3875.49, 31.82),
            vector3(1925.75, 3988.31, 31.48),
            vector3(1650.74, 3806.73, 34.4),
            vector3(1528.07, 3710.64, 33.88)
            
            -- adding new locations to a existing collection need to be added to bottom since we use indexed vectors
        },
    },
}
