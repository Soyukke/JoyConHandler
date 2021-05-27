using HTTP
import HTTP:bytes
using JSON
using JSON2

using Distributed
using SharedArrays

#  curl localhost:32000/testapi
# FIXME Distributed
# 1プロセス追加, joycon warker
if nprocs() < 2
    addprocs(1)
end

# FIXME 別プロセスでJoyConHandlerをusingできない．
@everywhere include(joinpath(@__DIR__, "../src/JoyConHandler.jl"))

# using JoyConHandler

sharedvec = SharedArray{Float32}(zeros(12))
sharedvec .= 0

procid = procs()[end]

z = @spawnat procid sharedvec
fetch(z)

z = @spawnat procid JoyConHandler
@show fetch(z)

@everywhere function readloop()
    @show "readloop"
    # sharedvec[1:end] .= 1
    try
        joyconL = JoyConHandler.initjoyconL()
        joyconR = JoyConHandler.initjoyconR()
        JoyConHandler.startsensor(joyconL)
        JoyConHandler.startsensor(joyconR)
        while true
            dataL = JoyConHandler.readsensor(joyconL)
            dataR = JoyConHandler.readsensor(joyconR)
            sharedvec[1:6] .= dataL
            sharedvec[7:12] .= dataR
        end
    catch e
        @show e
    end

end
z = @spawnat procid readloop()
# @show fetch(z)



# RESTで送信する値はグローバル変数としておいておきたい
# 別プロセスでjoyconとの通信を続ける

"""
Routingを行う場合
"""
const localhost = "0.0.0.0"
const port = haskey(ENV, "PORT") ? parse(Int, ENV["PORT"]) : 32000

println("ポート番号: ", port)
const headers = ["Content-Type" => "application/json"]

"""
辞書型をJSON文字列に変換する
"""
function dict2json_str(json_dict::AbstractDict)
    buf = IOBuffer()
    JSON.print(buf, json_dict, 4)
    return String(take!(buf))
end

"""
GET，nameをpathから取得して，そのnameを持つデータをJSONで返す
sharedvecを使う
"""
function getTest(req::HTTP.Request, sharedvec)::HTTP.Response
    dataL = sharedvec[1:6]
    dataR = sharedvec[7:12]
    @show sharedvec
    try
        # uri = HTTP.URI(req.target)
        # testapi/name, get name
        json_dict = Dict("accelLeft" => dataL, "accelRight" => dataR)
        json_str = dict2json_str(json_dict)
        return HTTP.Response(200, headers, body=bytes(json_str))
    catch e
        body = """
        {
            "message": "No data"
        }
        """
    return HTTP.Response(404, headers, body=bytes(body))
    end
end


# 共通ベクトル
# https://docs.julialang.org/en/v1/stdlib/SharedArrays/

function main()

    TEST_ROUTER = HTTP.Router()
    HTTP.@register(TEST_ROUTER, "GET", "/testapi", req -> getTest(req, sharedvec))
    println("listen...")
    HTTP.serve(TEST_ROUTER, localhost, port)
end

main()