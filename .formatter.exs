[
  import_deps: [:ecto, :phoenix],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test,contrib}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
