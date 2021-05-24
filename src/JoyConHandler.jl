module JoyConHandler

using HidApi

export initjoycon, readgyro, initjoycon2


L_ACCEL_OFFSET_X = 350
L_ACCEL_OFFSET_Y = 0
L_ACCEL_OFFSET_Z = 4081
R_ACCEL_OFFSET_X = 350
R_ACCEL_OFFSET_Y = 0
R_ACCEL_OFFSET_Z = -4081

# https://www.the-sz.com/products/usbid/index.php?v=&p=&n=Joy-Con
JOYCON_L = Dict("vendor_id" => 0x057E, "product_id" => 0x2006)
JOYCON_R = Dict("vendor_id" => 0x057E, "product_id" => 0x2007)

function initjoycon()
    try
        init()
        @show length(enumerate_devices())
        res = enumerate_devices()
        joycon_L = res[findfirst(x -> x.product_id == JOYCON_L["product_id"], res)]
        openjoyconleft(joycon_L)
        shutdown()
        return joycon_L
    catch e
        println(e)
    end
end

function initjoycon2()
    try
        init()
        @show length(enumerate_devices())
        res = enumerate_devices()
        joycon_L = res[findfirst(x -> x.product_id == JOYCON_L["product_id"], res)]
        readgyro(joycon_L)
        shutdown()
        return joycon_L
    catch e
        println(e)
    end
end

function writecommand(device, count, command, subcommand, arg)
    fix = [0x00, 0x01, 0x40, 0x40, 0x00, 0x01, 0x40, 0x40]
    command = UInt8[command, count, fix...,subcommand, arg]
    write(device, command)
end

"""
joy-con l tika from keyboard
"""
function openjoyconleft(deviceinfo)
    dev = open(deviceinfo)
    a = 0b00001000
    b = 0b00000100
    c = 0b00000010
    d = 0b00000001
    led = [a, b, c, d]
    arg = 0x00
    while true
        # キーボードから受付 1 ~ 4
        i = parse(Int, readline())
        # xor
        arg = arg ⊻ led[mod(i - 1, 4) + 1]
        writecommand(dev, 0, 0x01, 0x30, arg)
        sleep(0.5)
    end
    close(dev)
end

function calcacc(bytes)
    bstr = bitstring(bytes[2]) * bitstring(bytes[1])
    uint16le = parse(Int, bstr; base=2)
    int16le = uint16le < 32768 ? uint16le : uint16le - 65536
    return int16le
end

"""
ref
https://github.com/dekuNukem/Nintendo_Switch_Reverse_Engineering/blob/master/imu_sensor_notes.md
"""
function readgyro(deviceinfo)
    dev = open(deviceinfo)
    writecommand(dev, 0, 0x01, 0x40, 0x01)
    sleep(0.5)
    # sensor on
    writecommand(dev, 1, 0x01, 0x03, 0x30)

    while true
        res = read(dev, 49)
        @show calcacc(res[14:15]) - L_ACCEL_OFFSET_X, calcacc(res[16:17]) - L_ACCEL_OFFSET_Y, calcacc(res[18:19]) - L_ACCEL_OFFSET_Z
        sleep(0.05)
    end
end

end # module
