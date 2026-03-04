module EmagDownloader

using HTTP
using JSON
using ArchGDAL

export download_emag, preprocess_emag

"""
Download a file from `url` and save to `dest_path`.
If `overwrite` is false and file exists, no download occurs.
Returns `dest_path`.
"""
function download_emag(url::AbstractString, dest_path::AbstractString; overwrite::Bool=false)
    if isfile(dest_path) && !overwrite
        return dest_path
    end
    resp = HTTP.request("GET", url)
    if resp.status != 200
        error("Failed to download: HTTP $(resp.status)")
    end
    open(dest_path, "w") do io
        write(io, resp.body)
    end
    return dest_path
end

"""
Reproject/warp `input_path` to `output_path` with target CRS (e.g. "EPSG:4326").
Uses ArchGDAL.warp for resampling. Returns `output_path`.
"""
function preprocess_emag(input_path::AbstractString, output_path::AbstractString; target_crs::AbstractString="EPSG:4326", resampling::String="bilinear")
    ArchGDAL.registerdrivers()
    opts = ["-t_srs", target_crs, "-r", resampling]
    ArchGDAL.warp(output_path, [input_path]; options=opts)
    return output_path
end

end # module
