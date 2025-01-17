function arg_decl(x::Spec)
    T = idiomatic_julia_type(x)
    T in struct_name.(api.handles, true) && return wrap_identifier(x)
    :($(wrap_identifier(x))::$(signature_type(T)))
end

function kwarg_decl(x::Spec)
    val = default(x)
    Expr(:kw, wrap_identifier(x), val)
end

drop_arg(x::Spec) = is_length(x) && !is_length_exception(x) && is_inferable_length(x) || is_pointer_start(x) || x.type == :(Ptr{Ptr{Cvoid}})

"""
Function pointer arguments for a handle.
Includes one `fptr_create` for the constructor (if applicable),
and one `fptr_destroy` for the destructor (if applicable).
"""
function func_ptr_args(spec::SpecHandle)
    args = Expr[]
    spec ∈ api.constructors.handle && push!(args, :(fptr_create::FunctionPtr))
    destructor(spec) ≠ :identity && push!(args, :(fptr_destroy::FunctionPtr))
    args
end

"""
Function pointer arguments for a function.
Takes the function pointers arguments of the underlying handle if it is a Vulkan constructor,
or a unique `fptr` if that's just a normal Vulkan function.
"""
function func_ptr_args(spec::SpecFunc)
    if spec.type ∈ [FTYPE_CREATE, FTYPE_ALLOCATE]
        func_ptr_args(api.constructors[spec].handle)
    else
        [:(fptr::FunctionPtr)]
    end
end

"""
Corresponding pointer argument for a Vulkan function.
"""
func_ptrs(spec::Spec) = name.(func_ptr_args(spec))

function add_func_args!(p::Dict, spec, params; with_func_ptr = false)
    params = filter(!drop_arg, params)
    arg_filter = if spec.type ∈ [FTYPE_DESTROY, FTYPE_FREE]
        destroyed_type = api.destructors[spec].handle.name
        x -> !expose_as_kwarg(x) || x.type == destroyed_type
    else
        !expose_as_kwarg
    end

    p[:args] = convert(Vector{ExprLike}, map(arg_decl, filter(arg_filter, params)))
    p[:kwargs] = map(kwarg_decl, filter(!arg_filter, params))

    with_func_ptr && append!(p[:args], func_ptr_args(spec))
end
