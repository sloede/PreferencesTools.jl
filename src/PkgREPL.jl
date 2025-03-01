module PkgREPL

import ..PreferencesTools
import Pkg
import Markdown

function _nice_error(f)
    try
        f()
    catch err
        if err isa ErrorException
            printstyled("ERROR: ", color=:light_red)
            showerror(stdout, err)
            println()
        else
            rethrow()
        end
    end
end

function _with_env(f; glbl=false)
    glbl || return f()
    envs = filter(endswith("Project.toml"), Base.load_path())
    isempty(envs) && error("no global environment")
    cur_proj = Pkg.project().path
    try
        Pkg.activate(last(envs); io=devnull)
        f()
    finally
        Pkg.activate(cur_proj; io=devnull)
    end
end

### options

const all_opt = Pkg.REPLMode.OptionDeclaration([
    :name => "all",
    :short_name => "a",
    :api => :all => true,
])

const global_opt = Pkg.REPLMode.OptionDeclaration([
    :name => "global",
    :short_name => "g",
    :api => :glbl => true,
])

### status

function status(args...; glbl=false)
    _with_env(glbl=glbl) do
        PreferencesTools.status(args...)
        println()
    end
end
function status(name)
    PreferencesTools.status(name)
    println()
end

const status_help = Markdown.md"""
```
prefs st|status [-g|--global] [pkg]
```

Show all the preferences, optionally for a particular package.

The `-g` flag shows preferences in the global environment (the last environment in the
loadpath).
"""

const status_spec = Pkg.REPLMode.CommandSpec(
    name = "status",
    short_name = "st",
    api = status,
    help = status_help,
    description = "show all preferences",
    arg_count = 0 => 1,
    option_spec = [global_opt],
)

### add

function add(args; glbl=false)
    _nice_error() do
        _with_env(glbl=glbl) do
            pkg, args... = args
            prefs = map(args) do x
                '=' in x || error("preferences must be of the form key=value")
                key, value = split(x, '=', limit=2)
                if value == "nothing"
                    value = nothing
                elseif value == ""
                    value = missing
                elseif value == "true"
                    value = true
                elseif value == "false"
                    value = false
                elseif (v = tryparse(Int, value)) !== nothing
                    value = v
                elseif (v = tryparse(Float64, value)) !== nothing
                    value = v
                end
                Symbol(key) => value
            end
            PreferencesTools.set!(pkg; prefs...)
            status(pkg)
        end
    end
end

const add_help = Markdown.md"""
```
prefs add [-g|--global] pkg key=value ...
```

Set preferences for a given package.

The `-g` flag sets the preferences in the global environment (the last environment in the
load path).
"""

const add_spec = Pkg.REPLMode.CommandSpec(
    name = "add",
    api = add,
    help = add_help,
    description = "set preferences",
    arg_count = 1 => Inf,
    should_splat = false,
    option_spec = [global_opt],
)

### rm

function rm(args; all=false, glbl=false)
    _nice_error() do
        _with_env(glbl=glbl) do
            pkg, keys... = args
            if all
                error("not implemented")
            end
            if !isempty(keys)
                PreferencesTools.delete!(pkg, keys...)
            end
            status(pkg)
        end
    end
end

const rm_help = Markdown.md"""
```
prefs rm|remove [-g|--global] [-a|--all] pkg key ...
```

Unset preferences for a given package.

The `-a` flag removes all preferences.

The `-g` flag removes preferences from the global environment (the last environment in the
load path).
"""

const rm_spec = Pkg.REPLMode.CommandSpec(
    name = "remove",
    short_name = "rm",
    api = rm,
    help = rm_help,
    description = "unset preferences",
    arg_count = 1 => Inf,
    should_splat = false,
    option_spec = [all_opt, global_opt],
)

### all specs

const SPECS = Dict(
    "status" => status_spec,
    "st" => status_spec,
    "add" => add_spec,
    "remove" => rm_spec,
    "rm" => rm_spec,
)

function __init__()
    # add the commands to the REPL
    Pkg.REPLMode.SPECS["prefs"] = SPECS
    # update the help with the new commands
    copy!(Pkg.REPLMode.help.content, Pkg.REPLMode.gen_help().content)
end

end
