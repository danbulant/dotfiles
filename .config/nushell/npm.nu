def "nu-complete pnpm" [] {
  ^npm -l
  |lines
  |find 'Run "'
  |str trim
  |split column -c ' '
  |get column4
  |str replace '"' ''
}

export extern "pnpm" [
  command?: string@"nu-complete pnpm"
]

def "nu-complete pnpm run" [] {
  open ./package.json
  |get scripts
  |columns
}

export extern "pnpm run" [
  command?: string@"nu-complete pnpm run"
  --workspace(-w)
  --include-workspace-root
  --if-present
  --ignore-scripts
  --script-shell
]