eval "$(rtx activate zsh)"

# pnpm
export PNPM_HOME="/Users/ross/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
