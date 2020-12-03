#!/usr/env julia

push!(LOAD_PATH, "../src/")

using Documenter, Clack

DocMeta.setdocmeta!(Clack, :DocTestSetup, :(using Rslt))
makedocs(sitename="Clack.jl Documentation")
