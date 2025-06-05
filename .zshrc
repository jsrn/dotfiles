# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export ZSH="/Users/jsrn/.oh-my-zsh"

zstyle ':omz:update' mode auto

ZSH_THEME="robbyrussell"

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

export EDITOR='code --wait'

# SYSTEM UTILITIES
alias please='sudo $(fc -ln -1)'
alias ipaddr="ifconfig | grep 192 | cut -d ' ' -f 2"
alias nuke='shred -u'
alias shconfig='code ~/.zshrc'
alias whatismyip="ifconfig | grep 192 | cut -d ' ' -f 2"
alias hosts="cat ~/.ssh/config | grep 'Host ' -A 1 | sed 's/    Hostname/Hostname/' | cut -d ' ' -f 2"

# GIT
alias gcane='git commit --amend --no-edit'
alias yesgcane='LEFTHOOK_EXCLUDE=rubocop git commit --amend --no-edit'
alias gclean='CURR=`git branch --show-current --no-color`;git branch --merged | egrep -v "(^\*|$CURR)" | xargs git branch -d'
alias pickaxe="git log -p -S"
alias gl='git log --no-merges'
alias git-latest-tag="git tag --list | tac | head -1"
alias fco="git branch | fzf | xargs git checkout"

# OTHER
alias blog='cd ~/code-personal/jsrn.github.io && subl . && open http://127.0.0.1:4000 && bundle exec jekyll serve --drafts --future'
alias write='code --profile Writing'
alias scrap='code --profile Writing ~/Desktop/scrap.md'
alias bx='bundle exec'

function valec() {
    pbpaste > /tmp/valeclip
    vale --no-wrap --config /Users/jsrn/.vale.ini /tmp/valeclip
    rm /tmp/valeclip
}

# Open man pages in a nice little window.
# h/t https://collindonnell.com/my-xman-function
function xman() {
  open x-man-page://$1
}

function ia() {
  open $1 -a /Applications/iA\ Writer.app
}

export PATH="/Applications/Sublime Text.app/Contents/SharedSupport/bin:/Users/jsrn/bin:$PATH"
export HOMEBREW_CASK_OPTS="--appdir=~/Applications"
export HOMEBREW_NO_AUTO_UPDATE=1
export REVEAL_RUBOCOP_TODO=1

# Anything above this line should be stuff that I want on basically any system.
# System specific changes should go after this line to avoid being overwritten.

source ~/.zshrc-work

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh" || true

eval "$(mise activate --shims)"