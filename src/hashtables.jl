# hashtables.jl: hash tables for HomogeneousPolynomial and TaylorN
#
# Last modification: 2015.05.08
#
# Luis Benet & David P. Sanders
# UNAM
#

@doc """Type structure holding the current parameters for `TaylorN` and
`HomogeneousPolynomial`.

    Fieldnames:

    - maxOrder: maximum order (degree) of the polynomials
    - numVars : maximum number of variables

    These parameters can be changed using `set_params_TaylorN(order,numVars)`
    """ ->
type ParamsTaylorN
    maxOrder :: Int
    numVars  :: Int
    variable_names :: Array{UTF8String,1}
end

@doc """Display the current parameters for `TaylorN` and
`HomogeneousPolynomial`""" ->
function show_params_TaylorN()
    info( """Parameters for `TaylorN` and `HomogeneousPolynomial`:
    Maximum order       = $(_params_taylorN.maxOrder)
    Number of variables = $(_params_taylorN.numVars)
    Variable names      = $(_params_taylorN.variable_names)
    """)
    nothing
end

global const _params_taylorN = ParamsTaylorN(6, 2, UTF8String["x₁", "x₂"])




## Utilities to get/set the maximum order and number of variables;
## they reset the hash tables
get_maxOrder() = _params_taylorN.maxOrder
# set_maxOrder(n::Int) = set_params_TaylorN(n, _params_taylorN.numVars)

get_numVars() = _params_taylorN.numVars
# set_numVars(n::Int) = set_params_TaylorN(_params_taylorN.maxOrder, n)


## Hash tables
@doc """
  Generates the array of dictionaries `indicesTable`, `sizeTable` and `posTable`:

  - `indicesTable`: vector that contains the dictionaries that link the
  lexicographic position of the monomial with the corresponding indexes of
  the powers that characterize the monomial of given degree.
  The vector entry `[k+1]` corresponds to the homogeneous polynomial of
  degree `k`.
  - `sizeTable`: vector containing the number of distinct monomials of the
  homogeneous polynomial, ordered by the degree of the polynomial.
  - `posTable`: vector with the inverse of `indicesTable`, i.e., for a
  given degree `k` and a vector of indexes (hashed), it returns the
  (lexicographic) position of the corresponding monomial.
""" ->
function generateTables()
    maxOrd = get_maxOrder()
    numVars = get_numVars()

    arrayInd  = Array(Dict{Int,Array{Int,1}},maxOrd+1)
    arraySize = Array(Int,maxOrd+1)
    arrayPos  = Array(Dict{UInt,Int},maxOrd+1)

    if numVars==1
        for k = 0:maxOrd
            dInd = Dict{Int, Array{Int,1}}()
            dPos = Dict{UInt,Int}()
            dInd[1] = [k]
            dPos[hash([k])] = 1
            arrayInd[k+1] = dInd
            arraySize[k+1] = 1
            arrayPos[k+1] = dPos
        end
        return arrayInd, arraySize, arrayPos
    end

    iindices = zeros(Int, numVars)
    idic = 0
    for kDeg = 0:maxOrd
        pos = 0
        dInd = Dict{Int, Array{Int,1}}()
        dPos = Dict{UInt, Int}()
        iV = numVars
        for iz = 0:kDeg
            @inbounds iindices[end] = iz
            pos, dInd[pos] = pos2indices!( iindices, pos, dInd, iV, kDeg )
        end
        nCoefH = length(dInd)
        for i=1:nCoefH
            kdic = hash(dInd[i])
            dPos[kdic] = i
        end
        idic += 1
        arrayInd[idic] = dInd
        arraySize[idic] = nCoefH
        arrayPos[idic] = dPos
    end

    return arrayInd, arraySize, arrayPos
end

function pos2indices!(iIndices::Array{Int,1}, pos::Int, dict::Dict{Int,Array{Int,1}},
    iV::Int, kDeg::Int )

    jVar = iV-1
    kDegNext = kDeg - iIndices[iV]
    if jVar > 1
        for jDeg = 0:kDegNext
            @inbounds iIndices[jVar] = jDeg
            pos, dict[pos] = pos2indices!( iIndices, pos, dict, jVar, kDegNext )
        end
    else
        iIndices[1] = kDegNext
        pos += 1
        @inbounds dict[pos] = iIndices
    end

    return pos, iIndices[1:end]
end

const indicesTable, sizeTable, posTable = generateTables()
gc();


get_variable_names() = _params_taylorN.variable_names
set_variable_names{T<:String}(names::Vector{T}) = _params_taylorN.variable_names = names




@doc doc"""`set_variables` sets the names and number of the Taylor variables,
as well as the order of the Taylor expansion.""" ->
function set_variables{T}(R::Type, names::Vector{T}; order=6)
    order >= 1 || error("Order must be at least 1")

    num_vars = length(names)
    num_vars >= 1 || error("Number of variables must be at least 1")

    _params_taylorN.variable_names = names

    if !(order == _params_taylorN.maxOrder && num_vars == _params_taylorN.numVars)
        # if these are unchanged, no need to regenerate tables

        _params_taylorN.maxOrder = order
        _params_taylorN.numVars = num_vars

        resize!(indicesTable,order+1)
        resize!(sizeTable,order+1)
        resize!(posTable,order+1)

        indicesTable[:], sizeTable[:], posTable[:] = generateTables()
        gc();
    end

    # return a list of the new variables
    TaylorN{R}[taylorN_variable(R,i) for i in 1:get_numVars()]
end
set_variables{T}(names::Vector{T}; order=6) = set_variables(Float64, names, order=order)

function set_variables{T<:String}(R::Type, names::T; order=6, numvars=-1)
    variable_names = split(names)

    if length(variable_names) == 1 && numvars >= 1
        name = variable_names[1]
        variable_names = [string(name, subscriptify(i)) for i in 1:numvars]
    end

    set_variables(R, variable_names, order=order)
end
set_variables{T<:String}(names::T; order=6, numvars=-1) = 
    set_variables(Float64, names, order=order, numvars=numvars)


# function set_params_TaylorN(order::Int, numVars::Int)
#     (order > 0 && numVars>=1) ||
#         error("Incorrect order (<0) or number of variables (>=1)")

#     order == _params_taylorN.maxOrder && numVars == _params_taylorN.numVars &&
#         return order, numVars
#     global _params_taylorN = ParamsTaylorN(order, numVars, _params_taylorN.variable_names)

#     resize!(indicesTable,order+1)
#     resize!(sizeTable,order+1)
#     resize!(posTable,order+1)
#     indicesTable[:], sizeTable[:], posTable[:] = generateTables()
#     gc();

#     return order, numVars
# end