"""
Magnetic anomaly map handling.

A [`MagneticMap`](@ref) holds a north-up, lon/lat-gridded raster in memory and
answers point queries with nearest-neighbour or bilinear interpolation.
"""

"""
    MagneticMap(data, xmin, ymax, dx, dy)

In-memory magnetic anomaly grid (nT).

# Fields
- `data::Matrix{Float32}`: values indexed as `data[ix, iy]` (x first, like GDAL).
  `iy = 1` is the northernmost row. Nodata cells are stored as `NaN`.
- `xmin`, `ymax`: lon/lat (degrees) of the *outer corner* of the upper-left pixel.
- `dx`, `dy`: pixel size in degrees (both positive).
- `global_lon`: `true` when the grid spans 360° of longitude, in which case
  queries wrap around the antimeridian (so `-122.5` and `237.5` are equivalent).
"""
struct MagneticMap
    data::Matrix{Float32}
    xmin::Float64
    ymax::Float64
    dx::Float64
    dy::Float64
    global_lon::Bool
end

function MagneticMap(data::AbstractMatrix{<:Real}, xmin::Real, ymax::Real, dx::Real, dy::Real)
    dx > 0 && dy > 0 || throw(ArgumentError("pixel sizes dx and dy must be positive"))
    nx = size(data, 1)
    is_global = isapprox(nx * dx, 360.0; atol=dx)
    return MagneticMap(Matrix{Float32}(data), Float64(xmin), Float64(ymax), Float64(dx), Float64(dy), is_global)
end

Base.size(m::MagneticMap) = size(m.data)

"""
    bounds(map) -> (lon_min, lon_max, lat_min, lat_max)

Geographic extent of the pixel *centres* covered by `map`.
"""
function bounds(m::MagneticMap)
    nx, ny = size(m.data)
    return (m.xmin + 0.5m.dx, m.xmin + (nx - 0.5) * m.dx,
            m.ymax - (ny - 0.5) * m.dy, m.ymax - 0.5m.dy)
end

"""
    load_map(path) -> MagneticMap

Read band 1 of a single-band raster (GeoTIFF, NetCDF, or anything GDAL reads)
into memory. The raster must be north-up in geographic lon/lat coordinates.
Nodata cells become `NaN`.
"""
function load_map(path::AbstractString)
    isfile(path) || throw(ArgumentError("raster file not found: $path"))
    return ArchGDAL.read(path) do ds
        band = ArchGDAL.getband(ds, 1)
        xmin, pixelw, rot_x, ymax, rot_y, pixelh = ArchGDAL.getgeotransform(ds)
        (rot_x == 0 && rot_y == 0 && pixelh < 0) ||
            throw(ArgumentError("only north-up rasters (no rotation) are supported"))
        data = Float32.(ArchGDAL.read(band))
        nodata = ArchGDAL.getnodatavalue(band)
        if nodata !== nothing
            nd = Float32(nodata)
            replace!(v -> (v == nd || !isfinite(v)) ? NaN32 : v, data)
        end
        MagneticMap(data, xmin, ymax, pixelw, -pixelh)
    end
end

"""
    sample_map(map, lon, lat; interpolation=:bilinear) -> Float64

Magnetic anomaly (nT) at `(lon, lat)` in degrees. `interpolation` is
`:bilinear` (default) or `:nearest`. Longitudes may be given in either the
-180..180 or 0..360 convention when the map is global.

Throws `DomainError` if the point lies outside the map, and returns `NaN` if it
falls on nodata.
"""
function sample_map(m::MagneticMap, lon::Real, lat::Real; interpolation::Symbol=:bilinear)
    interpolation in (:bilinear, :nearest) ||
        throw(ArgumentError("interpolation must be :bilinear or :nearest, got :$interpolation"))
    nx, ny = size(m.data)
    lon_min, lon_max, lat_min, lat_max = bounds(m)
    lat_min - 0.5m.dy <= lat <= lat_max + 0.5m.dy ||
        throw(DomainError(lat, "latitude outside map extent ($lat_min, $lat_max)"))

    x = Float64(lon)
    if m.global_lon
        x = m.xmin + mod(x - m.xmin, 360.0)
    elseif !(m.xmin <= x <= m.xmin + nx * m.dx)
        throw(DomainError(lon, "longitude outside map extent ($lon_min, $lon_max)"))
    end

    # Fractional 1-based pixel coordinates; pixel i has its centre at coordinate i.
    fx = (x - m.xmin) / m.dx + 0.5
    fy = (m.ymax - Float64(lat)) / m.dy + 0.5

    if interpolation === :nearest
        return Float64(m.data[_wrap_x(round(Int, fx), nx, m.global_lon), clamp(round(Int, fy), 1, ny)])
    end

    x0 = floor(Int, fx); tx = fx - x0
    y0 = floor(Int, fy); ty = fy - y0
    xa, xb = _wrap_x(x0, nx, m.global_lon), _wrap_x(x0 + 1, nx, m.global_lon)
    ya, yb = clamp(y0, 1, ny), clamp(y0 + 1, 1, ny)
    top = (1 - tx) * m.data[xa, ya] + tx * m.data[xb, ya]
    bot = (1 - tx) * m.data[xa, yb] + tx * m.data[xb, yb]
    return Float64((1 - ty) * top + ty * bot)
end

_wrap_x(i::Int, nx::Int, is_global::Bool) = is_global ? mod1(i, nx) : clamp(i, 1, nx)
